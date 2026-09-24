# Backports

Upstream `minio/minio` is archived at
[`7aac2a2c`](https://github.com/minio/minio/commit/7aac2a2c5b7c882e68c1ce017d8256be2feea27f)
(2026-02-12). This fork starts from that commit. The reference for fixes made
since then is [pgsty/silo](https://github.com/pgsty/silo), the SILO community
fork, and its
[security advisory ledger](https://silo.pgsty.com/about/security-advisories/).
This file records each SILO advisory and notable fix considered for this fork,
reviewed against pgsty/silo at
[`2a4d5140`](https://github.com/pgsty/silo/commit/2a4d51406b7ed87af5fe6fe0f801f3290f96eb3c)
(Server `RELEASE.2026-09-16T00-00-00Z`), and its status:

- **ported**: in this fork, by cherry-pick (`git cherry-pick -x`, which keeps
  the author and names the source commit) or by an equivalent change,
  named in the row.
- **deferred**: applies to this fork and is not ported yet. Deferred rows
  are the maintenance backlog, in the priority order of the porting policy:
  (1) published security advisories that apply to upstream code, (2)
  dependency and toolchain updates, (3) correctness fixes for single-node
  deployments and the features the fork's users rely on (conditional
  writes, multipart, listing, signature checks). Multi-pool, replication,
  IAM federation and console fixes wait unless they are small and
  self-contained.
- **not applicable**: the code is not in this fork, or the change is SILO
  branding, packaging or an opt-in feature.

The first release of this fork carries (2) only; the advisories below are
its backlog, ported in later releases.

## Security advisories

| Advisory | SILO fix | Area | Status |
|---|---|---|---|
| CVE-2025-62506 | upstream `c1a49490` | restricted session policy lets service or STS accounts mint unrestricted children | ported: inherited, the fix is in upstream master |
| CVE-2026-33322 | `d24f449e` | OIDC STS JWT algorithm confusion; removes HMAC verification (HS256/384/512 providers must move to JWKS keys) | deferred (1) |
| CVE-2026-33419 | `3b950f8f`, follow-ups `18b712d4`, `9e10f6d9`, `f4411089`, `5e40665a` | LDAP STS username enumeration; unified failure response and per-source login throttling | deferred (1) |
| CVE-2026-34204 | `56fa63bf` | untrusted `X-Minio-Replication-*` headers written into replication metadata | deferred (1) |
| CVE-2026-39414 | `3252d5b7`, follow-up `fd69c89d` | S3 Select buffers oversized CSV and JSON records | deferred (1) |
| CVE-2026-41145 | `f444b6f3` | unsigned-trailer streaming PUT and UploadPart skip query-string signature verification | deferred (1) |
| CVE-2026-40344 | `efb6e5b0` | Snowball auto-extract unsigned-trailer uploads skip authentication | deferred (1) |
| CVE-2026-42600 | `73ac5247` | internode ReadMultiple path traversal; removes the unused endpoint | deferred (1); distributed deployments only |
| SN-2026-002 | `ca7baa67` and follow-ups | internode storage-REST and grid payload containment | deferred (1); distributed deployments only, large change |
| SN-2026-003 | silo-pkg v3.11.0, `2f55347f` | policy condition values taken from raw request entries | deferred (1); needs the matching change in `minio/pkg`, which is archived too |
| SN-2026-004 | silo-pkg v3.11.0, `97b7d280` | object-only resource patterns reach twelve bucket-level writes | deferred (1); needs `minio/pkg` |
| SN-2026-005 | silo-pkg v3.12.0, `eee05a17` | bare ARN prefixes accepted in policy writes | deferred (1); needs `minio/pkg` |
| SN-2026-006 | `b73581b0`, `c4fd97d0` | SSE-C key not checked on zero-byte reads | deferred (1) |
| SN-2026-007 | `474cd580`, `74c97d00`, `21870fa2` | GetObjectAttributes on SSE-C objects without the key | deferred (1) |
| SN-2026-008 | PR #101 (`93860345` through `04b097fd`) | internal replication headers trusted on presence | deferred (1); large change across 15 files |
| SN-2026-009 | `58735ee3`, `229fe2b3` | enable and disable of users and groups authorized by one action | deferred (1) |
| SN-2026-010 | `75a6734e` | explicit version deletes authorized as `s3:DeleteObject` | deferred (1); does not apply cleanly, hand port |
| SN-2026-011 | `12332543`, `87d8b596` | unsigned `x-amz-*` headers turn a signed PUT into CopyObject | deferred (1); does not apply cleanly, hand port |
| SN-2026-012 | `c4b5e1cb` | header-only presigned payload hash not checked against the body | deferred (1) |
| SN-2026-013 | #191, #192 | revoked IAM identities return through replay or recovery | deferred; site replication and shared IAM backends, large change |
| SN-2026-014 | Console #56, Server #209 | anonymous share-download proxy of the embedded console | deferred (1): the proxy is in the embedded `github.com/minio/console` (`api/public_objects.go`), which is archived too; the fix needs a console fork or a port of SILO's. Until then, do not expose the console port beyond the deployment |
| Client source address trust | `fe6dc478` | opt-in `MINIO_API_TRUSTED_PROXIES` boundary; not a vulnerability | not applicable: opt-in feature |

## Dependencies and toolchain

| SILO | Change | Status |
|---|---|---|
| dependency rows of the advisory ledger, `db4c0fd5`, `00f3cf74` and later dependency releases | Go toolchain and module updates for published vulnerabilities | ported by an equivalent change: go1.27.1 and every module govulncheck flags raised to its fixed release, on upstream's module paths. `00f3cf74`'s two test adaptations for newer Go were applied by hand. |
| `ce1c537e` | pins dependencies with breaking changes and fixes an LDAP TLS regression they caused | deferred (3): check LDAP over TLS against the upgraded modules |

## Correctness

| SILO | Change | Status |
|---|---|---|
| `65795ee1`, `8069a32a` (SN-2026-001) | streaming responses are not flushed through `trackingResponseWriter` | deferred (3) |
| `40bee4b7` | DeleteObject ignores `If-Match` | deferred (3) |
| `22c1e41f` | CompleteMultipartUpload accepts duplicate part numbers | deferred (3) |
| `4cbb074c`, `143f6970`, `dfb4b2a1`, `82f0a982` | ListMultipartUploads is not S3-compatible; multipart discovery is unbounded | deferred (3) |
| `e9c5340b` | listing shortcuts answer without NoSuchBucket | deferred (3) |
| `6a9b5d67`, `76195f1c` | header checksum ignored when `x-amz-trailer` is advertised on a non-trailer chunked PUT; trailers hidden after header stripping | deferred (3) |
| `7fea6d5a`, `3e14733f`, `c8590413`, `7e079ff0`, `5d152416`, `d28885d0`, `d4c8da16`, `7c103389` | multipart and checksum validation fixes | deferred (3) |
| `f2520f33`, `c0e71597`, `e73436c9`, `0b0ae242` | CopyObject checksum and metadata fixes | deferred (3) |
| `3598c430` | S3 Select drops records queued before an error message | deferred (3) |
| `744a9dcd` | `s3:versionid` conditions not bound to the effective version | deferred (3) |
| `055030ea` | configured request header deadlines not honored | deferred (3) |
| `48e18465` | TLS key exchange ignores Go's defaults across transports | deferred (3) |
| `2602177e`, `1af351a7` | ReadParts trace and keepalive error handling | deferred (3) |
| `e069fe9d`, `5e7d6030`, `1cf529ce`, `13bf126e` | preconditions and version deletes across pools | deferred: multi-pool |
| replication and federation fixes (`254b19ac`, `9d7094b7`, `358ab38f`, `87746913`, `0c8d7420`, `fcc4d778`, `af56d176`, `2c50d11f`, `885bd2c2`, `4b25f7e8`, `2bc103b8`, `e7e87402`, `9a303f50`, `f175e98c`, `8d76a255`, `dee2c3a0`, `150e7b5f`) | replication, federated CopyObject and CORS state | deferred: replication and federation |
| `711b092f`, console selection commits | embedded console | not applicable: SILO's console fork |
| `9462cce1`, rename and packaging commits | SILO branding, the `silo` binary, packaging and release machinery | not applicable |

Upstream commit `05e56996` points `Dockerfile` and `docker-buildx.sh` at an
internal MinIO registry; they, `Dockerfile.hotfix` and
`Dockerfile.release.old_cpu` are upstream's release tooling and are not used
by this fork, whose image is built by `Dockerfile.release`.
