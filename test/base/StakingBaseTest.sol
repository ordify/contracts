// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.23;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Staking, StakingDefinitionCreate, StakingDefinition, Deposit} from "../../src/Staking.sol";
import "../Token.sol";

abstract contract StakingBaseTest is Test {
    // contracts
    Staking internal staking;
    IERC20 internal token;
    string internal stakingContractName = "Test staking";
    uint32 internal rate = 2000;
    uint32 internal lockDuration = 30 days; // 30 days = 30 * 24 = 720
    address internal treasury = 0x8C9bdbf68e52226448367c00948333Dda7d9bA20;

    address internal nonOwner = 0x1111111111111111111111111111111111111111;
    address internal staker = 0x2222222222222222222222222222222222222222;

    function setUp() public virtual {
        // greeter = new Greeter();
        // alice = new User(address(greeter));
        // bob = new User(address(greeter));
        // greeter.transferOwnership(address(alice));
        token = new Token("Test token", "Test", 2e9, 18);
 
        StakingDefinitionCreate[] memory stakingDefinitions = new StakingDefinitionCreate[](1);
        StakingDefinitionCreate memory firstDefinition = StakingDefinitionCreate({
            rate: uint32(2000),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(30 days),
            name: "Test staking",
            poolMultiplier: uint32(10_000)
        });

        stakingDefinitions[0] = firstDefinition;

        staking = new Staking(
            stakingDefinitions,
            address(token),
            treasury,
            true
        );

        token.transfer(staker, 500_000_000e18);

        token.approve(address(staking), 500_000_000e18);
        staking.addReward(500_000_000e18);
    }

    function helperStake(Staking _stakingContract, uint8 stakingDefinitionId, uint256 _amount) private {
        Deposit memory userDepositBefore = _stakingContract.getUserDeposit(stakingDefinitionId, staker);
        (, uint256 current) = _stakingContract.calculateRewards(stakingDefinitionId, staker);
        uint256 amount = uint256(_amount);
        vm.startPrank(staker);
        token.approve(address(_stakingContract), amount);
        _stakingContract.stake(stakingDefinitionId, amount);
        vm.stopPrank();

        Deposit memory userDeposit = _stakingContract.getUserDeposit(stakingDefinitionId, staker);
        assertEq(userDeposit.depositAmount, amount + userDepositBefore.depositAmount + current);

        StakingDefinition memory stakingDefinition = _stakingContract.getStakingDefinition(stakingDefinitionId);

        assertEq(
            userDeposit.depositTime + stakingDefinition.lockDuration,
            userDeposit.endTime
        );

        assertTrue(userDeposit.status == _stakingContract.DEPOSIT_STATUS_STAKING());
        assertTrue(_stakingContract.doesUserHaveActiveStake(stakingDefinitionId, staker));
    }

    function utilsStake(Staking _stakingContract, uint256 _amount) public {
        for (uint8 i = 0; i < _stakingContract.totalStakingDefinitions(); i++) {
            helperStake(_stakingContract, i, _amount);
        }
    }
}
