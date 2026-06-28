from test_driver.machine import QemuMachine

def start(vm_sturmfeste: QemuMachine, vm_other: QemuMachine) -> None:
    print("hey")

    vm_other.succeed("whoami")
    vm_sturmfeste.succeed("whoami")

    vm_other.succeed("stat /etc/dummy-data/precious-animals.txt")
