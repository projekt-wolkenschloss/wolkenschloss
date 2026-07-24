# Risks and Technical Debts

## Tech Debt Borg Pull Model Implementation

The Borg-based pull model with reverse SSH, socat, and socket activation has three problems:

1. **Fragility**: The reverse SSH + socat + socket activation chain is complex and breaks easily.
2. **Shared encryption secret**: Both the Backup Server and Backup Client need the repo password, violating the client-only key requirement.
3. **Pull incompatibility with client-side encryption**: Client-side encryption with client-only key storage makes a true pull model architecturally infeasible. The server cannot create a backup without the client's encryption key.

See [DR-007](../decision-records/007-push-direction-with-missing-backup-alerts.md) for the decision to switch to push direction.
