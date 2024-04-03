// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Launchpad} from "../../src/Launchpad.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableToken is ERC20 {
    constructor() ERC20("USDT", "USDT") {
          _mint(0x00a329c0648769A73afAc7F9381E08FB43dBEA72, 1_000_000e18);
          _mint(msg.sender, 1_000_000e18);
    }
}

/**
 * @title LaunchpadEchidnaTestScript
 * @dev Used for save transctions to json file which will be trasformed to etheno based json using rust lib `foundry2echidna`
 */
contract LaunchpadEchidnaTestScript is Script {
    address echidnaUser1 = address(0x10000);
    address echidnaUser2 = address(0x20000);
    address echidnaUser3 = address(0x30000);

    uint256 initialBlockTime = block.timestamp;
    uint32 saleStartDate = 0;
    uint128 stableTarget = 80_000e18;
    uint32 round1Duration = 2 hours;

    uint256 verfifierPrivateKeyECDSA = 0x1010101010101010101010101010101010101010101010101010101010101010;
    address verifierPublicKeyECDSA = vm.addr(verfifierPrivateKeyECDSA);

    function run() external {
        // this is private key from GANACHE in our case, 
        // but it can be any that has balance on netowrk wher eyou executing it.
        vm.startBroadcast(0x4f9a86461179d14783afa16b8398ac04d6bfb1283d33b9b88470a5d13217fdde);

        StableToken stableToken = new StableToken();
        IERC20 stableCoin = IERC20(address(stableToken));


        // Create an instance of the smart contract (doing that will deploy the contract when the script runs)
        Launchpad launchpad = new Launchpad(
            verifierPublicKeyECDSA,
            stableTarget,
            saleStartDate,
            stableCoin,
            round1Duration
        );

        launchpad.transferOwnership(0x00a329c0648769A73afAc7F9381E08FB43dBEA72);

        stableToken.transfer(echidnaUser1, 50_000e18);
        stableToken.transfer(echidnaUser2, 50_000e18);
        stableToken.transfer(echidnaUser3, 50_000e18);
        
        vm.stopBroadcast();
    }
}