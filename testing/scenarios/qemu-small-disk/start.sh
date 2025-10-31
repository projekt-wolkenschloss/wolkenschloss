
DRIVE_FILE="sata0.qcow"
if [[ -z $1 ]]; then
    DRIVE_FILE="$1"
fi

#!/usr/bin/env bash
/nix/store/sd37c3ra55bvhjc1dldqcqi9ykmsb7f2-qemu-10.1.0/bin/qemu-system-x86_64 \
    -name quickemu,process=quickemu \
    -bios /etc/OVMF/FV/OVMF.fd \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host \
    -smp cores=4,threads=4,sockets=1 \
    -m 8G \
    -device virtio-balloon \
    -pidfile ./quickemu.pid \
    -rtc base=utc,clock=host \
    -vga none \
    -device virtio-vga-gl,xres=1280,yres=800 \
    -display sdl,gl=on \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device qemu-xhci,id=spicepass \
    -chardev spicevmc,id=usbredirchardev1,name=usbredir \
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1 \
    -chardev spicevmc,id=usbredirchardev2,name=usbredir \
    -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2 \
    -chardev spicevmc,id=usbredirchardev3,name=usbredir \
    -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3 \
    -device pci-ohci,id=smartpass \
    -device usb-ccid \
    -chardev spicevmc,id=ccid,name=smartcard \
    -device ccid-card-passthru,chardev=ccid \
    -device usb-ehci,id=input \
    -device usb-kbd,bus=input.0 \
    -k DE_de \
    -device usb-tablet,bus=input.0 \
    -audiodev alsa,id=audio0 \
    -device intel-hda \
    -device hda-micro,audiodev=audio0 \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=quickemu,hostfwd=tcp::22220-:22,smb=/home/geothain/Public,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive media=cdrom,index=0,file=../../../installer/iso/2025-10-03T21-41-04-wolkenschloss-nixos-installer.iso \
    -fsdev local,id=fsdev0,path=/home/geothain/Public,security_model=mapped-xattr \
    -device virtio-9p-pci,fsdev=fsdev0,mount_tag=Public-geothain \
    -monitor unix:./quickemu-monitor.socket,server,nowait \
    -serial unix:./quickemu-serial.socket,server,nowait \
    -drive file=sata0.qcow,id=sata-drive,if=none \
    -device ahci,id=ahci \
    -device ide-hd,drive=sata-drive,bus=ahci.0 2>/dev/null
