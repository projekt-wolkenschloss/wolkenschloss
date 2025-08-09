#!/bin/bash

# VM Manager for Proxmox
# This script helps to manage test different hardware configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TESTING_ROOT="${PROJECT_ROOT}/testing"
DEFAULT_VM_MDNS_NAME="wolkenschloss-nixos-test-vm"

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
: "${VM_NIXOS_USER_PASSWORD:?VM_NIXOS_USER_PASSWORD must be set in .env}"
: "${VM_SSH_KEY:?VM_SSH_KEY must be set in .env}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Commands:
  create SCENARIO ISO-PATH    Create VM from scenario
  start VMID          Start VM
  stop VMID           Stop VM  
  destroy VMID        Destroy VM
  list               List test VMs
  scenarios          List scenarios
  ssh VMID           SSH to VM

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
    local deps=("curl" "yq" "ssh" "scp" "grep" "sshpass" "avahi-resolve")
    
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

get_vm_mac_address() {
    local vmid="$1"
    
    # Get MAC address from VM config
    local mac
    mac=$(pve_exec "qm config $vmid" | grep "^net0:" | sed -n 's/.*virtio=\([^,]*\).*/\1/p')
    
    if [[ -z "$mac" ]]; then
        error "Could not find MAC address for VM $vmid"
        return 1
    fi
    
    echo "$mac"
}

parse_ip_from_arp_table() {
    local mac="$1"
    
    # Check ARP table for the given MAC address
    local ip
    ip=$(pve_exec "arp -a" | grep -i "$mac" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1)

    if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
        echo "$ip"
        return 0
    fi

    error "Could not find IP for MAC: $mac"
    return 1
}

resolve_ipv4_via_mDNS() {
    local hostname="$1"
    local ip=""
    
    ip=$(avahi-resolve -4 -n "${hostname}.local" 2>/dev/null | awk '{print $2}' | head -1)
    if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi
    return 1
}

# TODO simplify
get_vm_ip() {
    local vmid="$1"

    ip=$(resolve_ipv4_via_mDNS "$DEFAULT_VM_MDNS_NAME")
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Get MAC address from VM config
    local mac
    mac=$(get_vm_mac_address "$vmid")
    
    log "Looking for VM $vmid with MAC: $mac"
    
    # First try: Check existing ARP table
    local ip
    ip=$(parse_ip_from_arp_table "$mac")
    if ! [[ -n "$ip" ]] && pve_exec "ping -c 1 -W 2 '$ip' >/dev/null 2>&1"; then
        log "Found IP in ARP table: $ip"
        echo "$ip"
        return 0
    fi
    
    ip=$(pve_exec "ip neighbour | grep -i '$mac' | awk '{print \$1}' | head -1")
    if pve_exec "ping -c 1 -W 2 '$ip' >/dev/null 2>&1"; then
        log "Found IP in neighbour table: $ip"
        echo "$ip"
        return 0
    fi

    log "MAC not found in ARP table, performing network scan to populate ARP..."
    
    # Determine network range (adjust as needed for your environment)
    local network="$NETWORK_RANGE"
    
    # Use nmap to ping scan the network (this populates the ARP table)
    pve_exec "nmap -sn $network >/dev/null 2>&1" || {
        warn "nmap scan failed, trying broadcast ping instead"
        # Extract broadcast address from network range (e.g., 192.168.1.0/24 -> 192.168.1.255)
        local broadcast
        broadcast=$(echo "$network" | sed 's/\.0\/24$/.255/' | sed 's/\.0\/16$/.255.255/' | sed 's/\.0\.0\/8$/.255.255.255/')
        pve_exec "ping -c 3 -b $broadcast >/dev/null 2>&1" || true
    }
    
    # Now check ARP table again immediately after scan
    ip=$(parse_ip_from_arp_table "$mac")
    if pve_exec "ping -c 1 -W 2 '$ip' >/dev/null 2>&1"; then
        echo "$ip"
        return 0
    fi
        
    error "Could not find IP for VM $vmid (MAC: $mac) in ARP table"
    return 1
}

upload_iso_to_proxmox() {
    local iso_path="$1"
    
    if [[ ! -f "$iso_path" ]]; then
        error "ISO file not found: $iso_path"
        return 1
    fi
    
    local iso_filename
    iso_filename=$(basename "$iso_path")

    local existing_iso
    existing_iso=$(pve_exec "pvesm list $PROXMOX_ISO_STORAGE --content iso" | grep "$iso_filename" | head -1 | awk '{print $1}' || true)
        
    if [[ -n "$existing_iso" ]]; then
        log "ISO already exists in Proxmox storage: $existing_iso"
        return 0
    fi
    
    log "Uploading ISO to Proxmox storage: $iso_filename"

    pve_copy "$iso_path" "/tmp/$iso_filename"
    pve_exec "cp /tmp/$iso_filename /var/lib/vz/template/iso/$iso_filename"
    pve_exec "rm -f /tmp/$iso_filename"
    
    log "ISO uploaded successfully: /var/lib/vz/template/iso/$iso_filename"
}

create_vm() {
    local scenario="$1"
    local iso_path="$2"
    local scenario_file="${TESTING_ROOT}/scenarios/${scenario}.yaml"

    local nixos_iso
    if ! [[ -n "$iso_path" && -f "$iso_path" ]]; then
        error "Invalid ISO path: $iso_path"
        exit 1
    fi

    log "Using provided ISO: $iso_path"
    upload_iso_to_proxmox "$iso_path"
    
    # Extract ISO filename
    local iso_filename
    iso_filename=$(basename "$iso_path")
    
    # Set the ISO path in Proxmox format
    nixos_iso="$PROXMOX_ISO_STORAGE:iso/$iso_filename"

    if [[ -z "$nixos_iso" ]]; then
        error "No NixOS ISO $nixos_iso found."
        exit 1
    fi

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

    pve_exec "qm set $vmid --ide2 ${nixos_iso},media=cdrom"
    
    log "VM $vmid created successfully"
    echo "VMID: $vmid"
    echo "Name: $vm_name"
    echo "Scenario: $scenario"
    
    # Store VM metadata
    echo "scenario=$scenario" > "/tmp/nixos-test-vm-${vmid}.meta"
    echo "vm_name=$vm_name" >> "/tmp/nixos-test-vm-${vmid}.meta"
}

get_nixos_iso() {
    # Look for NixOS ISO in the ISO storage
    local isos
    isos=$(pve_exec "pvesm list $PROXMOX_ISO_STORAGE --content iso" | grep -i nixos-minimal | head -1 | awk '{print $1}' || true)
    echo "$isos"
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
    
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$VM_SSH_KEY" "nixos@$vm_ip"; then
        return 0
    fi
    log "Connecting with ssh key $VM_SSH_KEY failed"

    local password="$VM_NIXOS_USER_PASSWORD"
    if ! sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "nixos@$vm_ip"; then
        warn "Failed to log into vm $vmid via password"
        exit 1
    fi
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
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 create SCENARIO ISO-PATH"
                exit 1
            fi
            create_vm "$1" "$2"
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
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
