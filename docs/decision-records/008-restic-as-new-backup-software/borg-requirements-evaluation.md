# BorgBackup — Requirements Evaluation

> **Purpose**: Evaluate whether [BorgBackup (Borg)](https://www.borgbackup.org/) can meet the backup requirements defined in [backup-process.md](../backup-process.md) and the related decision records ([DR-005](../decision-records/005-client-side-encryption-with-client-only-key-storage.md), [DR-006](../decision-records/006-operational-separation-for-backup-immutability.md), [DR-007](../decision-records/007-push-direction-with-missing-backup-alerts.md)).

**Borg version evaluated**: 1.4.x (stable). Borg 2.0 is in beta and changes some semantics; differences are noted where relevant.

---

## 1. Client-Side Encryption with Client-Only Key Storage

**Verdict: SUPPORTED — with the `keyfile` or `keyfile-blake2` encryption mode.**

Borg encrypts all data client-side. Chunking, compression, and encryption all happen on the client before data is sent to the server. The `borg serve` process on the server only sees ciphertext and performs low-level storage operations (put, get, commit, check, compact).

**How it works**: Borg supports several encryption modes, chosen at `borg init` time and immutable thereafter:

| Mode | Key stored in | Encryption | Authentication | Client-only key? |
|---|---|---|---|---|
| `repokey` | Repository (`<repo>/config`) | AES-CTR-256 | HMAC-SHA256 (EtM) | **No** — key is on the server |
| `repokey-blake2` | Repository | AES-CTR-256 | BLAKE2b-256 | **No** — key is on the server |
| `keyfile` | Client (`~/.config/borg/keys/`) | AES-CTR-256 | HMAC-SHA256 (EtM) | **Yes** |
| `keyfile-blake2` | Client (`~/.config/borg/keys/`) | AES-CTR-256 | BLAKE2b-256 | **Yes** |
| `authenticated` | Repository | None | HMAC-SHA256 | **No** — no encryption |
| `authenticated-blake2` | Repository | None | BLAKE2b-256 | **No** — no encryption |
| `none` | N/A | None | None | **No** — no encryption or auth |

For the Wolkenschloss requirement of **client-only key storage**, the `keyfile` or `keyfile-blake2` modes must be used. In these modes, the encryption key is stored in `~/.config/borg/keys/` on the client machine and is **never placed in the repository**. The server (or anyone with access to the repository) cannot decrypt the data without both the key file and the passphrase.

The key file itself is encrypted with the user's passphrase. The passphrase is also never transmitted to the server.

**Initialization**:
```bash
borg init --encryption=keyfile ssh://borg@backup-server/~/repo
```

**Critical: key backup**: If the key file is lost, backups are **permanently unrecoverable**, even with the passphrase. The documentation strongly recommends exporting the key to an offline medium:
```bash
borg key export --paper ssh://borg@backup-server/~/repo
```

**Caveats**:
- The `repokey` mode (the general recommendation in the docs) stores the encrypted key **inside the repository on the server**. This does NOT satisfy the client-only key requirement. A compromised server with the passphrase could decrypt all data. The `keyfile` mode must be explicitly chosen.
- If the client machine is compromised, the attacker can capture the passphrase from `BORG_PASSPHRASE` env var, the key file from `~/.config/borg/keys/`, or both from memory. Borg's threat model explicitly acknowledges this.
- The `BORG_KEY_FILE` environment variable can be used to specify a custom key file path, which may be useful for automation.
- Chunk ID generation is key-dependent in encrypted modes, which improves privacy (an attacker cannot correlate chunks across different keys).

**Sources**:
- Encryption modes: <https://borgbackup.readthedocs.io/en/stable/usage/init.html#encryption-mode-tl-dr>
- Key storage location: <https://borgbackup.readthedocs.io/en/stable/usage/init.html#more-about-encryption-modes>
- Key export: <https://borgbackup.readthedocs.io/en/stable/usage/key.html#borg-key-export>
- Client-side encryption guarantee: <https://borgbackup.readthedocs.io/en/stable/usage/init.html> ("Encryption is done locally - i.e., if you back up to a remote machine, the remote machine neither sees your passphrase, nor your unencrypted Borg key, nor your unencrypted files.")

---

## 2. Operational Separation (Append-Only / Client Cannot Delete)

**Verdict: PARTIALLY SUPPORTED — Borg's append-only mode is a low-level segment-level constraint, not a full operational separation. Careful architecture is needed.**

Borg provides two mechanisms relevant to this requirement:

### 2a. Repository append-only mode

A repository can be set to `append_only` via:
```bash
borg config /path/to/repo append_only 1
```

Or at init time:
```bash
borg init --append-only --encryption=keyfile /path/to/repo
```

**What append-only actually does** (from the docs):

> "A repository can be made 'append-only', which means that Borg will never overwrite or delete committed data (append-only refers to the segment files, but borg will also reject to delete the repository completely)."

**Critical limitation**: The docs explicitly state:

> "Please note that this only affects the low level structure of the repository, and running `borg delete` or `borg prune` or reading from the repository will still be allowed."

This means the client can **still issue** `borg delete`, `borg prune`, and `borg compact` commands. In append-only mode, `prune` and `delete` will mark data as deleted in a new transaction, but the underlying segment files are not overwritten. Disk space is not freed. However, the **manifest is updated** — the deleted archives disappear from the repository's active manifest, making them invisible to `borg list` and normal operations, even though the data is still present in the segments.

The `borg compact` command, which would actually free the space, is a no-op in append-only mode. The documentation warns:

> "If `borg compact` command is used on a repo in append-only mode, there will be no warning or error, but no compaction will happen."

### 2b. `borg serve --append-only` via SSH forced command

A more robust approach is to enforce append-only at the `borg serve` level via SSH `authorized_keys`:

```
command="borg serve --append-only --restrict-to-repository /path/to/repo",restrict ssh-rsa AAAAB3...
```

This forces append-only mode for connections using that SSH key, **regardless of the repository's own `append_only` setting**. Even if the client tries to disable append-only mode, the server-side `--append-only` flag takes precedence.

### 2c. Operational separation via separate SSH keys

The recommended architecture for operational separation is to use **different SSH keys for different operations**:

```
# Client key — append-only, can only push
command="borg serve --append-only --restrict-to-repository /path/to/repo",restrict ssh-rsa <client-key>

# Admin key — full access, for pruning
command="borg serve --restrict-to-repository /path/to/repo",restrict ssh-rsa <admin-key>
```

The client uses the first key and can only append data. The admin uses the second key and can run `borg prune` and `borg compact` to manage retention.

**Rollback capability**: In append-only mode, Borg maintains a `transactions` file. If a compromised client runs `borg prune` or `borg delete`, the data is not actually freed — the server admin can roll back to a previous transaction by removing segment files created after a known-good transaction. The documentation provides explicit instructions for this.

**Caveats**:
- **Append-only does NOT prevent `prune` from being executed by the client.** It only prevents compaction (actual space freeing). The archives are logically deleted from the manifest. A client running `borg prune` can make archives "disappear" from `borg list` even in append-only mode. The data is recoverable via the transaction rollback mechanism, but the client has effectively removed the archives from normal access.
- **The `borg serve --append-only` flag does NOT prevent the client from running `prune` or `delete` either.** It only prevents `compact` (which frees disk space). This is a subtle but important distinction.
- **A compromised client can still fill the repository with garbage data** in append-only mode, consuming all available storage. Storage quotas (`--storage-quota`) can mitigate this.
- **The `borg serve` approach requires the server to run `borg serve`** via SSH. It does not apply to local repositories or other transport mechanisms.
- **Pruning must be done from the server or admin key.** Since the client's key forces append-only, the admin runs `borg prune` using a different SSH key (or directly on the server filesystem).

**For the Wolkenschloss use case**: The `borg serve --append-only` + separate admin key pattern achieves the operational separation required by DR-006. The client can push but cannot meaningfully delete (prune is logically effective but physically recoverable). The server admin prunes using a separate, more privileged key. However, the distinction between logical and physical deletion is a subtlety that must be documented carefully.

**Sources**:
- Append-only mode: <https://borgbackup.readthedocs.io/en/stable/usage/notes.html#append-only-mode-forbid-compaction>
- `borg serve --append-only`: <https://borgbackup.readthedocs.io/en/stable/usage/serve.html>
- Hosting repositories (SSH forced commands): <https://borgbackup.readthedocs.io/en/stable/deployment/hosting-repositories.html>
- Transaction rollback: <https://borgbackup.readthedocs.io/en/stable/usage/notes.html#rolling-back-a-transaction>
- How to protect against hacked client (FAQ): <https://borgbackup.readthedocs.io/en/stable/faq.html#how-can-i-protect-against-a-hacked-backup-client>

---

## 3. Push Direction

**Verdict: FULLY SUPPORTED — Borg's native model is push over SSH.**

Borg's primary operating mode is push: the client initiates an SSH connection to the server, starts `borg serve` on the remote side, and pushes encrypted data. The server never initiates a connection to the client.

**How it works**:
```bash
# Client pushes backup to remote server
borg create ssh://borg@backup-server:22/~/repo::{hostname}-{now} /path/to/data
```

This is the standard, documented, and recommended way to use Borg. The `ssh://` repository URL causes the client to SSH into the server and start `borg serve` automatically. All data flows client → server.

The `BORG_RSH` environment variable controls the SSH command:
```bash
export BORG_RSH='ssh -i /path/to/key -p 2222'
```

**The previous Wolkenschloss pull model** (reverse SSH + socat + socket activation) was a workaround to make Borg operate in pull mode, which is not Borg's native direction. The official documentation documents pull mode as a deployment workaround with significant caveats:

> "Typically the Borg client connects to a backup server using SSH as a transport when initiating a backup. This is referred to as push mode. If, however, you require the backup server to initiate the connection or prefer it to initiate the backup run, one of the following workarounds is required..."

The pull-mode docs further warn about security issues with the SSHFS approach:

> "Warning: To mount the client's root file system you will need root access to the client. This contradicts to the usual threat model of BorgBackup, where clients don't need to trust the backup server (data is encrypted). In pull mode the server (when logged in as root) could cause unlimited damage to the client."

**For the Wolkenschloss use case**: Switching from pull to push is architecturally straightforward with Borg. The client simply uses `borg create ssh://...` with the appropriate SSH key. No reverse SSH, socat, or socket activation is needed. This directly addresses the fragility and shared-secret problems documented in [backup-process.md](../backup-process.md).

**Sources**:
- Repository URLs (SSH): <https://borgbackup.readthedocs.io/en/stable/usage/general.html#repository-urls>
- Pull mode (documented as workaround): <https://borgbackup.readthedocs.io/en/stable/deployment/pull-backup.html>
- SSH configuration for Borg: <https://borgbackup.readthedocs.io/en/stable/usage/serve.html#ssh-configuration>

---

## 4. Backup Monitoring / Alerting on Missing Backups

**Verdict: NOT BUILT IN — must be implemented externally.**

Borg is a command-line tool with no built-in scheduling, monitoring, or alerting. It does not track when backups "should" occur, and it has no daemon or notification system.

**What Borg provides that can help**:

- **Exit codes**: Borg returns exit code 0 on success, 1 on warning, 2 on error (or more specific codes with `BORG_EXIT_CODES=modern`). A wrapper script can check these.
- **JSON output**: `borg create --json` and `borg info --json` provide machine-readable output including archive statistics and timestamps.
- **`borg list` and `borg info`**: Can list all archives in a repository with timestamps. A monitoring script can check the most recent archive timestamp against an expected schedule.
- **`--show-rc`**: Logs the return code at the end of execution, useful for scripted monitoring.

**What must be built**:

Since the server does not have the encryption key (with `keyfile` mode), it cannot use `borg list` or `borg info` to inspect archive metadata. However, the server can:

1. **Monitor filesystem-level signals**: Check for new segment files or changes in the repository directory. A new backup creates new segment files in `data/`. A monitoring script on the server can detect when new data was last written.
2. **Use a touch-file pattern**: The backup script on the client creates a marker file on the server (via SSH) after a successful backup. The server monitors this file's modification time. This is simple but requires an additional SSH connection.
3. **Parse `borg serve` logs**: If `borg serve` logs are captured (e.g., via `--info` or `--debug`), the server can detect when the last `borg create` operation occurred.
4. **Use a separate monitoring channel**: The client sends a notification (HTTP, email, etc.) after each successful backup. The server alerts if no notification is received within the expected schedule.

**For the Wolkenschloss use case**: The Sturmfeste backup server must implement monitoring for missing backups, consistent with DR-007. Since the server cannot decrypt the repository in `keyfile` mode, monitoring must rely on filesystem signals or out-of-band notifications. The server could:
- Monitor the repository directory for filesystem modification times
- Require the client to send a "backup completed" notification to a monitoring endpoint
- Implement the monitoring as part of the Sturmfeste server application, not within Borg itself

**Sources**:
- Return codes: <https://borgbackup.readthedocs.io/en/stable/usage/general.html#return-codes>
- Environment variables (exit codes): <https://borgbackup.readthedocs.io/en/stable/usage/general.html#environment-variables>
- JSON output: <https://borgbackup.readthedocs.io/en/stable/internals/frontends.html>

---

## 5. Backup Verification (Integrity Checks)

**Verdict: PARTIALLY SUPPORTED — repository-level checks can run without the key; archive-level checks require it.**

Borg's `borg check` command has two distinct phases, with different key requirements:

### Phase 1: Repository check (runs on server, no key needed)

Checks the low-level consistency of the repository:
- Segment magic headers
- Object metadata and data integrity (CRC32 checksums)
- Repository index consistency

**This phase runs on the server** and does not require the encryption key. The documentation states:

> "When checking a remote repository, please note that the checks run on the server and do not cause significant network traffic."

This can also be split into partial checks using `--max-duration` for large repositories.

### Phase 2: Archive check (runs on client, key required)

Checks the consistency and correctness of archive metadata and (optionally) data:
- Repository manifest existence
- Archive metadata chunks present and valid
- All file data chunks exist in the repository
- With `--verify-data`: full cryptographic verification (decrypt, decompress, verify HMAC/hash)

**This phase runs on the client** because it requires decrypting data. The documentation states:

> "When checking archives of a remote repository, archive checks run on the client machine because they require decrypting data and therefore the encryption key."

**What the server can verify without the key**:
- Repository structural integrity (segment files, CRC32, index consistency)
- Data existence (all chunks referenced by the index exist)
- File existence and naming

**What the server cannot verify without the key**:
- Archive content integrity (are the files inside the archives correct?)
- Cryptographic integrity (HMAC verification of encrypted chunks)
- Data correctness (is the decrypted content what it should be?)

**Important note about `repokey` vs `keyfile`**: In `repokey` mode, the key is stored in the repository. The server **could** decrypt and verify archives if it also had the passphrase. In `keyfile` mode, the server never has the key and cannot perform archive-level verification at all.

**For the Wolkenschloss use case**: Since DR-005 requires client-only key storage (`keyfile` mode), full integrity verification must be performed client-side. The server can run `borg check --repository-only` to verify structural integrity, but archive content verification requires the client. The backup-process.md requirement states: "Verification should run server-side where possible, or client-side if the backup format requires the encryption key to verify." With Borg in `keyfile` mode, the encryption key is required for archive verification, so this is a client-side responsibility.

**Sources**:
- `borg check` documentation: <https://borgbackup.readthedocs.io/en/stable/usage/check.html>
- FAQ: Can Borg verify data integrity: <https://borgbackup.readthedocs.io/en/stable/faq.html#can-borg-verify-data-integrity-of-a-backup-archive>
- Separate compaction (implies structural checks are server-side): <https://borgbackup.readthedocs.io/en/stable/usage/notes.html#separate-compaction>

---

## 6. Versioning and Retention

**Verdict: FULLY SUPPORTED.**

Every `borg create` produces a new, independent archive (snapshot). Archives are immutable once created. The `borg prune` command manages retention with configurable policies.

**Retention options**:

| Option | Description |
|---|---|
| `--keep-within INTERVAL` | Keep all archives within the time interval (e.g., `2d`, `1m`) |
| `--keep-secondly N` | Keep N secondly archives |
| `--keep-minutely N` | Keep N minutely archives |
| `--keep-hourly N` / `-H N` | Keep N hourly archives |
| `--keep-daily N` / `-d N` | Keep N daily archives |
| `--keep-weekly N` / `-w N` | Keep N weekly archives |
| `--keep-monthly N` / `-m N` | Keep N monthly archives |
| `--keep-yearly N` / `-y N` | Keep N yearly archives |
| `--keep-13weekly N` | Quarterly retention (13-week strategy) |
| `--keep-3monthly N` | Quarterly retention (3-month strategy) |
| `--keep-last N` | Keep the N most recent archives |

Rules are applied from most granular (secondly) to least (yearly). Archives kept by an earlier rule do not count toward later rules. Since Borg 1.2.0, the oldest archive is always retained if a retention target is not otherwise met.

**Archive naming and filtering**: Archives can be filtered by prefix (`--glob-archives`) for separate retention policies per data set:
```bash
borg prune --keep-daily 7 --glob-archives '{hostname}-*' /path/to/repo
```

**Two-step deletion**: `borg prune` removes archives (marks data as deleted), but disk space is not freed until `borg compact` is run. Since Borg 1.2.0, compaction is a separate step and can be run independently (even from the server side without the key).

**Important for append-only**: As noted in Requirement 2, in append-only mode, `borg prune` will logically delete archives but not free space. The `--keep-within` option is relevant because it keeps all archives within a time window, preventing an attacker from crowding out legitimate archives.

**Caveats**:
- `borg prune` operates on the repository and requires write access. In the operational separation model, pruning is an admin-only operation.
- `borg compact` also requires write access and can be run from the server side (no key needed), but only in non-append-only mode.
- A very large number of archives in a single repository can slow down operations like `borg check` and `borg mount`.
- One repository per client is recommended for both security and performance reasons.

**Sources**:
- `borg prune`: <https://borgbackup.readthedocs.io/en/stable/usage/prune.html>
- FAQ: Multiple servers into single repository (security issues): <https://borgbackup.readthedocs.io/en/stable/faq.html#can-i-backup-from-multiple-servers-into-a-single-repository>
- Separate compaction: <https://borgbackup.readthedocs.io/en/stable/usage/notes.html#separate-compaction>

---

## 7. Database Pre-Backup Hooks

**Verdict: SUPPORTED via `--content-from-command` and `--stdin`. No general pre/post hooks exist.**

Borg does **not** have general-purpose pre/post backup hook commands. It is a single-shot CLI tool without a daemon or plugin system. However, database dumps are specifically supported.

### Method 1: `--content-from-command` (recommended)

Borg can run a command and capture its stdout as backup content:
```bash
borg create --content-from-command repo::archive -- pg_dumpall -U postgres
```

If the command exits with a non-zero code, Borg fails without creating an archive. This prevents empty or truncated backups.

The default filename for stdin data is `stdin`; customize with `--stdin-name`:
```bash
borg create --content-from-command --stdin-name db-postgres.sql repo::archive -- pg_dumpall -U postgres
```

### Method 2: Piped stdin (not recommended)

```bash
pg_dumpall -U postgres | borg create repo::archive -
```

**Warning**: If the piped command fails, the archive is still created with truncated content. The documentation warns:

> "Using `--content-from-command`, in contrast, borg is guaranteed to fail without creating an archive should the command fail."

Always prefer `--content-from-command` over piped stdin for database dumps.

### Method 3: Wrapper scripts

For multi-step pre-backup workflows (multiple database dumps, config exports, etc.), a wrapper script is needed:
```bash
#!/bin/bash
# Pre-backup: dump all databases
pg_dumpall -U postgres > /var/backups/postgres.sql
mysqldump --all-databases > /var/backups/mysql.sql

# Run Borg
borg create repo::{now:%Y-%m-%d} /var/backups /path/to/data
```

Or using systemd service units with `ExecStartPre`:
```ini
[Service]
ExecStartPre=/usr/local/bin/dump-databases.sh
ExecStart=/usr/bin/borg create repo::{now} /var/backups /data
```

**For the Wolkenschloss use case**: A wrapper script or systemd unit handles database dumps before Borg runs. Since the backup scope is application data and non-reproducible config (per backup-process.md), the wrapper would:
1. Dump databases (PostgreSQL, MariaDB, SQLite)
2. Run `borg create` on the dump directory and data directories

This is functionally equivalent to the restic approach.

**Sources**:
- `borg create`, "Reading backup data from stdin": <https://borgbackup.readthedocs.io/en/stable/usage/create.html#reading-backup-data-from-stdin>
- `--content-from-command`: <https://borgbackup.readthedocs.io/en/stable/usage/create.html>

---

## 8. Cloud Storage Backends

**Verdict: LIMITED — only SSH/SFTP natively. Other backends require rclone or Borg 2.**

### Borg 1.x (stable) supported backends

| Backend | URL format | Notes |
|---|---|---|
| **Local filesystem** | `/path/to/repo` | Direct filesystem access |
| **Remote via SSH** | `ssh://user@host/path` or `user@host:path` | Requires `borg` installed on server; uses `borg serve` |
| **Local (file://)** | `file:///path/to/repo` | Same as local filesystem |

**That's it.** Borg 1.x natively supports only local filesystems and SSH. There is no native S3, B2, Azure, GCS, or any cloud storage API support.

### Workaround: rclone mount

Borg can back up to a locally mounted cloud storage via [rclone mount](https://rclone.org/commands/rclone_mount/):
```bash
rclone mount remote:bucket /mnt/cloud
borg init --encryption=keyfile /mnt/cloud/repo
borg create /mnt/cloud/repo::archive /data
```

**Warning**: The documentation strongly warns against using Borg on non-SSH remote repositories:

> "When Borg is writing to a repo on a locally mounted remote file system, e.g. SSHFS, the Borg client only can do file system operations and has no agent running on the remote side, so every operation needs to go over the network, which is slower."

This approach loses Borg's client/server architecture where `borg serve` handles server-side operations efficiently. Performance and reliability may suffer.

### Borg 2.0 (beta) backends

Borg 2.0 adds **S3** support natively:
```bash
borg2 init --encryption=keyfile s3://s3.amazonaws.com/bucket/repo
```

See: <https://borgbackup.readthedocs.io/en/2.0.x/usage/general.html>

Borg 2.0 is still in beta as of 2026. It is **not production-ready** for the Wolkenschloss use case.

### Workaround: rclone serve sftp

An alternative is to use `rclone serve sftp` to present cloud storage as an SFTP endpoint:
```bash
rclone serve sftp remote:bucket --addr :2222
borg init --encryption=keyfile ssh://borg@localhost:2222/~/repo
```

This adds complexity and a single point of failure (the rclone SFTP proxy).

**For the Wolkenschloss "Cloud Mode"**: Borg 1.x has a significant gap here. The options are:
1. **SSH to a VPS running `borg serve`**: The cloud backup server runs Borg and provides SSH access. This is the standard Borg deployment and works well, but requires a full server (not just object storage).
2. **rclone mount**: Works but is slower and less reliable than native SSH.
3. **Wait for Borg 2.0**: Adds S3 support, but is not yet stable.
4. **Hybrid approach**: Use Borg with SSH for "local mode" and a different tool (like restic) for "cloud mode" that needs direct S3/B2 access.

**Caveats**:
- The lack of native cloud backends is a significant limitation compared to restic (which supports S3, B2, Azure, GCS, Swift, and SFTP natively).
- SSH-based deployment requires a full server (VPS) for cloud mode, increasing cost and operational overhead compared to object storage.
- rclone mount introduces performance overhead and potential reliability issues (network filesystem semantics).

**Sources**:
- Repository URLs: <https://borgbackup.readthedocs.io/en/stable/usage/general.html#repository-urls>
- FAQ: Local repo vs. server repo: <https://borgbackup.readthedocs.io/en/stable/faq.html#what-is-the-difference-between-a-repo-on-an-external-hard-drive-vs-repo-on-a-server>
- Borg 2.0 backends (beta): <https://borgbackup.readthedocs.io/en/2.0.x/usage/general.html>

---

## 9. Known Limitations and Gotchas

### 9.1 No Built-in Scheduling or Monitoring
Borg is a single-shot CLI tool. Scheduling (cron, systemd timers) and monitoring must be implemented externally. See Requirement 4.

### 9.2 Append-Only Does Not Prevent Logical Deletion
Borg's append-only mode prevents compaction (physical space freeing) but does **not** prevent `borg prune` or `borg delete` from logically removing archives from the manifest. A compromised client with append-only SSH access can still run `borg prune` and make archives disappear from `borg list`. The data is physically recoverable via transaction rollback, but normal operations will not see the deleted archives.

The official documentation acknowledges this:

> "Append-only is useful for scenarios where a backup client machine backs up remotely to a backup server using `borg serve`, since a hacked client machine cannot delete backups on the server permanently."

The key word is "permanently" — the client can delete them temporarily (until rollback). This is a subtlety that must be accounted for in monitoring and recovery procedures.

### 9.3 Compromised Client Can Fill Repository with Garbage Data
Even with append-only, a compromised client can fill the repository with garbage archives, consuming all available storage. Storage quotas (`--storage-quota` in `borg serve`) can mitigate this, but the quota is per-repository, not per-archive.

### 9.4 AES-CTR Nonce Reuse with Multiple Clients
Borg uses AES-CTR for encryption. If multiple clients write to the same repository, AES-CTR nonce reuse can occur, weakening encryption. The documentation explicitly warns:

> "BorgBackup is built upon a defined Attack model that cannot provide its guarantees for multiple clients using the same repository."

**One repository per client** is the recommended practice. This is also relevant for the Wolkenschloss architecture: each Wolkenschloss instance should have its own repository on the backup server.

### 9.5 Separate Compaction Since 1.2.0
Since Borg 1.2.0, compaction is a separate step. After `borg prune` or `borg delete`, disk space is not freed until `borg compact` is run. This is beneficial for the operational separation model: the client can prune (though it shouldn't in append-only mode), but compact must be run separately, typically by the server admin.

The documentation also notes that `borg compact` can be run from the server side without the encryption key.

### 9.6 No Server-Side Verification Without the Key
With `keyfile` encryption, the server cannot verify archive content integrity. Only structural repository checks (`borg check --repository-only`) are possible without the key. Full verification requires the client.

### 9.7 Key File Must Be Backed Up Externally
With `keyfile` mode, losing the key file means losing all backups permanently — even with the passphrase. The documentation strongly recommends `borg key export --paper` to create an offline copy. This is a user responsibility that must be clearly communicated in the Wolkenschloss UI.

### 9.8 Pull Mode Incompatibility with Client-Only Key Storage
The previous Wolkenschloss pull-mode setup (reverse SSH + socat + socket activation) required both the server and client to know the encryption passphrase. This is because in pull mode, the server initiates the backup and needs the key to encrypt data. With `keyfile` mode and push, the key stays on the client. The pull mode is architecturally incompatible with the client-only key requirement.

The official documentation for pull mode with socat explicitly shows the passphrase being passed to the client via SSH:

> `echo 'your secure borg key passphrase' | ssh -A ... borgc@borg-client "BORG_PASSPHRASE=\$(cat) borg ... init --encryption repokey ssh://borgs@borg-server/~/repo"`

This confirms that the pull model with Borg fundamentally requires sharing the encryption secret.

### 9.9 Cache Considerations
Borg maintains a local cache in `~/.cache/borg/` containing the chunks index and files index. The cache is **not encrypted**. The documentation notes:

> "The assumption is that the cache is being stored on the very same system which also contains the original files which are being backed up."

For the Wolkenschloss client, this is acceptable (the cache is on the same machine as the data). The cache should not be stored on the backup server.

### 9.10 `borg serve` Process Management
If the SSH connection between client and server is disrupted, `borg serve` may hold a lock on the repository. The documentation recommends configuring SSH keepalives on both sides:

```
# Client: ~/.ssh/config
Host backupserver
    ServerAliveInterval 10
    ServerAliveCountMax 30

# Server: /etc/ssh/sshd_config
ClientAliveInterval 10
ClientAliveCountMax 30
```

This prevents stale locks from blocking subsequent backup operations.

### 9.11 Repository Requires Borg on the Server
Unlike restic's REST backend (which is a standalone HTTP server), Borg's SSH transport requires the `borg` binary to be installed on the server. This is a deployment requirement but not a significant limitation for the Wolkenschloss use case (NixOS can install Borg trivially).

---

## Pull-Mode Evaluation: Can Borg Work in Push Mode with Client-Only Key Storage?

**Verdict: YES — this is Borg's native and recommended mode.**

The current Wolkenschloss setup uses Borg in pull mode (reverse SSH + socat + socket activation), which has three problems documented in [backup-process.md](../backup-process.md):

1. **Fragility**: The reverse SSH + socat + socket activation chain is complex and breaks easily.
2. **Shared encryption secret**: Both sides need the repo password.
3. **Incompatibility with client-side encryption**: Pull mode requires the server to have the encryption key.

Switching to push mode resolves all three problems:

**Push with `keyfile` encryption**:
```bash
# On the client: initialize repository with keyfile encryption
borg init --encryption=keyfile ssh://borg@sturmfeste/~/repo

# The key is stored on the client at ~/.config/borg/keys/...
# The server never sees the key

# Create backup (push)
borg create ssh://borg@sturmfeste/~/repo::{now} /path/to/data
```

**Server-side SSH configuration** (enforces append-only):
```
# /home/borg/.ssh/authorized_keys
command="borg serve --append-only --restrict-to-repository /home/borg/repo",restrict ssh-rsa <wolkenschloss-client-key>
command="borg serve --restrict-to-repository /home/borg/repo",restrict ssh-rsa <admin-key>
```

**Server-side pruning** (using the admin key):
```bash
# Run on the server, or from admin machine using the admin key
borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6 /home/borg/repo
borg compact /home/borg/repo
```

This architecture:
- Keeps the encryption key exclusively on the client (`keyfile` mode)
- Uses push direction (client initiates SSH to server)
- Enforces operational separation via `borg serve --append-only` + separate admin key
- Eliminates the fragile reverse SSH + socat chain

---

## Summary Table

| # | Requirement | Supported? | How | Caveats |
|---|---|---|---|---|
| 1 | Client-side encryption, client-only key | **Yes** | `keyfile`/`keyfile-blake2` mode; key stored in `~/.config/borg/keys/` | Must explicitly choose `keyfile` (not `repokey`); losing the key = losing all backups |
| 2 | Append-only / client cannot delete | **Partial** | `borg serve --append-only` + SSH forced commands; separate admin key for pruning | Append-only prevents compaction, NOT logical deletion; client can still `prune` (archives disappear from manifest but data is recoverable via rollback) |
| 3 | Push direction | **Yes** | Borg's native model; `borg create ssh://...` | None — this is the standard mode |
| 4 | Backup monitoring / missing backup alerts | **No** | Must be implemented externally | No built-in scheduler or alerting; server cannot inspect archive metadata without the key |
| 5 | Backup verification without key | **Partial** | `borg check --repository-only` runs server-side without key; full archive checks require the key | Server can verify structure only; content verification is client-side only |
| 6 | Versioning and retention | **Yes** | `borg prune` with `--keep-*` policies; archives are immutable; two-step deletion (prune + compact) | `prune` requires write access; one repo per client recommended |
| 7 | Database pre-backup hooks | **Yes** (limited) | `--content-from-command` captures command stdout as backup content | No general pre/post hooks; complex workflows need wrapper scripts |
| 8 | Cloud storage backends | **Limited** | Only SSH natively; rclone mount as workaround; S3 in Borg 2.0 (beta) | No native S3/B2/Azure/GCS; cloud mode requires a VPS running `borg serve`, not just object storage |
| 9 | Known limitations | — | — | Append-only doesn't prevent logical deletion; no monitoring; one client per repo; keyfile must be backed up; pull mode incompatible with client-only key |

---

## Comparison with Restic

Since a [restic evaluation](restic-requirements-evaluation.md) already exists, here is a brief comparison on the key differentiators:

| Aspect | Borg | Restic |
|---|---|---|
| Client-only key storage | `keyfile` mode (must choose explicitly) | Default — key always derived from password, stored in repo but encrypted |
| Append-only enforcement | `borg serve --append-only` (prevents compaction only, not logical deletion) | `rest-server --append-only` (prevents DELETE and overwrite at HTTP level) |
| Native cloud backends | SSH only | S3, B2, Azure, GCS, Swift, SFTP, REST |
| Server-side verification without key | `borg check --repository-only` (structural) | File existence and SHA-256 naming only |
| Key management | Key file must be backed up separately; `borg key export --paper` | Password-only recovery; no separate key file |
| Maturity | Stable, widely deployed since 2015 | Stable, widely deployed since 2016 |
| Pull mode | Documented as workaround; incompatible with client-only key | Not supported (inherently push) |
| Resource usage | Often lower memory; single-threaded | Can be higher memory for large repos |
| Deduplication | Chunk-level; chunk ID is key-dependent (privacy) | Pack-level; chunk ID is content-based |

**Key trade-off**: Borg's `keyfile` mode provides true client-only key storage (the key file never touches the server), but requires the user to manage key file backups. Restic's key is always stored in the repository (encrypted with the password), so the server has the encrypted key — but cannot use it without the password. Both models protect against a server-only compromise, but Borg's `keyfile` mode provides stronger guarantees against a server compromise combined with a weak password.

The most significant architectural difference is **cloud backend support**: restic supports many cloud storage APIs natively, while Borg requires SSH access to a server. For the Wolkenschloss "Cloud Mode," this means Borg would require a VPS (running `borg serve`) instead of just an object storage bucket, increasing cost and operational complexity.
