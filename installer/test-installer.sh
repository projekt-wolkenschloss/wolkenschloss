#!/usr/bin/env bash

# Test the custom installer ISO functionality
# This script helps verify that the custom installer works correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_TYPE]

Test custom Wolkenschloss installer ISO functionality.

OPTIONS:
    -h, --help          Show this help
    -i, --iso PATH      Path to ISO file to test
    -p, --port PORT     SSH port for testing (default: 2222)
    --no-build          Don't build ISO, use existing
    --headless          Run QEMU without GUI

TEST_TYPE:
    build               Build and basic validation (default)
    ssh                 Test SSH connectivity
    auth                Test authentication methods
    network             Test network configuration
    deployment          Test actual deployment scenario

EXAMPLES:
    $0                      # Build and basic test
    $0 -i custom.iso ssh    # Test SSH on existing ISO
    $0 deployment           # Full deployment test

EOF
}

build_test_iso() {
    log "Building test ISO..."
    
    # Use environment variables for testing
    export SSH_KEYS="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILx8vTsRnBzwg1EgPtlkjmYQPHd3h4vC2FPlQ7K8YVz3 test@wolkenschloss"
    export ROOT_PASSWORD_HASH='$6$rounds=4096$testsalt$test.hash.for.testing.only.never.use.in.production'
    
    "${SCRIPT_DIR}/build-iso.sh" --clean custom
    
    # Find the built ISO
    local iso_file
    iso_file=$(find "${SCRIPT_DIR}/../result" -name "*.iso" | head -1)
    
    if [[ ! -f "$iso_file" ]]; then
        error "Failed to build test ISO"
        return 1
    fi
    
    echo "$iso_file"
}

start_qemu() {
    local iso_file="$1"
    local ssh_port="${2:-2222}"
    local headless="${3:-false}"
    
    log "Starting QEMU with ISO: $(basename "$iso_file")"
    
    local display_args="-display gtk"
    if [[ "$headless" == "true" ]]; then
        display_args="-nographic"
    fi
    
    # Start QEMU in background
    qemu-system-x86_64 \
        -enable-kvm \
        -m 2048 \
        -cdrom "$iso_file" \
        -netdev user,id=net0,hostfwd=tcp::${ssh_port}-:22 \
        -device virtio-net,netdev=net0 \
        -boot d \
        $display_args \
        -pidfile "/tmp/qemu-test.pid" \
        -daemonize
    
    log "QEMU started with PID $(cat /tmp/qemu-test.pid)"
    log "SSH will be available on localhost:${ssh_port}"
    
    # Wait for system to boot
    log "Waiting for system to boot..."
    sleep 30
}

stop_qemu() {
    if [[ -f "/tmp/qemu-test.pid" ]]; then
        local pid
        pid=$(cat /tmp/qemu-test.pid)
        log "Stopping QEMU (PID: $pid)"
        kill "$pid" 2>/dev/null || true
        rm -f "/tmp/qemu-test.pid"
    fi
}

test_ssh_connectivity() {
    local ssh_port="${1:-2222}"
    local max_attempts="${2:-10}"
    
    log "Testing SSH connectivity on port $ssh_port"
    
    for ((i=1; i<=max_attempts; i++)); do
        log "Attempt $i/$max_attempts..."
        
        if ssh -o ConnectTimeout=5 \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -p "$ssh_port" \
               root@localhost \
               "echo 'SSH connection successful'" 2>/dev/null; then
            log "✅ SSH connectivity test passed"
            return 0
        fi
        
        sleep 10
    done
    
    error "❌ SSH connectivity test failed after $max_attempts attempts"
    return 1
}

test_authentication() {
    local ssh_port="${1:-2222}"
    
    log "Testing authentication methods"
    
    # Test 1: Password authentication (if configured)
    log "Testing password authentication..."
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o PasswordAuthentication=yes \
           -o PubkeyAuthentication=no \
           -p "$ssh_port" \
           root@localhost \
           "echo 'Password auth works'" 2>/dev/null; then
        log "✅ Password authentication working"
    else
        warn "⚠️  Password authentication failed (may be expected)"
    fi
    
    # Test 2: Key authentication (if keys are configured)
    log "Testing SSH key authentication..."
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o PasswordAuthentication=no \
           -o PubkeyAuthentication=yes \
           -p "$ssh_port" \
           root@localhost \
           "echo 'Key auth works'" 2>/dev/null; then
        log "✅ SSH key authentication working"
    else
        warn "⚠️  SSH key authentication failed (check key configuration)"
    fi
    
    # Test 3: User accounts
    log "Testing user accounts..."
    ssh -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "$ssh_port" \
        root@localhost \
        "id root && id nixos" 2>/dev/null || {
        error "❌ User account test failed"
        return 1
    }
    
    log "✅ Authentication tests completed"
}

test_network_config() {
    local ssh_port="${1:-2222}"
    
    log "Testing network configuration"
    
    # Get network info
    local network_info
    network_info=$(ssh -o ConnectTimeout=5 \
                      -o StrictHostKeyChecking=no \
                      -o UserKnownHostsFile=/dev/null \
                      -p "$ssh_port" \
                      root@localhost \
                      "ip addr show; echo '---'; ip route show" 2>/dev/null) || {
        error "❌ Failed to get network information"
        return 1
    }
    
    log "Network configuration:"
    echo "$network_info"
    
    # Test DNS
    log "Testing DNS resolution..."
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -p "$ssh_port" \
           root@localhost \
           "nslookup google.com" 2>/dev/null >/dev/null; then
        log "✅ DNS resolution working"
    else
        warn "⚠️  DNS resolution failed (may be expected in isolated test)"
    fi
    
    log "✅ Network configuration test completed"
}

test_deployment_readiness() {
    local ssh_port="${1:-2222}"
    
    log "Testing deployment readiness"
    
    # Check required tools
    local tools=("git" "nix" "nixos-install" "curl" "wget")
    for tool in "${tools[@]}"; do
        log "Checking for $tool..."
        if ssh -o ConnectTimeout=5 \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -p "$ssh_port" \
               root@localhost \
               "which $tool" 2>/dev/null >/dev/null; then
            log "✅ $tool available"
        else
            error "❌ $tool not found"
        fi
    done
    
    # Test Nix functionality
    log "Testing Nix functionality..."
    if ssh -o ConnectTimeout=5 \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -p "$ssh_port" \
           root@localhost \
           "nix --version && nix-build --version" 2>/dev/null >/dev/null; then
        log "✅ Nix functionality working"
    else
        error "❌ Nix functionality test failed"
        return 1
    fi
    
    # Test disk detection
    log "Testing disk detection..."
    local disks
    disks=$(ssh -o ConnectTimeout=5 \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -p "$ssh_port" \
               root@localhost \
               "lsblk" 2>/dev/null) || {
        error "❌ Disk detection failed"
        return 1
    }
    
    log "Available disks:"
    echo "$disks"
    
    log "✅ Deployment readiness test completed"
}

run_tests() {
    local test_type="$1"
    local iso_file="$2"
    local ssh_port="${3:-2222}"
    local headless="${4:-false}"
    
    # Cleanup function
    cleanup() {
        log "Cleaning up..."
        stop_qemu
    }
    trap cleanup EXIT
    
    case "$test_type" in
        build)
            log "Running build test..."
            if [[ ! -f "$iso_file" ]]; then
                error "ISO file not found: $iso_file"
                return 1
            fi
            log "✅ Build test passed - ISO exists: $(basename "$iso_file")"
            ;;
            
        ssh)
            start_qemu "$iso_file" "$ssh_port" "$headless"
            test_ssh_connectivity "$ssh_port"
            ;;
            
        auth)
            start_qemu "$iso_file" "$ssh_port" "$headless"
            test_ssh_connectivity "$ssh_port"
            test_authentication "$ssh_port"
            ;;
            
        network)
            start_qemu "$iso_file" "$ssh_port" "$headless"
            test_ssh_connectivity "$ssh_port"
            test_network_config "$ssh_port"
            ;;
            
        deployment)
            start_qemu "$iso_file" "$ssh_port" "$headless"
            test_ssh_connectivity "$ssh_port"
            test_authentication "$ssh_port"
            test_network_config "$ssh_port"
            test_deployment_readiness "$ssh_port"
            ;;
            
        *)
            error "Unknown test type: $test_type"
            return 1
            ;;
    esac
}

main() {
    local test_type="build"
    local iso_file=""
    local ssh_port="2222"
    local no_build=false
    local headless=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--iso)
                iso_file="$2"
                shift 2
                ;;
            -p|--port)
                ssh_port="$2"
                shift 2
                ;;
            --no-build)
                no_build=true
                shift
                ;;
            --headless)
                headless=true
                shift
                ;;
            build|ssh|auth|network|deployment)
                test_type="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check dependencies
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        error "QEMU not found. Install with: nix-shell -p qemu"
        exit 1
    fi
    
    # Build ISO if needed
    if [[ -z "$iso_file" && "$no_build" != "true" ]]; then
        log "No ISO specified, building test ISO..."
        iso_file=$(build_test_iso)
    fi
    
    if [[ ! -f "$iso_file" ]]; then
        error "ISO file not found: $iso_file"
        exit 1
    fi
    
    log "Starting tests for: $test_type"
    log "ISO file: $(basename "$iso_file")"
    log "SSH port: $ssh_port"
    
    # Run the tests
    if run_tests "$test_type" "$iso_file" "$ssh_port" "$headless"; then
        log "🎉 All tests passed!"
    else
        error "❌ Some tests failed!"
        exit 1
    fi
}

main "$@"
