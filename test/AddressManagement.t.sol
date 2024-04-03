// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./base/AddressManagementBaseTest.sol";

contract AddressManagementTest is AddressManagementBaseTest {
    function testDefaultChains() public {
        assertEq(addressManagement.supportedChains(0), "SOLANA");
        assertEq(addressManagement.supportedChains(1), "SUI");
        assertEq(addressManagement.supportedChains(2), "APTOS");
    }

    function testChainLengthGetter() public {
        assertEq(addressManagement.getNumberOfChains(), 3);
    }

    function testAddnewChain(string memory newChain) public {
        assertEq(addressManagement.getNumberOfChains(), 3);

        addressManagement.addChain(newChain);

        assertEq(addressManagement.getNumberOfChains(), 4);

        assertEq(addressManagement.supportedChains(addressManagement.getNumberOfChains() - 1), newChain);
    }

    function testAddnewChainShouldNotSucceedIfChainExist(string memory newChain) public {
        assertEq(addressManagement.getNumberOfChains(), 3);

        addressManagement.addChain(newChain);

        assertEq(addressManagement.getNumberOfChains(), 4);

        assertEq(addressManagement.supportedChains(addressManagement.getNumberOfChains() - 1), newChain);

        vm.expectRevert(bytes("chain already exist"));
        addressManagement.addChain(newChain);
    }

    function testSubmitMyAddress(string memory cusotmAddress) public {
        addressManagement.submitAddress(0, cusotmAddress);
        assertEq(
            addressManagement.userAddresses(address(this), 0),
            cusotmAddress
        );
    }
}
