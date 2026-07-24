# Client-Side Encryption with Client-Only Key Storage

## Status

Accepted

## Decision

Backup data is encrypted on the Backup Client before transfer. The encryption key is held only by the Backup Client; the Backup Server never has access to it. The user is responsible for keeping an offline copy of the key.

## Context

The threat model requires that a compromised or untrusted Sturmfeste Backup Server cannot access backup contents. Otherwise a paid cloud backup would break with the core philosophy that only the user can access his data. This means the server must never possess the encryption key.

The previous Borg-based setup violated this by requiring both the Backup Server and Backup Client to know the repo password. This created two problems: the server could read backup contents, and a compromised server could decrypt all backup data.

Considered options:

- **Key escrow**: The backup service holds a sealed copy of the key (e.g., encrypted by the user's password), enabling recovery if the user loses their key. Rejected because it requires trusting the escrow holder and adds architectural complexity that conflicts with the threat model.
- **Server-managed encryption**: The server encrypts data after receiving it. Rejected because the server sees plaintext before encryption.
- **Client-only key storage**: Only the client holds the key. If the key is lost, backups are unrecoverable. The trade-off is an offline key copy (paper, password manager, USB) is a responsibility.

## Consequences

- The Backup Server stores only ciphertext and cannot read backup data, even if compromised.
- If the user loses their encryption key and has no offline copy, all backups are permanently unrecoverable.
- The restore process must prompt the user for their decryption key before accessing backup data.
- A pull-based backup model becomes architecturally infeasible (see [DR-007](./007-push-direction-with-missing-backup-alerts.md)).
