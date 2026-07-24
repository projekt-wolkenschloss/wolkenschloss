# Restic as the new Backup Software

## Status

Accepted

## Decision

We will replace borg with [restic](https://restic.net/) as the backup tool for Wolkenschloss.

## Context

The previous Borg-based setup used pull mode (reverse SSH + socat + socket activation), which had several problems documented (fragility, shared encryption secret, and difficulties with client-only key storage). Both Borg and restic were evaluated against the requirements in [DR-005](../../decision-records/005-client-side-encryption-with-client-only-key-storage.md), [DR-006](../../decision-records/006-operational-separation-for-backup-immutability.md), and [DR-007](../../decision-records/007-push-direction-with-missing-backup-alerts.md).

Full evaluations: [restic](restic-requirements-evaluation.md), [Borg](borg-requirements-evaluation.md).

Both tools satisfy the core requirements (client-side encryption, push direction, versioning, database dumps). The deciding factors are:

**Append-only enforcement**: Restic's `rest-server --append-only` blocks DELETE and overwrite operations at the HTTP level. The client physically cannot delete backups. Borg's `borg serve --append-only` only prevents compaction (space freeing). The client can still run `borg prune` and make archives disappear from the manifest. The data is physically recoverable via transaction rollback, but logically deleted. Restic's model provides a stronger operational separation as required by [DR-006](../../decision-records/006-operational-separation-for-backup-immutability.md).

**Cloud storage backends**: Restic natively supports S3, B2, Azure, GCS, Swift, SFTP, and REST. Borg 1.x only supports SSH. For cloud mode, this is decisive: restic can back up directly to an object storage bucket, while Borg would require a VPS running `borg serve`. Borg 2.0 adds S3 support but is not yet stable.

## Consequences

- Retention policies on the restic server must be carefull chosen to prevent snapshot crowding attacks.
- The existing Borg pull-mode code be replaced with a restic rebuild.
- Existing Borg repositories must be migrated.
- Trade-offs by choosing restic over Borg
  - Restic's key is stored encrypted in the repository (on the server). A server compromise combined with a weak password could expose backups, requiring strong passphrases.
  - Restic's memory usage can be higher for large repositories.
