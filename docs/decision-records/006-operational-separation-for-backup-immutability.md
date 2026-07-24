# Operational Separation for Backup Immutability

## Status

Accepted

## Decision

The Backup Client can only push new backups. Deletion and pruning of existing backups is managed exclusively by the Backup Server. A compromised Wolkenschloss cannot delete, modify, or prune its own backup history.

## Context

Wolkenschloss has a large attack surface due to the amount of software it runs and its public exposure. If it is compromised, the attacker must not be able to destroy existing backups. This is the primary threat driving backup architecture decisions.

Considered options:

- **Protocol-level append-only**: The server rejects delete/prune commands from the client (e.g., `append_only` mode). The client still connects with credentials that could be revoked or misused.
- **Operational separation**: The client simply has no capability to delete or prune, it can only push. Pruning is a separate process on the server, independent of the client. This is the chosen option.
- **WORM semantics (true immutability)**: Once written, data cannot be deleted by anyone, even the server admin, for a retention period (e.g., S3 Object Lock, ZFS snapshots). Adds significant infrastructure complexity and is unnecessary for the current threat model: the concern is a compromised client, not a compromised server.

The server admin retains full control, which is acceptable because in local mode the user operates Sturmfeste themselves, and in cloud mode the user trusts the operator.

## Consequences

- Existing backups are safe from a compromised Wolkenschloss.
- Pruning and retention management must be implemented as a server-side process, not a client capability.
- The server admin (user or cloud operator) can delete backups if needed (e.g., to free storage).
- Backup versioning must be managed on the server side, ensuring the user can roll back to previous versions after accidental deletion or misconfiguration.
