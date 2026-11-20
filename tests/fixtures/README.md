# eMudhra distrust regression fixtures

Public certificate chains copied on 23 October 2026 from the incident researcher's
[offline chain archive](https://emudhra.we-have-a-problem.com/chains.zip), linked by
[Mozilla's operator guidance](https://groups.google.com/a/mozilla.org/g/dev-security-policy/c/0R3XLJL6FuE).
These files contain certificates only, not private keys.

- `emudhra-g3-chain.pem`: `chains/dv-g3b-emudhra.we-have-a-problem.com.pem`,
  file SHA-256 `ab6483de0cb01d53d59275baf74d2766f3599e57a48d3319e4a5536c268ac696`.
- `aaa-cross-signed-chain.pem`: `chains/dv-g3b-aaa-emudhra.we-have-a-problem.com.pem`,
  file SHA-256 `3641ff8e872e4c90d5691edb09894914121b267e6a50455347c5f28708fa1af2`.

Both chains were accepted by the previous `20250419` bundle. The check fixes the
verification time to 23 October 2026, disables other OpenSSL CA stores and requires
an issuer-trust failure, not an expiry, DNS, or connection failure. It checks both
the generated bundle and raw roots, and retains unaffected emSign G1 and ISRG X1.

The four defensive root fingerprint assertions come from the researcher's
[`roots.json`](https://emudhra.we-have-a-problem.com/roots.json).
Only emSign ECC G3 and AAA occur in this Debian bundle. Debian's
[DLA-4845-1](https://lists.debian.org/debian-lts-announce/2026/10/msg00039.html)
removes those two roots to cover the cross-sign path. This is not a blanket
distrust of all eMudhra certificates.
