# Push Direction with Missing-Backup Alerts

## Status

Accepted

## Decision

The Backup Client pushes backups to the Backup Server. This reverses the direction from the previous Borg-based pull setup. To mitigate the risk of a compromised client silently stopping backups, the server monitors for missing backups and alerts the user.

## Context

The previous setup used a pull model where Sturmfeste initiated backups by connecting to Wolkenschloss via reverse SSH, socat, and socket activation. The pull model had a security advantage: a compromised client cannot halt backups because the server initiates on its own schedule.

However, the pull implementation had three problems:

1. **Fragility**: The reverse SSH + socat + socket activation chain is complex and breaks easily.
2. **Shared encryption secret**: Both sides need the repo password, violating client-only key storage (see [DR-005](005-client-side-encryption-with-client-only-key-storage.md)).
3. **Incompatibility with client-side encryption**: Client-side encryption with client-only key storage makes a true pull model architecturally infeasible. The server cannot create a backup without the client's encryption key.

Considered options:

- **Pull with key transfer**: Server pulls and the client provides the key on demand. The server would have access to the key, violating client-only key storage.
- **Push with server-side alerts**: Client pushes encrypted backups. If a backup is not received within the expected schedule, the server alerts the user. The risk is a gap in backup coverage, not loss of existing backups. This operational separation (see [DR-006](006-operational-separation-for-backup-immutability.md)) ensures existing backups remain intact.

## Consequences

- A compromised Wolkenschloss can stop pushing backups. The user is notified by the server, but there will be a detection gap.
- The Backup Server must implement monitoring for missing backups and alert the user.
- The Backup Server should also alert on anomalous backup size changes, which may indicate a compromised client pushing garbage data to exhaust storage.
- The existing Borg pull-mode configuration (`wolkenschloss.modules.mixins.borgPullModeBackupClient`, `borgPullModeBackupServer`) will need to be replaced with a push-mode equivalent.
