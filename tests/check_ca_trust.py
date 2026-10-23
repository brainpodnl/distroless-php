#!/usr/bin/env python3
"""Check the generated bundle and the raw certificates shipped in PHP images."""

import hashlib
from pathlib import Path
import re
import ssl
import subprocess
import sys
import tarfile
import tempfile


PEM = re.compile(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", re.S)
# Certificate DER SHA-256, not subject names or SPKI hashes. See fixtures/README.md.
DISTRUSTED = {
    "86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B",
    "D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4",
    "7DD78D5F4F13459A83DFF9ABBBA62EDBAF6F2D102BF257FD712F4D9F2746ED8D",
    "F2EDAAFF3D9B701FB4D14C9F285F8C0BAD90FC3BCC1FA07D47F4718EDABA34A5",
}
RETAINED = {
    # Unaffected emSign Root CA - G1 and ISRG Root X1.
    "40F6AF0346A99AA1CD1D555A4E9CCE62C7F9634603EE406615833DC8C8D00367",
    "96BCEC06264976F37460779ACF28C5A7CFE8A3C0AAE11A8FFCEE05C0BDDF08C6",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def fingerprints(data):
    certs = PEM.findall(data)
    require(bool(certs), "No PEM certificates found")
    return {
        hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.decode("ascii"))).hexdigest().upper()
        for cert in certs
    }


def read_archive(path, prefix):
    with tarfile.open(path) as archive:
        files = [
            member for member in archive.getmembers()
            if member.isfile() and member.name.removeprefix("./").startswith(prefix)
            and member.name.endswith(".crt")
        ]
        require(bool(files), f"No certificate files under {prefix} in {path}")
        return b"\n".join(archive.extractfile(member).read() for member in files)


def main():
    require(len(sys.argv) == 3, "Usage: check_ca_trust.py BUNDLE_LAYER_TAR PACKAGE_DATA_TAR")
    bundle = read_archive(sys.argv[1], "etc/ssl/certs/")
    source = read_archive(sys.argv[2], "usr/share/ca-certificates/")
    bundle_fps, source_fps = fingerprints(bundle), fingerprints(source)
    require(bundle_fps == source_fps, "Generated bundle and installed raw roots differ")
    require(not bundle_fps & DISTRUSTED, f"Distrusted roots remain: {bundle_fps & DISTRUSTED}")
    require(RETAINED <= bundle_fps, "Unaffected emSign G1 or ISRG Root X1 was removed")
    require(len(bundle_fps) > 100, "Unexpectedly small CA bundle")

    # These offline chains worked with the old bundle. Fix time to the incident
    # so expiry cannot make an unsafe bundle appear to pass in future runs.
    with tempfile.TemporaryDirectory() as directory:
        ca_file = Path(directory) / "ca.pem"
        ca_file.write_bytes(bundle)
        fixtures = sorted((Path(__file__).parent / "fixtures").glob("*.pem"))
        require(len(fixtures) == 2, "Both eMudhra and AAA cross-sign fixtures are required")
        for fixture in fixtures:
            result = subprocess.run(
                ["openssl", "verify", "-CAfile", str(ca_file), "-no-CApath", "-no-CAstore",
                 "-attime", "1792756800", "-untrusted", str(fixture), str(fixture)],
                capture_output=True, text=True, check=False,
            )
            require(result.returncode != 0, f"Compromised chain still trusted: {fixture.name}")
            require("error 20 at" in result.stderr,
                    f"Expected an untrusted issuer, not another failure: {result.stderr}")
    print(f"PASS: {len(bundle_fps)} retained roots; affected roots and both attack chains rejected")


if __name__ == "__main__":
    main()
