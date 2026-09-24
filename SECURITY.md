# Security policy

Report a vulnerability in this fork privately by email to
[security@latere.ai](mailto:security@latere.ai). Do not open a public issue
or pull request for it.

Include the release you tested (`minio --version`), the deployment shape
(single node or distributed), the steps to reproduce, and the impact you
observed. A vulnerability in code inherited from upstream belongs here too:
upstream `minio/minio` is archived and no longer accepts reports.

Fixes ship in a new release of this fork, `ghcr.io/latere-ai/minio`, and the
release notes name the issue. Known advisories that are not yet ported are
listed in [docs/backports.md](docs/backports.md). Only the latest release is
supported.
