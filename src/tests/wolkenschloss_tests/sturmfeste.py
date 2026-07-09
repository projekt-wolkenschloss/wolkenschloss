from test_driver.machine import QemuMachine
from importlib import resources
from pathlib import Path
import unittest

import hashlib, logging

log = logging.getLogger(__name__)

def start(tester: unittest.TestCase, vm_sturmfeste: QemuMachine, vm_other: QemuMachine) -> None:
    print("hey")

    vm_other.succeed("whoami")
    vm_sturmfeste.succeed("whoami")

    test_borg_backup(tester, vm_sturmfeste, vm_other)
    
    vm_other.succeed("stat /etc/dummy-data/precious-animals.txt")

def test_borg_backup(tester: unittest.TestCase, vm_sturmfeste: QemuMachine, vm_other: QemuMachine) -> None:
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
    data_dir = Path(str(resources.files(__package__).joinpath("test-data")))
    for file in data_dir.iterdir():
        log.info(file)
        print(file)
        with file.open("rb") as file_handle:
            hash = hashlib.file_digest(file_handle, "sha512")
            log.info(hash)
            print(hash)

    # with data_dir.joinpath("precious-animals.txt").open("rb") as file:
    #     hash = hashlib.file_digest(file, "sha512")
    #     log.info(hash.hexdigest)
        
    
