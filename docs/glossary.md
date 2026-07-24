# Glossary

**Wolkenschloss**:
The self-hosting server that runs user applications and services.

**Sturmfeste**:
A backup server that receives and stores encrypted backups. May be user-operated (local) or rented (cloud).

## Backup

Backup in Projekt Wolkenschloss covers the requirements and process for protecting user data against hardware failure, accidental deletion, and compromise.

## Language

**Backup Client**:
The machine being backed up. Typically Wolkenschloss.

**Backup Server**:
The machine receiving and storing backups. Sturmfeste.

**Local Mode**:
Deployment where the user has both Wolkenschloss and Sturmfeste on their local network.

**Cloud Mode**:
Deployment where the user has only Wolkenschloss. The Sturmfeste instance is a paid service.

**Operational Separation**:
The Backup Client can only push new backups. Deletion and pruning of existing backups is performed by the Backup Server independently.
