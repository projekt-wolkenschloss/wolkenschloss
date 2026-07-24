# Restic Backup Tool — Requirements Evaluation

> **Purpose**: Evaluate whether [restic](https://restic.net/) can meet the backup requirements defined in [backup-process.md](../backup-process.md) and the related decision records ([DR-005](../decision-records/005-client-side-encryption-with-client-only-key-storage.md), [DR-006](../decision-records/006-operational-separation-for-backup-immutability.md), [DR-007](../decision-records/007-push-direction-with-missing-backup-alerts.md)).

## 1. Client-Side Encryption with Client-Only Key Storage

**Verdict: FULLY SUPPORTED.**

Restic encrypts all data client-side before writing to the repository. Every blob (data and metadata) is encrypted with AES-256-CTR and authenticated with Poly1305-AES. The encryption key is derived from the user's password using scrypt and is never transmitted to the server.

**How it works**: When a repository is initialized with `restic init`, a master encryption key and MAC key are generated and stored encrypted in the `keys/` directory. The user's password unlocks the master key. All data written to the repository — snapshots, trees, data blobs, indexes — is encrypted before leaving the client. The server (any backend) only ever sees ciphertext.

**Key details**:
- Encryption: AES-256 in CTR mode with Poly1305-AES MAC.
- Key derivation: scrypt (configurable parameters).
- The repository password is required to access any data. Without it, the repository is cryptographically opaque.
- A repository can have multiple passwords (multiple key files), each granting full access.
- The master key can be inspected with `restic cat masterkey` (requires password).

**Caveats**:
- If the client host is compromised, the attacker can capture the password from memory or the `RESTIC_PASSWORD` environment variable and decrypt all past and future backups. Restic's threat model explicitly acknowledges this.
- There is no way to revoke a leaked key without re-encrypting the entire repository (via `restic copy` to a new repo).
- The key files in the repository contain metadata in cleartext (hostname, username of the key creator, KDF parameters) but not the password or master key.

**Sources**:
- Design doc, "Keys, Encryption and MAC" section: <https://github.com/restic/restic/blob/master/doc/design.rst>
- Design doc, "Threat Model" section (same URL)
- Preparing a new repo: <https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html>

---

## 2. Operational Separation (Append-Only / Client Cannot Delete)

**Verdict: SUPPORTED with rest-server `--append-only` or rclone proxy.**

Restic itself has no built-in append-only mode in the client — the `forget` and `prune` commands can delete data. However, the server side can enforce append-only semantics, which is the recommended architecture for this exact threat model.

**How it works**:

### Option A: rest-server with `--append-only`

The official [rest-server](https://github.com/restic/rest-server) supports an `--append-only` flag. When enabled, the server rejects DELETE and overwrite operations. The client can only create new backups (POST) and read existing data (GET). The `forget` and `prune` commands will fail when run from the client.

```bash
rest-server --append-only --path /data
```

Pruning must be performed by a separate, well-secured process with full access to the repository (e.g., a cron job on the server host running `restic forget --keep-within 30d && restic prune` directly on the local filesystem).

### Option B: rclone as append-only proxy

For backends that don't natively support append-only (S3, B2, etc.), rclone can be configured as a proxy that denies delete operations. See [Simon Ruderich's blog post on append-only backups with restic and rclone](https://ruderich.org/simon/notes/append-only-backups-with-restic-and-rclone).

The restic documentation also mentions this pattern:
```bash
restic -o rclone.program="ssh user@remotehost rclone" -r rclone:b2:foo/bar
```

### Option C: S3 bucket policies

For S3 backends, bucket policies can be configured to allow only `s3:PutObject` and `s3:GetObject` for the client's IAM user, while denying `s3:DeleteObject`.

**Critical security consideration**: With append-only mode, an attacker who compromises the client can still add garbage snapshots. If the `forget` policy uses `--keep-last` or `--keep-daily` (without `--keep-within`), the attacker could create snapshots that crowd out legitimate ones, causing them to be removed when an administrator runs `forget`. The official documentation explicitly warns about this and recommends using `--keep-within` for append-only repositories.

**Caveats**:
- The append-only guarantee is enforced at the server/transport layer, not in restic itself. If the client has direct filesystem access to the repository (local or SFTP backend), append-only is not enforced unless the filesystem enforces it.
- `prune` requires exclusive access and locks the repository, so it must be scheduled during maintenance windows.
- The `--private-repos` flag on rest-server prevents users from accessing each other's repos, useful for multi-tenant setups.

**Sources**:
- Rest server README: <https://github.com/restic/rest-server>
- Forget documentation, "Security considerations in append-only mode": <https://restic.readthedocs.io/en/latest/060_forget.html>
- Design doc, "Threat Model" (append-only adversary): <https://github.com/restic/restic/blob/master/doc/design.rst>

---

## 3. Push Direction

**Verdict: FULLY SUPPORTED.**

Restic is inherently a push-based tool. The client initiates all operations (backup, check, restore). The server (or storage backend) never initiates connections to the client.

**How it works**: The client runs `restic backup` and pushes encrypted data to the configured backend. Supported push mechanisms:
- `rest:` — HTTP/HTTPS to a rest-server
- `sftp:` — SSH/SFTP (client connects outbound to SSH server)
- `s3:`, `b2:`, `azure:`, `gs:`, `swift:` — Cloud storage APIs (client pushes)
- `rclone:` — Via rclone proxy

No inbound connections or listening daemons are needed on the client side. This aligns perfectly with the push model described in [DR-007](../decision-records/007-push-direction-with-missing-backup-alerts.md).

**Caveats**: None relevant to the push requirement.

**Sources**:
- Preparing a new repo (all backend types): <https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html>

---

## 4. Backup Monitoring / Alerting on Missing Backups

**Verdict: NOT BUILT IN — must be implemented externally.**

Restic has no built-in scheduling, monitoring, or alerting. It is a command-line tool that runs on demand. The documentation explicitly states:

> "Restic does not have a built-in way of scheduling backups, as it's a tool that runs when executed rather than a daemon."

**What restic provides that can help**:
- **Exit codes**: Restic returns exit code 0 on success, 1 on fatal error, 3 on partial source read errors, 10 if the repo doesn't exist, 11 if locking fails, 12 on wrong password (since 0.17.1). Scripts can check these.
- **JSON output**: The `--json` flag on `backup` and `snapshots` commands provides machine-readable output including `snapshot_id`, `backup_start`, `backup_end`, and summary statistics. This can be consumed by monitoring scripts.
- **`restic snapshots`**: Lists all snapshots with timestamps. A monitoring script can check the most recent snapshot time against an expected schedule.

**External tools for monitoring**:
- [resticprofile](https://github.comcreativeprojects/resticprofile): A wrapper that adds scheduling, pre/post commands, and Prometheus metrics. Not part of restic itself.
- [restic-rest-server Prometheus metrics](https://github.com/restic/rest-server): The rest-server can expose Prometheus metrics (`--prometheus`), but these are server-side HTTP metrics, not backup freshness alerts.
- Custom scripts checking `restic snapshots --json` for the latest snapshot timestamp.

**For the Wolkenschloss use case**: The Sturmfeste backup server would need to implement its own monitoring that checks when the last snapshot was received for each client, and alerts if a backup hasn't arrived within the expected schedule. This is consistent with DR-007's requirement that "the server monitors for missing backups and alerts the user."

**Sources**:
- Backup docs, "Scheduling backups": <https://restic.readthedocs.io/en/latest/040_backup.html>
- Scripting docs (exit codes, JSON output): <https://restic.readthedocs.io/en/latest/075_scripting.html>
- Rest server Prometheus support: <https://github.com/restic/rest-server>

---

## 5. Backup Verification (Integrity Checks)

**Verdict: PARTIALLY SUPPORTED — structural checks need the key; the server cannot verify content without it.**

The `restic check` command verifies repository integrity, but it **requires the repository password** to decrypt and verify the content. Without the key, the server cannot verify anything beyond the fact that files exist.

**What `restic check` does** (requires password):
1. **Structural consistency** (default): Loads and decrypts all indexes, verifies that all referenced blobs exist, checks snapshot/tree/blob references are valid.
2. **Data integrity** (`--read-data`): Downloads all pack files, decrypts them, verifies the plaintext SHA-256 hashes match what the index says. Also verifies the MAC on each blob.
3. **Subset checking** (`--read-data-subset`): Check a fraction of pack files, useful for spreading the I/O cost over time.

**What can be verified without the key**:
- File existence: The server can verify that files exist in the expected directory structure.
- File naming: Repository file names are the SHA-256 hash of their (encrypted) content. Running `sha256sum` on a file and comparing to its filename detects corruption at the storage level. This is documented in the design doc.
- File size: Abnormal file sizes could indicate corruption.

**Important**: The Poly1305-AES MAC on each encrypted blob provides cryptographic integrity verification, but verifying the MAC requires the key. A corrupted or tampered file will fail MAC verification during decryption, which restic will detect on restore or check. But this can only happen client-side with the key.

**For the Wolkenschloss use case**: Since the server does not have the encryption key (by design, per DR-005), full integrity verification must be performed client-side. The server can only do superficial checks (file existence, naming consistency, size anomalies). The backup-process.md requirement states: "Verification should run server-side where possible, or client-side if the backup format requires the encryption key to verify." With restic, the encryption key is required, so verification is a client-side responsibility.

A practical approach: schedule periodic `restic check` runs from a trusted client (or a dedicated verification process on the server with key access for this specific purpose).

**Sources**:
- Working with repos, "Checking integrity and consistency": <https://restic.readthedocs.io/en/latest/045_working_with_repos.html>
- Design doc, "Repository Format" (file naming = SHA-256 hash): <https://github.com/restic/restic/blob/master/doc/design.rst>
- Design doc, "Pack Format" (MAC verification): <https://github.com/restic/restic/blob/master/doc/design.rst>

---

## 6. Versioning and Retention

**Verdict: FULLY SUPPORTED.**

Every `restic backup` creates a new snapshot. Snapshots are immutable, content-addressed, and deduplicated. The `forget` command manages retention with configurable policies.

**Retention options**:
| Option | Description |
|---|---|
| `--keep-last n` | Keep the `n` most recent snapshots |
| `--keep-hourly n` | Keep one snapshot per hour for the last `n` hours |
| `--keep-daily n` | Keep one snapshot per day for the last `n` days |
| `--keep-weekly n` | Keep one snapshot per week for the last `n` weeks |
| `--keep-monthly n` | Keep one snapshot per month for the last `n` months |
| `--keep-yearly n` | Keep one snapshot per year for the last `n` years |
| `--keep-tag tag` | Keep snapshots with specific tags |
| `--keep-within duration` | Keep all snapshots within a duration (e.g., `30d`, `1y3m`) |
| `--keep-within-daily` | Keep daily snapshots within a duration |
| `--keep-within-weekly` | Keep weekly snapshots within a duration |
| ... | Similar for monthly, hourly, yearly |

Multiple `--keep-*` options are ORed: a snapshot is kept if it matches any policy.

**Important for append-only**: The `--keep-within` option is specifically recommended for append-only repositories. It keeps all snapshots within a time window, which prevents an attacker's garbage snapshots from crowding out legitimate ones (see Requirement 2).

**Snapshot grouping**: `forget` groups snapshots by hostname and paths by default (`--group-by host,paths`). This prevents accidentally removing unrelated backup sets.

**Two-step deletion**: `forget` marks snapshots for removal but doesn't delete data. `prune` actually removes unreferenced data. This can be automated with `forget --prune`.

**Caveats**:
- `prune` requires an exclusive lock and can be time-consuming for large repositories.
- After `forget`, data is not freed until `prune` runs. Running `check` after `prune` is recommended.

**Sources**:
- Removing backup snapshots: <https://restic.readthedocs.io/en/latest/060_forget.html>

---

## 7. Database Pre-Backup Hooks

**Verdict: SUPPORTED via `--stdin-from-command`. No general pre/post hooks exist.**

Restic does **not** have general-purpose pre/post backup hook commands. The tool is a single-shot CLI without a daemon or plugin system. However, database dumps are specifically supported via the `--stdin-from-command` option.

**How to dump a database before backup**:

```bash
restic backup --stdin-from-command --stdin-filename dump.sql -- mysqldump --host example mydb
```

This runs `mysqldump`, captures its stdout, and backs it up as `dump.sql`. If the command exits with a non-zero code, the backup is cancelled (no snapshot is created).

For PostgreSQL:
```bash
restic backup --stdin-from-command --stdin-filename postgres.sql -- pg_dumpall -U postgres
```

**Warning about `--stdin`**: The older `--stdin` option (piped input) does NOT detect command failures, which can result in empty backups. The documentation explicitly warns about this:

> "Restic cannot detect if data read from stdin is complete or not... If possible, use `--stdin-from-command` instead."

**For multi-database or complex pre-backup workflows**: Restic itself does not orchestrate multiple pre/post steps. A wrapper script or tool is needed. Options:
- Simple shell scripts that run dumps, then invoke `restic backup`
- [resticprofile](https://github.com/creativeprojects/resticprofile) — adds pre/post backup commands, scheduling, and configuration profiles
- systemd service units with `ExecStartPre` for pre-backup commands

**For the Wolkenschloss use case**: A wrapper around `restic backup` can handle database dumps and other pre-backup tasks. Since the backup scope is application data and non-reproducible config (per backup-process.md), the wrapper would:
1. Dump databases (PostgreSQL, MariaDB, SQLite)
2. Run `restic backup` on the dump directory and data directories

**Sources**:
- Backup docs, "Reading data from a command": <https://restic.readthedocs.io/en/latest/040_backup.html>
- Backup docs, "Reading data from stdin" (warning about `--stdin`): <https://restic.readthedocs.io/en/latest/040_backup.html>

---

## 8. Cloud Storage Backends

**Verdict: EXCELLENT — broad native support.**

Restic supports the following backends natively (no rclone needed):

| Backend | URL format | Notes |
|---|---|---|
| **Local** | `/path/to/repo` | Direct filesystem access |
| **SFTP** | `sftp:user@host:/path` | SSH-based; requires key-based auth for automation |
| **REST Server** | `rest:http://host:8000/` | Official [rest-server](https://github.comrestic/rest-server); supports append-only, auth, TLS |
| **Amazon S3** | `s3:s3.region.amazonaws.com/bucket` | Any S3-compatible service (Minio, Wasabi, Ceph, Alibaba OSS) |
| **Backblaze B2** | `b2:bucket:path` | **Recommended to use S3-compatible API instead** due to B2 library issues |
| **Azure Blob** | `azure:container:/path` | Supports access key, SAS token, and managed identity auth |
| **Google Cloud Storage** | `gs:bucket:/path` | Service account key auth |
| **OpenStack Swift** | `swift:container:/path` | Multiple Keystone auth versions |

Additionally, **rclone** provides access to many more services (Google Drive, Dropbox, OneDrive, SFTP to non-standard ports, etc.): `rclone:remote:path`.

**For the Wolkenschloss "Cloud Mode"**: Users without a local backup server would use a cloud storage backend. The most practical options are:
- **S3-compatible storage**: The most flexible option. Works with AWS, Wasabi, Minio, and many others. Restic supports path-style and virtual-hosted-style access.
- **Backblaze B2**: Very cost-effective, but the documentation recommends using B2's S3-compatible API rather than the native B2 backend.
- **rest-server in the cloud**: A VPS running rest-server with `--append-only` and `--private-repos` provides the same architecture as local mode but hosted.

**Caveats**:
- The native B2 backend has known error handling issues; the S3-compatible API is recommended.
- S3 backends require AWS credentials as environment variables.
- GCS requires a service account key file.
- Cloud storage costs include both storage and API operations (PUT, GET, LIST). Restic's deduplication minimizes data transfer, but the index structure creates many small files.
- For append-only enforcement on cloud backends, rclone proxy or S3 bucket policies are needed (see Requirement 2).

**Sources**:
- Preparing a new repo (all backend sections): <https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html>

---

## 9. Known Limitations and Gotchas

### 9.1 No Built-in Scheduling or Monitoring
Restic is a single-shot CLI tool. Scheduling (cron, systemd timers, etc.) and monitoring must be implemented externally. See Requirement 4.

### 9.2 Compromised Client Can Add Garbage Data
Even with append-only, a compromised client can fill the repository with garbage snapshots. The defense is: (a) `--keep-within` retention policies that preserve legitimate snapshots, and (b) server-side monitoring for anomalous size changes (as required by DR-007).

### 9.3 Forget Policy Attacks on Append-Only Repositories
With append-only, an attacker who creates snapshots with slightly newer timestamps can cause `forget` to remove legitimate snapshots when using `--keep-daily` or `--keep-last`. The mitigation is to use `--keep-within` exclusively for append-only repos. This is well-documented in the official "Security considerations in append-only mode" section.

### 9.4 Prune Requires Exclusive Lock
`prune` acquires an exclusive lock on the repository, preventing any other restic operations (including backups) from running concurrently. For large repositories, prune can be time-consuming. This must be scheduled in maintenance windows.

### 9.5 No Server-Side Verification Without the Key
The backup server cannot verify the integrity of backup data without the encryption key. Only superficial checks (file existence, filename = SHA-256 hash of encrypted content) are possible. Full integrity verification requires the client or a process with key access. See Requirement 5.

### 9.6 Key Revocation Requires Full Re-Encryption
If an encryption key is leaked (e.g., the client is compromised), the only way to revoke access is to create a new repository and copy all data to it using `restic copy`. Simply changing the password does not revoke access — the master key remains the same. This is a known design limitation documented in the threat model.

### 9.7 Repository Format Considerations
- Repository version 1: No compression.
- Repository version 2 (default since restic 0.14): Supports zstd compression. Data from new backups is compressed; existing data is not re-compressed until `prune --repack-uncompressed` is run.
- Migration from v1 to v2 is supported via `restic migrate upgrade_repo_v2`.

### 9.8 CIFS/SMB Not Recommended
The documentation explicitly warns against storing repositories on CIFS/SMB shares due to Linux kernel compatibility issues. This is unlikely to affect the Wolkenschloss use case but worth noting.

### 9.9 Cache Directory
Restic maintains a local cache of repository data. The cache is encrypted, preventing metadata leaks even if the cache directory is compromised.

### 9.10 `--stdin` vs `--stdin-from-command`
Using `--stdin` with pipes (e.g., `mysqldump | restic backup --stdin`) will silently create empty backups if the command fails. Always use `--stdin-from-command` for database dumps.

### 9.11 S3 Path-Style vs Virtual-Hosted Style
Restic requires path-style URLs for Amazon S3. Virtual-hosted-style URLs (e.g., `bucket.s3.region.amazonaws.com`) are not supported and must be converted to path-style (e.g., `s3.region.amazonaws.com/bucket`).

### 9.12 Chunking Attack Mitigation
As of restic 0.18.0, chunks are randomly assigned to pack files to mitigate the chunking attack described in [Alexeev, Percival, Zhang (2025)](https://eprint.iacr.org/2025/532.pdf). Earlier versions are potentially vulnerable. See [PR #5295](https://github.com/restic/restic/pull/5295).

---

## Summary Table

| # | Requirement | Supported? | How | Caveats |
|---|---|---|---|---|
| 1 | Client-side encryption, client-only key | **Yes** | AES-256-CTR + Poly1305-AES; key derived from password; all data encrypted before leaving client | Leaked key requires full repo re-encryption; compromised client can capture password |
| 2 | Append-only / client cannot delete | **Yes** (server-enforced) | rest-server `--append-only`, rclone proxy, or S3 bucket policies | Must use `--keep-within` for forget; append-only is server-side, not client-enforced |
| 3 | Push direction | **Yes** | Restic is inherently push-based; all backends are client-initiated | None |
| 4 | Backup monitoring / missing backup alerts | **No** (must be external) | Exit codes, JSON output, `restic snapshots` can be consumed by external monitoring | No built-in scheduler or alerting; resticprofile or custom scripts needed |
| 5 | Backup verification without key | **Partial** | Only file existence and SHA-256 naming checks without key; full `restic check` requires key | Server cannot verify content integrity; client-side or key-holding process needed |
| 6 | Versioning and retention | **Yes** | Snapshots are immutable; `forget` supports `--keep-*` policies; `--keep-within` recommended for append-only | `prune` requires exclusive lock and can be slow |
| 7 | Database pre-backup hooks | **Yes** (limited) | `--stdin-from-command` runs a command and backs up its stdout | No general pre/post hooks; complex workflows need wrapper scripts or resticprofile |
| 8 | Cloud storage backends | **Yes** | S3, B2 (via S3), Azure, GCS, Swift, SFTP, REST, + rclone for others | B2 native backend has issues (use S3 API); S3 requires path-style URLs |
| 9 | Known limitations | — | — | No scheduling, prune locks, key revocation requires re-encryption, `--stdin` trap |

---

## Recommendation

Restic meets **7 of 8** core requirements directly, with the remaining one (monitoring) well-supported by external tooling patterns. The architecture aligns closely with the Wolkenschloss threat model:

- **Client-side encryption** is restic's default and only mode — there is no unencrypted path.
- **Append-only** is a first-class use case with rest-server, and the documentation explicitly addresses the security considerations.
- **Push direction** is restic's native model.
- **Monitoring** must be built externally, but restic provides good primitives (exit codes, JSON output, snapshot listing) for this.
- **Verification without the key** is inherently limited by the encryption design — this is an acceptable trade-off given the threat model.

The main architectural gap is that **backup monitoring and alerting** must be built as a separate system. This aligns with DR-007, which already expects Sturmfeste to implement this.
