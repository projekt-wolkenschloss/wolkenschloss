# Restore Process

Restore is a **first-class, guided process**. When a user sets up a new Wolkenschloss:

1. The installer offers a choice between a fresh install and restoring from backup.
2. The user locates the Sturmfeste server (local mode: advertised on the network; cloud mode: configured endpoint).
3. The user enters their decryption key in the UI.
4. The NixOS system is built from the configuration.
5. Application data and non-NixOS configuration is restored from the backup.
6. The system is fully restored.
