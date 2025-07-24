#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help     Show this help
    -c, --clean    Clean build cache first

Examples:
    $0 custom
    $0 --clean
EOF
}

# Parse arguments
CLEAN=false

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
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# Clean if requested
if [[ "$CLEAN" == "true" ]]; then
    echo "🧹 Cleaning build cache..."
    nix-collect-garbage
    rm -rf result*
fi

# Build the installer
echo "🔨 Building installer..."
nix build ".#installer" --print-build-logs

echo "✅ Built: $(ls -la result/wolkenschloss-installer*.iso)"
