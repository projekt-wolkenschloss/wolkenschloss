# Backup Process

Self hosting introduces the responsibility of making your own backups. Without them, you will lose data when hardware fails, you get hacked, or you make a mistake.

This document describes the backup **requirements and process** for Projekt Wolkenschloss. See the [glossary](glossary.md) for term definitions.

## Deployment Modes

Users can deploy backups in two modes, both using the same backup software and protocol:

- **Local Mode**: The user operates both Wolkenschloss and a Sturmfeste backup server on their local network. The user is responsible for physical placement (e.g., if both machines are in the same room, a fire destroys both).
- **Cloud Mode**: The user operates only Wolkenschloss. A Sturmfeste instance is operated as a paid backup service. The cloud code is open source to increase trust.

Both modes use identical backup architecture. Only the location and operator of the backup server differ.

## Requirements

### Encryption

All backup data must be **encrypted on the Backup Client before transfer** (client-side encryption), and protected in transit (transit encryption). The Backup Server never has access to plaintext data.

The encryption key is held **only by the Backup Client**. The user is responsible for keeping an offline copy of the key (e.g., paper, password manager, USB in a drawer). If the key is lost, backups are permanently unrecoverable.

### Immutability

A compromised Wolkenschloss must not be able to delete, corrupt, or prune existing backups. This is enforced through **operational separation**:

- The Backup Client can only push new backups.
- Deletion and pruning of existing backups is managed exclusively by the Backup Server.

In local mode, that's the user. In cloud mode, the user must trust the provider.

### Backup Monitoring

Since the client pushes backups, a compromised client could silently stop pushing. Wolkenschloss or the Sturmfeste Backup Server must monitor for missing backups and alert the user when a backup is not received within the expected schedule.

Additionally, the server alerts on anomalous backup size changes, which may indicate a compromised client pushing garbage data to exhaust storage.

### Backup Verification

Backups can rot over time (bit rot, hardware failures). To prevent a backup going bad unnoticed, the Backup Server must periodically verify backup integrity.

### Backup Scope

Only application data and non-reproducible service configuration is backed up. The NixOS-based system configuration is fully reproducible and does not need backup.

Before each filesystem backup, database dumps are created separately to ensure consistency for applications using databases (PostgreSQL, MariaDB, SQLite, etc.).

### Backup Content Integrity

A compromised client could push a backup with tampered content (e.g., replacing a config file with a backdoor). The server cannot detect this due to client-side encryption. We unfortunately must accept this risk as we do not know any feasible way to prevent it. Retention of previous backup versions provides rollback capability that reduces the risk.

### Versioning

The server must retain multiple backup versions so users can restore from a point before accidental deletion, misconfiguration, or compromise. Schedule and retention policy are user-configurable. The default is nightly backups with a fixed retention policy.

## Threat Model

| Threat | Mitigation |
|---|---|
| Compromised Wolkenschloss deletes backups | Operational separation, client cannot delete |
| Compromised Wolkenschloss corrupts existing backups | Operational separation, client cannot modify existing backups |
| Compromised Wolkenschloss stops backups | Server alerts user on missing backups |
| Compromised Wolkenschloss fills server with garbage | Server alerts on anomalous size changes |
| Compromised Wolkenschloss pushes tampered content | Accepted risk; rollback via retention depth |
| Physical disaster destroys both machines | User responsibility for placement; can use multiple Sturmfeste instances |
| User loses encryption key | Backups are unrecoverable; user is responsible for offline key copy |
| Cloud operator reads backups | Client-side encryption prevents access |
| Cloud operator deletes backups | Accepted risk; trust in operator |
| Cloud operator disappears | Accepted risk; trust in operator |
