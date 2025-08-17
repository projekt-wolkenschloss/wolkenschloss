#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Wolkenschloss installer ISOs.

OPTIONS:
    -h, --help      Show this help
    -c, --clean     Clean build cache first
    -k, --ssh-key  Comma-separated SSH public key
    -K, --ssh-key-file
                    File containing SSH public key (overrides -k)
    -p, --password  Password hash for nixos user

Examples:
    $0                                    # Build for x86_64-linux
    $0 --clean               # Clean build cache first
    $0 -k "ssh-rsa AAAA..." # With SSH public key
    $0 -p "\$6\$rounds=4096\$salt\$hash"   # With password hash
EOF
}

# Default values
SYSTEM="x86_64-linux"
CLEAN=false
SSH_KEY=""
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
        -k|--ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        -K|--ssh-key-file)
            if [[ -f "$2" ]]; then
                SSH_KEY=$(cat "$2")
            else 
                echo "SSH key file not found: $2"
                exit 1
            fi
            shift 2
            ;;
        -p|--password)
            PASSWORD_HASH="$2"
            shift 2
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
if [[ -n "$SSH_KEY" ]]; then
    export VM_SSH_KEY="$SSH_KEY"
    echo "Using provided SSH key"
fi

if [[ -n "$PASSWORD_HASH" ]]; then
    export VM_NIXOS_PASSWORD_HASH="$PASSWORD_HASH"
    echo "Using provided password hash"
fi

if [[ "$CLEAN" == "true" ]]; then
    echo "Cleaning build cache..."
    rm -rf "$SCRIPT_DIR/result"
    rm -rf "$SCRIPT_DIR/iso"
    nix-collect-garbage
fi

echo "Building iso..."
nix build ".#packages.$SYSTEM.iso" --print-build-logs --impure

# Find and display the built ISO
ISO_FILE=$(find -L result -name "*.iso" | head -n1)
if [[ -n "$ISO_FILE" && -f "$ISO_FILE" ]]; then
    mkdir -p "$SCRIPT_DIR/iso"
    NEW_FILE_NAME="$(date +"%Y-%m-%dT%H-%M-%S")-wolkenschloss-nixos-installer.iso"
    sudo mv "$ISO_FILE" "$SCRIPT_DIR/iso/$NEW_FILE_NAME" || true
    rm -rf result
    echo "Built:" 
    ls -lah "$SCRIPT_DIR/iso/$NEW_FILE_NAME"
else
    echo "Could not find ISO file in result directory"
    rm -r result
    exit 1
fi
