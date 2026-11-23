# distroless-php

Distroless PHP images built with Bazel, using [rules_distroless](https://github.com/GoogleContainerTools/rules_distroless).

## CA trust bundle

All PHP versions generate their CA bundle from the same `php-common` package that
supplies the image's raw root certificates. Keep the version constraint in
`php/common.yaml` and the amd64/arm64 entries in `php/common.lock.json` aligned.
The minimum fixed package for the October 2026 eMudhra incident is
`20250419~deb12u2` ([DLA-4845-1](https://lists.debian.org/debian-lts-announce/2026/10/msg00039.html)).
Both emSign ECC Root CA - G3 and AAA Certificate Services must be absent: removing
only the first leaves a cross-signed trust path.

Run the same focused regression check as CI (Python 3 and OpenSSL 3 required):

```sh
bazel build //php:php-fpm-8.4_cacerts @php-common//ca-certificates:data
python3 tests/check_ca_trust.py \
  "$(bazel cquery //php:php-fpm-8.4_cacerts --output=files)" \
  "$(bazel cquery @php-common//ca-certificates:data --output=files)"
```

The check validates both the generated layer and installed raw certificates,
retains unaffected roots, and rejects offline chains through both affected roots.
Existing published images do not update automatically: rebuild and roll out all
supported PHP versions and architectures after merging a trust-store update.

## Updating Debian package snapshots

The YAML manifests pin Debian packages to a specific [snapshot.debian.org](https://snapshot.debian.org) timestamp for reproducibility. When snapshots expire or return 404s, you need to update the timestamps and regenerate the lock files.

### 1. Find a recent snapshot timestamp

Browse the available snapshots:

- Debian archive: https://snapshot.debian.org/archive/debian/
- Debian security: https://snapshot.debian.org/archive/debian-security/

Pick a recent timestamp (e.g. `20260210T022610Z`).

### 2. Update the YAML manifests

Replace the snapshot URLs in all manifest files:

- `php/common.yaml`
- `php/wkhtmltopdf.yaml`
- `php/7.2/php.yaml`
- `php/7.4/php.yaml`
- `php/8.3/php.yaml`
- `php/8.4/php.yaml`
- `nginx/bookworm.yaml`

Each file has three Debian snapshot sources to update:

```yaml
sources:
  - channel: bookworm main contrib
    url: https://snapshot.debian.org/archive/debian/<TIMESTAMP>
  - channel: bookworm-security main
    url: https://snapshot.debian.org/archive/debian-security/<TIMESTAMP>
  - channel: bookworm-updates main
    url: https://snapshot.debian.org/archive/debian/<TIMESTAMP>
```

### 3. Regenerate the lock files

Run the lock target for each repository:

```sh
bazel run @php-common//:lock
bazel run @php-wkhtmltopdf//:lock
bazel run @php-7.2//:lock
bazel run @php-7.4//:lock
bazel run @php-8.3//:lock
bazel run @php-8.4//:lock
bazel run @php-8.5//:lock
bazel run @nginx-bookworm//:lock
```

This resolves packages from the new snapshots and writes updated `.lock.json` files.
