// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/Vesting.sol";
import "../Token.sol";

abstract contract VestingBaseTest is Test {

    // contracts

    IERC20 internal token;
    Vesting internal vesting;
    Phase[] internal phases;
    uint256 internal constant YEAR_IN_SECONDS = 365 days;
    uint256 internal constant MONTH_IN_SECONDS = YEAR_IN_SECONDS / 12;
    uint256 internal cliffDuration = MONTH_IN_SECONDS;
    uint256 internal stage1Duration = MONTH_IN_SECONDS;
    uint256 internal stage2Duration = 9 * MONTH_IN_SECONDS;
    uint256 startDate = 1648650600;
    

    function setUp() public virtual {
        vm.warp(1645455879);
        token = new Token("Test token", "Test", 1e59, 18);

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
    }
}
