# Secret Operations

We use age, SOPS and sops-nix for secret ops.

To shorten the cli arguments for SOPS, we use a central `.sops.yaml` file. It states which (public) keys are able to encrypt the secrets.

Sops-nix transfers the SOPS-managed secret files to the hosts, and
decrypts them there, using the host's private keys and places them in `/run/secrets/...` folders.

Because of that, the public and/or private key of the target hosts must be known before the first installation. Currently, the public keys are added to the `.sops.yaml` file manually after the first installation failed due to missing keys.

## Creating a SOPS configuration

```yaml
# Used as variables in the creation rules
keys:
  - &human_heinrich age1evemaaaaaaaa
  - &server_sturmfeste age1uhzhwbbbbbbb
# - ...

# creation rules are evaluated sequentially, the first match wins
creation_rules:
  - path_regex: secrets\.(yaml|json|env|ini)$
    key_groups:
    - age:
      - *human_heinrich
      - *server_sturmfeste
```

## Converting ssh to age

You can read from a private key, or convert a public key.

To read from a private key, you need to provide the passphrase (if any) in the environment variable `SSH_TO_AGE_PASSPHRASE`:

```bash
# Read from a private key with pw
read -s SSH_TO_AGE_PASSPHRASE; export SSH_TO_AGE_PASSPHRASE
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 -o key.txt
```

Alternatively, you can convert a public key:

```bash
# Or convert a public key
PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5vRWckzzgJT4zxE+1ePsWvFCmws0IGpVXO8fl0hfu9 root@maximus-zone-aprill"; \
  echo "$PUBLIC_KEY" | nix run github:Mic92/ssh-to-age --
```

See also <https://github.com/Mic92/ssh-to-age>.

## Adding a key

1. Find the public key. Often in `/etc/ssh/ssh_host_*` or in `~/.ssh/`
2. Convert it to an age key (see above)
3. Add it to the `.sops.yaml` with `sops <encrypted-secrets-file>`
