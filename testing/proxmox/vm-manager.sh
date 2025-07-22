#!/bin/bash

# VM Manager for NixOS Testing in Proxmox
# This script helps create, manage, and test different hardware configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TESTING_ROOT="${PROJECT_ROOT}/testing"

# Default configuration
# Load environment variables from .env
if [[ -f "${TESTING_ROOT}/.env" ]]; then
    set -a
    source "${TESTING_ROOT}/.env"
    set +a
fi

: "${PROXMOX_HOST:?PROXMOX_HOST must be set in .env}"
: "${PROXMOX_USER:?PROXMOX_USER must be set in .env}"
: "${PROXMOX_SUDO_PASSWORD:?PROXMOX_SUDO_PASSWORD must be set in .env}"

: "${PROXMOX_STORAGE:?PROXMOX_STORAGE must be set in .env}"
: "${PROXMOX_ISO_STORAGE:?PROXMOX_ISO_STORAGE must be set in .env}"
: "${VM_ROOT_PASSWORD:?VM_ROOT_PASSWORD must be set in .env}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Commands:
  create SCENARIO     Create VM from scenario
  start VMID          Start VM
  stop VMID           Stop VM  
  destroy VMID        Destroy VM
  list               List test VMs
  scenarios          List scenarios
  iso                Download NixOS ISO
  test SCENARIO      Run test cycle
  ssh VMID           SSH to VM
  install VMID       Run headless install

Options:
  --help              Show help
EOF
}

test_proxmox_connection() {
    log "Testing connection to Proxmox host $PROXMOX_HOST..."
    if ! echo "$PROXMOX_SUDO_PASSWORD" | ssh -o ConnectTimeout=10 -o BatchMode=no "${PROXMOX_USER}@${PROXMOX_HOST}" "sudo -S echo 'Connection test successful'" >/dev/null 2>&1; then
        error "Cannot connect to Proxmox host $PROXMOX_HOST as user $PROXMOX_USER or sudo failed"
        error "Please check your SSH configuration and sudo password"
        exit 1
    fi
}

check_dependencies() {
    local deps=("curl" "yq" "ssh" "scp" "grep")
    
    # Validate required environment variables
    if [[ -z "${PROXMOX_HOST}" ]]; then
        error "PROXMOX_HOST cannot be empty"
        exit 1
    fi
    
    if [[ -z "${PROXMOX_SUDO_PASSWORD}" ]]; then
        error "PROXMOX_SUDO_PASSWORD cannot be empty"
        exit 1
    fi
    
    # Check dependencies
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    
    test_proxmox_connection
}

# Execute command on Proxmox with sudo
pve_exec() {
    local cmd="$1"
    if ! echo "$PROXMOX_SUDO_PASSWORD" | ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "sudo -S $cmd"; then
        error "Failed to execute command on Proxmox host: $cmd"
        return 1
    fi
}

# Copy file to Proxmox
pve_copy() {
    local src="$1"
    local dst="$2"
    if ! scp "$src" "${PROXMOX_USER}@${PROXMOX_HOST}:$dst"; then
        error "Failed to copy file $src to Proxmox host"
        return 1
    fi
}

get_next_vmid() {
    # Get the next available VM ID starting from 9000 (for testing VMs)
    local start_id=9000
    local vmid=$start_id
    
    while pve_exec "qm status $vmid" &>/dev/null; do
        ((vmid++))
    done
    
    echo $vmid
}

get_vm_ip() {
    local vmid="$1"
    local timeout="${2:-60}"
    local count=0
    
    log "Waiting for VM $vmid to get IP address..."
    
    while [[ $count -lt $timeout ]]; do
        local ip
        ip=$(pve_exec "qm guest cmd $vmid network-get-interfaces 2>/dev/null" | \
             grep -o '"ip-address":"[0-9.]*"' | \
             grep -v '127.0.0.1' | \
             head -1 | \
             cut -d'"' -f4 2>/dev/null || true)
        
        if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
            echo "$ip"
            return 0
        fi
        
        sleep 2
        ((count += 2))
    done
    
    error "VM $vmid did not get IP address within ${timeout}s"
    return 1
}

create_vm() {
    local scenario="$1"
    local scenario_file="${TESTING_ROOT}/scenarios/${scenario}.yaml"
    
    if [[ ! -f "$scenario_file" ]]; then
        error "Scenario file not found: $scenario_file"
        exit 1
    fi
    
    log "Creating VM for scenario: $scenario"
    
    local vmid
    vmid=$(get_next_vmid)
    local vm_name="nixos-test-${scenario}-${vmid}"
    
    # Parse scenario configuration
    local memory
    memory=$(yq '.vm.memory' "$scenario_file")
    local cores
    cores=$(yq '.vm.cores' "$scenario_file")
    local disks_count
    disks_count=$(yq '.vm.disks | length' "$scenario_file")
    
    log "Creating VM $vmid ($vm_name) with $memory MB RAM, $cores cores, $disks_count disks"
    
    # Create the VM
    pve_exec "qm create $vmid \
        --name '$vm_name' \
        --memory $memory \
        --cores $cores \
        --net0 'virtio,bridge=vmbr0' \
        --boot 'order=ide2;scsi0' \
        --ostype l26 \
        --cpu cputype=host \
        --agent enabled=1 \
        --bios ovmf \
        --machine q35 \
        --scsihw virtio-scsi-single \
        --efidisk0 '${PROXMOX_STORAGE}:0,efitype=4m,pre-enrolled-keys=0'"
    
    # Add disks based on scenario
    for i in $(seq 0 $((disks_count - 1))); do
        local disk_size
        disk_size=$(yq -r ".vm.disks[$i].size" "$scenario_file")
        local disk_type
        disk_type=$(yq ".vm.disks[$i].type // \"scsi\"" "$scenario_file")
        local disk_id="scsi$i"
        
        debug "Adding disk $disk_id: ${disk_size} (${disk_type})"
        
        pve_exec "qm set $vmid \
            --${disk_id} ${PROXMOX_STORAGE}:${disk_size},iothread=1"
    done
    
    # Set CD-ROM to NixOS ISO
    local nixos_iso
    nixos_iso=$(get_nixos_iso)
    if [[ -n "$nixos_iso" ]]; then
        pve_exec "qm set $vmid --ide2 ${nixos_iso},media=cdrom"
    else
        warn "No NixOS ISO found. Please upload one manually."
    fi
    
    log "VM $vmid created successfully"
    echo "VMID: $vmid"
    echo "Name: $vm_name"
    echo "Scenario: $scenario"
    
    # Store VM metadata
    echo "scenario=$scenario" > "/tmp/nixos-test-vm-${vmid}.meta"
    echo "vm_name=$vm_name" >> "/tmp/nixos-test-vm-${vmid}.meta"
    echo "root_password=$VM_ROOT_PASSWORD" >> "/tmp/nixos-test-vm-${vmid}.meta"
}

get_nixos_iso() {
    # Look for NixOS ISO in the ISO storage
    local isos
    isos=$(pve_exec "pvesm list $PROXMOX_ISO_STORAGE --content iso" | grep -i nixos-minimal | head -1 | awk '{print $1}' || true)
    echo "$isos"
}

download_nixos_iso() {
    local version="${1:-25.05}"
    local iso_name="nixos-minimal-${version}-x86_64-linux.iso"
    local download_url="https://channels.nixos.org/nixos-${version}/latest-nixos-minimal-x86_64-linux.iso"
    
    log "Downloading NixOS ${version} ISO..."
    
    # Download to temporary location
    local temp_iso="/tmp/${iso_name}"
    curl -L "$download_url" -o "$temp_iso"
    
    # Upload to Proxmox storage
    log "Uploading ISO to Proxmox storage..."
    pve_copy "$temp_iso" "/tmp/${iso_name}"
    pve_exec "pvesm upload $PROXMOX_ISO_STORAGE /tmp/${iso_name} $iso_name"
    pve_exec "rm -f /tmp/${iso_name}"
    
    # Cleanup
    rm -f "$temp_iso"
    
    log "NixOS ISO downloaded and uploaded successfully"
}

list_vms() {
    log "NixOS Test VMs:"
    pve_exec "qm list" | grep -E "nixos-test-" || echo "No test VMs found"
}

list_scenarios() {
    log "Available test scenarios:"
    for scenario in "${TESTING_ROOT}/scenarios"/*.yaml; do
        if [[ -f "$scenario" ]]; then
            local name
            name=$(basename "$scenario" .yaml)
            local description
            description=$(yq '.description' "$scenario" 2>/dev/null || echo "No description")
            echo "  $name: $description"
        fi
    done
}

start_vm() {
    local vmid="$1"
    log "Starting VM $vmid..."
    pve_exec "qm start $vmid"
}

stop_vm() {
    local vmid="$1"
    log "Stopping VM $vmid..."
    pve_exec "qm stop $vmid"
}

ssh_vm() {
    local vmid="$1"
    
    # Get VM IP
    local vm_ip
    vm_ip=$(get_vm_ip "$vmid")
    if [[ -z "$vm_ip" ]]; then
        error "Could not get IP for VM $vmid"
        return 1
    fi
    
    log "Connecting to VM $vmid at $vm_ip"
    
    # Get root password from metadata
    local meta_file="/tmp/nixos-test-vm-${vmid}.meta"
    local password="$VM_ROOT_PASSWORD"
    if [[ -f "$meta_file" ]]; then
        password=$(grep "^root_password=" "$meta_file" | cut -d'=' -f2 || echo "$VM_ROOT_PASSWORD")
    fi
    
    log "Use password: $password"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$vm_ip"
}

destroy_vm() {
    local vmid="$1"
    
    warn "This will completely destroy VM $vmid and all its data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Destroying VM $vmid..."
        pve_exec "qm stop $vmid" 2>/dev/null || true
        sleep 2
        pve_exec "qm destroy $vmid --purge"
        rm -f "/tmp/nixos-test-vm-${vmid}.meta"
        log "VM $vmid destroyed"
    else
        log "Operation cancelled"
    fi
}

run_headless_install() {
    local vmid="$1"
    local scenario="${2:-single-disk}"
    
    log "Running headless NixOS installation on VM $vmid"
    
    # Get VM IP
    local vm_ip
    vm_ip=$(get_vm_ip "$vmid" 120)  # Wait up to 2 minutes for IP
    if [[ -z "$vm_ip" ]]; then
        error "Could not get IP for VM $vmid"
        return 1
    fi
    
    log "VM $vmid is available at $vm_ip"
    
    # Get metadata
    local meta_file="/tmp/nixos-test-vm-${vmid}.meta"
    local password="$VM_ROOT_PASSWORD"
    if [[ -f "$meta_file" ]]; then
        scenario=$(grep "^scenario=" "$meta_file" | cut -d'=' -f2 || echo "$scenario")
        password=$(grep "^root_password=" "$meta_file" | cut -d'=' -f2 || echo "$VM_ROOT_PASSWORD")
    fi
    
    log "Installing scenario: $scenario"
    
    # Determine disko configuration
    local disko_config="./machines/nixos-testing/partitioning-disko.nix"
    local flake_config="nixos-testing-1"
    
    if [[ -f "${PROJECT_ROOT}/testing/scenarios/${scenario}-disko.nix" ]]; then
        disko_config="./testing/scenarios/${scenario}-disko.nix"
        case "$scenario" in
            "raid-mirror") flake_config="nixos-testing-mirror" ;;
            "raidz") flake_config="nixos-testing-raidz" ;;
            "small-disk") flake_config="nixos-testing-small" ;;
        esac
    fi
    
    # Create installation script
    local install_script="/tmp/nixos-install-${vmid}.sh"
    cat > "$install_script" << EOF
#!/bin/bash
set -euo pipefail

# Set root password for SSH access
echo "root:${password}" | chpasswd

# Enable SSH
systemctl start sshd
systemctl enable sshd

# Clone repository
cd /tmp
git clone https://github.com/projekt-wolkenschloss/wolkenschloss.git
cd wolkenschloss

# Run disko partitioning
echo "Running disko partitioning..."
nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- --mode disko ${disko_config}

# Install NixOS
echo "Installing NixOS..."
nixos-install --flake .#${flake_config} --no-root-password

echo "Installation completed successfully!"
EOF
    
    # Copy and run installation script on VM
    log "Copying installation script to VM..."
    # Copy via Proxmox host (since we're always remote)
    pve_copy "$install_script" "/tmp/nixos-install-${vmid}.sh"
    echo "$PROXMOX_SUDO_PASSWORD" | ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "sudo -S scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/nixos-install-${vmid}.sh root@${vm_ip}:/tmp/"
    pve_exec "rm -f /tmp/nixos-install-${vmid}.sh"
    
    log "Running installation on VM..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$vm_ip" "chmod +x /tmp/nixos-install-${vmid}.sh && /tmp/nixos-install-${vmid}.sh"
    
    # Cleanup
    rm -f "$install_script"
    
    log "Headless installation completed successfully!"
    log "VM $vmid is now ready. SSH: root@$vm_ip (password: $password)"
}

run_test_cycle() {
    local scenario="$1"
    local headless="${2:-false}"
    
    log "Running complete test cycle for scenario: $scenario"
    
    # Create VM
    local vm_output
    vm_output=$(create_vm "$scenario")
    local vmid
    vmid=$(echo "$vm_output" | grep "VMID:" | cut -d' ' -f2)
    
    if [[ -z "$vmid" ]]; then
        error "Failed to get VM ID"
        return 1
    fi
    
    # Start VM
    start_vm "$vmid"
    
    if [[ "$headless" == "true" ]]; then
        log "Running headless installation..."
        run_headless_install "$vmid" "$scenario"
        
        log "Installation completed. VM $vmid is ready for testing."
        log "SSH: root@$(get_vm_ip "$vmid") (password: $VM_ROOT_PASSWORD)"
    else
        # Wait for VM to be ready
        log "Waiting for VM to boot (60 seconds)..."
        sleep 60
        
        log "VM $vmid is ready for manual testing"
        log "Connect via Proxmox console or SSH to: root@$(get_vm_ip "$vmid" 30 || echo "IP_NOT_AVAILABLE")"
        log "Root password: $VM_ROOT_PASSWORD"
    fi
    
    log ""
    log "When done testing, run: $0 destroy $vmid"
}


main() {    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                usage
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    check_dependencies
    
    case "$command" in
        create)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 create SCENARIO"
                exit 1
            fi
            create_vm "$1"
            ;;
        start)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 start VMID"
                exit 1
            fi
            start_vm "$1"
            ;;
        stop)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 stop VMID"
                exit 1
            fi
            stop_vm "$1"
            ;;
        ssh)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 ssh VMID"
                exit 1
            fi
            ssh_vm "$1"
            ;;
        install)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 install VMID"
                exit 1
            fi
            run_headless_install "$1"
            ;;
        destroy)
            if [[ $# -ne 1 ]]; then
                error "Usage: $0 destroy VMID"
                exit 1
            fi
            destroy_vm "$1"
            ;;
        list)
            list_vms
            ;;
        scenarios)
            list_scenarios
            ;;
        iso)
            if [[ $# -eq 0 ]]; then
                download_nixos_iso
            else
                download_nixos_iso "$1"
            fi
            ;;
        test)
            if [[ $# -lt 1 || $# -gt 2 ]]; then
                error "Usage: $0 test SCENARIO [--headless]"
                exit 1
            fi
            local headless=false
            if [[ "${2:-}" == "--headless" ]]; then
                headless=true
            fi
            run_test_cycle "$1" "$headless"
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
