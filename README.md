# distroless-php

Distroless PHP images built with Bazel, using [rules_distroless](https://github.com/GoogleContainerTools/rules_distroless).

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
