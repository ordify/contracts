// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Vesting, Phase} from "../../src/Vesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableToken is ERC20 {
    constructor() ERC20("USDT", "USDT") {
          _mint(0x00a329c0648769A73afAc7F9381E08FB43dBEA72, 1_000_000e18);
          _mint(msg.sender, 1_000_000e18);
    }
}

/**
 * @title VestingEchidnaTestScript
 * @dev Used for save transctions to json file which will be trasformed to etheno based json using rust lib `foundry2echidna`
 */
contract VestingEchidnaTestScript is Script {
    address echidnaUser1 = address(0x10000);
    address echidnaUser2 = address(0x20000);
    address echidnaUser3 = address(0x30000);
    address echidnaContractAddress = 0x00a329c0648769A73afAc7F9381E08FB43dBEA72;

    Vesting internal vesting;

    IERC20 internal token;
    Phase[] internal phases;
    uint256 startDate = 1648650600;

    function run() external {
        // this is private key from GANACHE in our case, 
        // but it can be any that has balance on netowrk wher eyou executing it.
        vm.startBroadcast(0x4f9a86461179d14783afa16b8398ac04d6bfb1283d33b9b88470a5d13217fdde);

        StableToken stableToken = new StableToken();
        token = IERC20(address(stableToken));

        phases.push(Phase(1333, 1651329000, 0)); // '2022-04-30T14:30:00.000Z'
        phases.push(Phase(1333, 1653921000, 0)); // '2022-05-30T14:30:00.000Z'
        phases.push(Phase(1333, 1656599400, 0)); // '2022-06-30T14:30:00.000Z'
        phases.push(Phase(1333, 1659191400, 0)); // '2022-07-30T14:30:00.000Z'
        phases.push(Phase(1333, 1661869800, 0)); // '2022-08-30T14:30:00.000Z'
        phases.push(Phase(1335, 1664548200, 0)); // '2022-09-30T14:30:00.000Z'

        vesting = new Vesting({
            _vestedToken: token,
            _name: "VestingIDO",
            _startDateAt: 1648650600, /// '2022-03-30T14:30:00.000Z'
            _claimableAtStart: 2000,
            _phases: phases,
            _refundGracePeriodDuration: 7 days
        });

        vesting.transferOwnership(echidnaContractAddress);

        vm.stopBroadcast();
    }
}