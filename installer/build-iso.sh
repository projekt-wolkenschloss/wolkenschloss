#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SYSTEM]

Build Wolkenschloss installer ISOs.

OPTIONS:
    -h, --help      Show this help
    -c, --clean     Clean build cache first
    -k, --ssh-keys  Comma-separated SSH public keys
    -p, --password  Password hash for nixos user

Environment Variables:
    SSH_KEYS            Comma-separated SSH public keys
    NIXOS_PASSWORD_HASH Password hash for nixos user

Examples:
    $0                                    # Build for x86_64-linux
    $0 --clean               # Clean build cache first
    $0 -k "ssh-rsa AAAA...,ssh-ed25519..." # With SSH keys
    $0 -p "\$6\$rounds=4096\$salt\$hash"   # With password hash
EOF
}

# Default values
SYSTEM="x86_64-linux"
CLEAN=false
SSH_KEYS=""
PASSWORD_HASH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -k|--ssh-keys)
            SSH_KEYS="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD_HASH="$2"
            shift 2
            ;;
        x86_64-linux|aarch64-linux)
            SYSTEM="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Set environment variables if provided
if [[ -n "$SSH_KEYS" ]]; then
    export SSH_KEYS
    echo "Using provided SSH keys"
fi

if [[ -n "$PASSWORD_HASH" ]]; then
    export NIXOS_PASSWORD_HASH="$PASSWORD_HASH"
    echo "Using provided password hash"
fi

# Clean if requested
if [[ "$CLEAN" == "true" ]]; then
    echo "Cleaning build cache..."
    nix-collect-garbage
    rm -rf result*
fi

echo "Building iso..."
nix build ".#packages.$SYSTEM.iso" --print-build-logs

# Find and display the built ISO
ISO_FILE=$(find -L result -name "*.iso" | head -n1)
if [[ -n "$ISO_FILE" && -f "$ISO_FILE" ]]; then
    echo "Built: $(ls -la "$ISO_FILE")"
    echo "ISO location: $ISO_FILE"
else
    echo "Could not find ISO file in result directory"
    exit 1
fi
