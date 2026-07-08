from test_driver.machine import QemuMachine
from test_driver.driver import AssertionTester

def start(tester: AssertionTester, vm_sturmfeste: QemuMachine, vm_other: QemuMachine) -> None:
    print("hey")

    vm_other.succeed("whoami")
    vm_sturmfeste.succeed("whoami")

    vm_other.succeed("stat /etc/dummy-data/precious-animals.txt")
    
    test_borg_backup(tester, vm_sturmfeste, vm_other)

def test_borg_backup(tester: AssertionTester, vm_sturmfeste: QemuMachine, vm_other: QemuMachine) -> None:
    # Copy or boot other VM with static test data
    # Get checksums of test data
    # Check that backup is loaded unit: timer, service
    # Start backup
    # Wait with timeout for unit to complete
    # Check systemd status
    # Parse borg repo contents for completeness
    # Prepare restore folder
    # Restore backup
    # Checksum files and compare
    _out = vm_other.succeed("sha256sum /etc/dummy-data/precious-animals.txt")
    
