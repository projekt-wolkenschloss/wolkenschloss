# Testing

The testing directories aim is to provide ways to test the Wolkenschloss.
Currently, it includes a NixOS configuration that can be used to test the initial boot image on Proxmox.

## Boot Image Testing

To deploy Wolkenschloss remotely, we need an image to apply the config from that enables remote access.

This first step of a Wolkenschloss deployment can be tested as follows:

1. Create an installer iso from the `installer` directory
2. `cp .env.template .env` and fill in the required variables

To create a new password hash: `sudo apt install whois`, then `mkpasswd <your-password>`.

