// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/AddressManagement.sol";

abstract contract AddressManagementBaseTest is Test {
    AddressManagement internal addressManagement;

    function setUp() public virtual {
        addressManagement = new AddressManagement();
    }
}
