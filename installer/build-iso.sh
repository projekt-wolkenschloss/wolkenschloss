#!/usr/bin/env bash

# Wolkenschloss Installer ISO Builder
# This script builds custom NixOS installer ISOs with pre-configured authentication

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
ISO_NAME="wolkenschloss-installer"
OUTPUT_DIR="${PROJECT_ROOT}/result"
TEMP_DIR="/tmp/wolkenschloss-iso-build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [CONFIG]

Build custom Wolkenschloss installer ISO with pre-configured authentication.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -o, --output DIR    Output directory (default: ${OUTPUT_DIR})
    -n, --name NAME     ISO base name (default: ${ISO_NAME})
    --clean             Clean build artifacts before building
    --test              Build and test in QEMU
    --method METHOD     Build method: nixos-generators, manual, or flake (default: nixos-generators)

CONFIG:
    base               Build basic installer (base-installer.nix)
    custom             Build custom installer with auth (custom-installer.nix) [default]
    secure             Build secure installer (secure-installer.nix)

EXAMPLES:
    $0                          # Build custom installer
    $0 secure                   # Build secure installer
    $0 --method flake custom    # Build custom installer using flake method
    $0 --test base             # Build and test base installer

ENVIRONMENT VARIABLES:
    DEBUG=true                  Enable debug output
    SSH_KEYS="key1,key2"       Comma-separated SSH keys to embed
    ROOT_PASSWORD_HASH         Custom root password hash
    NIXOS_PASSWORD_HASH        Custom nixos user password hash

For password hash generation:
    mkpasswd -m sha-512 -R 4096 "your-password"

For SSH key format:
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxx... user@host
EOF
}

check_dependencies() {
    local deps=("nix" "nix-build")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        error "Please install Nix: https://nixos.org/download.html"
        exit 1
    fi
    
    # Check for nixos-generators if using that method
    if [[ "${BUILD_METHOD}" == "nixos-generators" ]]; then
        if ! nix-env -q nixos-generators &> /dev/null && ! command -v nixos-generate &> /dev/null; then
            warn "nixos-generators not found in PATH"
            log "Installing nixos-generators..."
            nix-env -f https://github.com/nix-community/nixos-generators/archive/master.tar.gz -i || {
                error "Failed to install nixos-generators"
                exit 1
            }
        fi
    fi
}

generate_config() {
    local config_type="$1"
    local temp_config="${TEMP_DIR}/installer-config.nix"
    
    mkdir -p "${TEMP_DIR}"
    
    # Base configuration
    local base_config="${SCRIPT_DIR}/installer/${config_type}-installer.nix"
    
    if [[ ! -f "$base_config" ]]; then
        error "Configuration file not found: $base_config"
        exit 1
    fi
    
    # Create enhanced configuration with environment overrides
    cat > "$temp_config" << EOF
# Generated Wolkenschloss Installer Configuration
# Base: ${config_type}-installer.nix
# Generated: $(date)

{ config, pkgs, lib, ... }:

let
  # Environment variable overrides
  customRootHash = builtins.getEnv "ROOT_PASSWORD_HASH";
  customNixosHash = builtins.getEnv "NIXOS_PASSWORD_HASH";
  customSSHKeys = builtins.getEnv "SSH_KEYS";
  
  # Parse SSH keys from environment
  sshKeysList = if customSSHKeys != "" 
    then lib.splitString "," customSSHKeys
    else [];
    
in {
  imports = [ ${base_config} ];
  
  # Override passwords if provided
  users.users.root = lib.mkIf (customRootHash != "") {
    hashedPassword = lib.mkForce customRootHash;
  };
  
  users.users.nixos = lib.mkIf (customNixosHash != "") {
    hashedPassword = lib.mkForce customNixosHash;
  };
  
  # Add SSH keys if provided
  users.users.root.openssh.authorizedKeys.keys = lib.mkIf (sshKeysList != []) (
    lib.mkForce sshKeysList
  );
  
  users.users.nixos.openssh.authorizedKeys.keys = lib.mkIf (sshKeysList != []) (
    lib.mkForce sshKeysList  
  );
  
  # Add build information
  environment.etc."wolkenschloss-installer-info".text = ''
    Wolkenschloss Installer ISO
    Built: $(date)
    Config: ${config_type}
    Method: ${BUILD_METHOD}
    Git Hash: $(cd ${PROJECT_ROOT} && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  '';
}
EOF

    echo "$temp_config"
}

build_with_nixos_generators() {
    local config_file="$1"
    local output_name="$2"
    
    log "Building ISO with nixos-generators..."
    
    if command -v nixos-generate &> /dev/null; then
        nixos-generate -f iso -c "$config_file" -o "${OUTPUT_DIR}/${output_name}"
    else
        nix run github:nix-community/nixos-generators -- -f iso -c "$config_file" -o "${OUTPUT_DIR}/${output_name}"
    fi
}

build_manual() {
    local config_file="$1"
    local output_name="$2"
    
    log "Building ISO manually with nix-build..."
    
    nix-build '<nixpkgs/nixos>' \
        -A config.system.build.isoImage \
        -I nixos-config="$config_file" \
        -o "${OUTPUT_DIR}/${output_name}"
}

build_with_flake() {
    local config_type="$1"
    local output_name="$2"
    
    log "Building ISO with flake method..."
    
    # Create temporary flake
    local flake_dir="${TEMP_DIR}/flake"
    mkdir -p "$flake_dir"
    
    cat > "${flake_dir}/flake.nix" << EOF
{
  description = "Wolkenschloss Custom Installer ISO";
  
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  
  outputs = { self, nixpkgs }: {
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, modulesPath, ... }: {
          imports = [ ${SCRIPT_DIR}/installer/${config_type}-installer.nix ];
        })
      ];
    };
  };
}
EOF
    
    # Build with flake
    cd "$flake_dir"
    nix build .#nixosConfigurations.installer.config.system.build.isoImage -o "${OUTPUT_DIR}/${output_name}"
}

test_iso() {
    local iso_path="$1"
    
    if [[ ! -f "$iso_path" ]]; then
        error "ISO file not found: $iso_path"
        return 1
    fi
    
    log "Testing ISO in QEMU..."
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        warn "QEMU not found. Install with: nix-shell -p qemu"
        return 1
    fi
    
    # Run QEMU with the ISO
    log "Starting QEMU (press Ctrl+Alt+G to release mouse, Ctrl+Alt+Q to quit)..."
    qemu-system-x86_64 \
        -enable-kvm \
        -m 2048 \
        -cdrom "$iso_path" \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net,netdev=net0 \
        -boot d \
        -display gtk
}

clean_build() {
    log "Cleaning build artifacts..."
    rm -rf "${TEMP_DIR}"
    rm -rf "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"
}

main() {
    local config_type="custom"
    local verbose=false
    local clean=false
    local test_iso_flag=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                export DEBUG=true
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--name)
                ISO_NAME="$2"  
                shift 2
                ;;
            --clean)
                clean=true
                shift
                ;;
            --test)
                test_iso_flag=true
                shift
                ;;
            --method)
                BUILD_METHOD="$2"
                shift 2
                ;;
            base|custom|secure)
                config_type="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set default build method
    BUILD_METHOD="${BUILD_METHOD:-nixos-generators}"
    
    # Validate build method
    case "$BUILD_METHOD" in
        nixos-generators|manual|flake)
            ;;
        *)
            error "Invalid build method: $BUILD_METHOD"
            error "Valid methods: nixos-generators, manual, flake"
            exit 1
            ;;
    esac
    
    log "Starting Wolkenschloss installer ISO build"
    log "Configuration: $config_type"
    log "Build method: $BUILD_METHOD"
    log "Output directory: $OUTPUT_DIR"
    
    # Clean if requested
    if [[ "$clean" == "true" ]]; then
        clean_build
    fi
    
    # Check dependencies
    check_dependencies
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate configuration
    local config_file
    config_file=$(generate_config "$config_type")
    debug "Generated config: $config_file"
    
    # Build ISO
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local output_name="${ISO_NAME}-${config_type}-${timestamp}"
    
    case "$BUILD_METHOD" in
        nixos-generators)
            build_with_nixos_generators "$config_file" "$output_name"
            ;;
        manual)
            build_manual "$config_file" "$output_name"
            ;;
        flake)
            build_with_flake "$config_type" "$output_name"
            ;;
    esac
    
    # Find the built ISO
    local iso_file
    if [[ -L "${OUTPUT_DIR}/${output_name}" ]]; then
        # It's a symlink, follow it
        iso_file=$(readlink -f "${OUTPUT_DIR}/${output_name}")
        if [[ -d "$iso_file" ]]; then
            # It's a directory, find the ISO inside
            iso_file=$(find "$iso_file" -name "*.iso" | head -1)
        fi
    else
        # Look for ISO files in output directory
        iso_file=$(find "${OUTPUT_DIR}" -name "*.iso" | head -1)
    fi
    
    if [[ ! -f "$iso_file" ]]; then
        error "Failed to find built ISO file"
        exit 1
    fi
    
    # Get ISO info
    local iso_size
    iso_size=$(du -h "$iso_file" | cut -f1)
    
    log "✅ ISO built successfully!"
    log "📁 Location: $iso_file"
    log "📏 Size: $iso_size"
    log "🔧 Config: $config_type"
    log "⚙️  Method: $BUILD_METHOD"
    
    # Show usage instructions
    echo
    log "Usage instructions:"
    echo "1. Flash to USB: dd if='$iso_file' of=/dev/sdX bs=4M status=progress"
    echo "2. Or test in QEMU: $0 --test"
    echo "3. Boot target machine from USB"
    echo "4. SSH access available on port 22"
    
    if [[ "$config_type" == "custom" || "$config_type" == "secure" ]]; then
        echo "5. Default credentials (CHANGE IN PRODUCTION):"
        echo "   - root: see installer configuration"
        echo "   - nixos: see installer configuration"
    fi
    
    # Test if requested
    if [[ "$test_iso_flag" == "true" ]]; then
        test_iso "$iso_file"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log "🎉 Build completed successfully!"
}

# Set default build method
BUILD_METHOD="${BUILD_METHOD:-nixos-generators}"

# Run main function
main "$@"
