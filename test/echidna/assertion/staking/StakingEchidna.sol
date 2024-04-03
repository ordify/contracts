// SPDX-License Identifier:MIT
pragma solidity 0.8.23;

import {Staking, Deposit, StakingDefinition, StakingDefinitionCreate, WithdrawFeeState} from "../../../../src/Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
interface IHevm {
    function prank(address) external;
}

contract StakingEchidna {
    address echidnaUser1 = address(0x10000);
    address echidnaUser2 = address(0x20000);
    address echidnaUser3 = address(0x30000);
    address echidnaUser4 = address(0x40000);
    address echidnaUser5 = address(0x50000);
    address echidnaUser6 = address(0x60000);
    address echidnaUser7 = address(0x70000);
    address echidnaUser8 = address(0x80000);
    address echidnaUser9 = address(0x90000);
    address echidnaUser10 = address(0x11000);

    address[] private senders;

    address internal treasury = address(0x44000);

    address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    IHevm hevm = IHevm(HEVM_ADDRESS);

    Staking public staking;
    IERC20 public token;

    bool private pass = true;
    uint private createdAt = block.timestamp;

    uint256 initialBlockTime = block.timestamp;

    uint256 totalRewardLocalCalculation;

    event TestProggres(
        string msg,
        uint256 amount
    );
    event TestProggres(
        string msg,
        address value
    );
    event TestProggres(
        string msg,
        bool value
    );
    event TestProggres(
        string msg,
        string value
    );

    constructor() {
        // addresses for staking and token are taken from init.json file. or easier in script folder from latest json transactions, before it is converted ofr echdna init json.
        staking = Staking(0x171A71FaBC220f291fF53B73e24C64854080433F);
        token = IERC20(0x9E042954166732dC06d91768436CE6406640d310);

        senders.push(echidnaUser1);
        senders.push(echidnaUser2);
        senders.push(echidnaUser3);
        senders.push(echidnaUser4);
        senders.push(echidnaUser5);
        senders.push(echidnaUser6);
        senders.push(echidnaUser7);
        senders.push(echidnaUser8);
        senders.push(echidnaUser9);
        senders.push(echidnaUser10);
        
        // token.approve(address(staking), 1_000_000e18);
        // staking.addReward(1_000_000e18);
    }

    function test_staking(uint8 stakingDefinitionId, uint256 _amount) public {
        address sender = msg.sender;

        require(!staking.isStopped());
        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        require(stakingDefinition.enabled);

        emit TestProggres("sender", sender);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        uint256 tokenBalance = token.balanceOf(sender);
        require(_amount <= tokenBalance);
        require(_amount > 0);

        hevm.prank(sender);
        token.approve(address(staking), _amount);

        Deposit memory depositSenderBefore = staking.getUserDeposit(stakingDefinitionId, sender);
        emit TestProggres("depositSenderBefore.depositTime", depositSenderBefore.depositTime);
        emit TestProggres("depositSenderBefore.endTime", depositSenderBefore.endTime);
        emit TestProggres("depositSenderBefore.depositAmount", depositSenderBefore.depositAmount);
        emit TestProggres("depositSenderBefore.status", depositSenderBefore.status);

        if(depositSenderBefore.status == staking.DEPOSIT_STATUS_NOT_STAKING()) {
            assert(depositSenderBefore.depositAmount == 0);
        } else if(depositSenderBefore.status == staking.DEPOSIT_STATUS_STAKING()) {
            assert(depositSenderBefore.depositAmount > 0);
        } else if(depositSenderBefore.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN()) {
            assert(depositSenderBefore.depositAmount > 0);
        }

        (, uint256 currentRewards) =staking.calculateRewards(stakingDefinitionId, sender);

        hevm.prank(sender);
        staking.stake(stakingDefinitionId, _amount);

        totalRewardLocalCalculation += currentRewards;

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSenderAfter.depositTime", depositSenderAfter.depositTime);
        emit TestProggres("depositSenderAfter.endTime", depositSenderAfter.endTime);
        emit TestProggres("depositSenderAfter.depositAmount", depositSenderAfter.depositAmount);
        emit TestProggres("depositSenderAfter.status", depositSenderAfter.status);
        
        if(depositSenderBefore.status == staking.DEPOSIT_STATUS_NOT_STAKING() || depositSenderBefore.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN()) {
            emit TestProggres("checking", "assert(depositSenderAfter.depositAmount == _amount)");
            assert(depositSenderAfter.depositAmount == _amount);
        } else {
            emit TestProggres("checking", "assert(depositSenderBefore.depositAmount + _amount + currentRewards == depositSenderAfter.depositAmount);");
            assert(depositSenderBefore.depositAmount + _amount + currentRewards == depositSenderAfter.depositAmount);
        }
        emit TestProggres("checking", "assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING());");
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING());

        uint256 totalDeposits = calculateTotalDeposits();

        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_early_withdraw(uint8 stakingDefinitionId) public {
        if(!staking.prematureWithdrawEnabled()) {
            staking.setPrematureWithdrawEnabled(true);
        }

        address sender = msg.sender;

        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("sender", sender);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));

        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);

        require(block.timestamp < depositSender.endTime);
        require(block.timestamp > depositSender.depositTime);
        
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);

        WithdrawFeeState memory withdrawFeeState = staking.withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, sender);
        emit TestProggres("withdrawFeeState.stakingDefinitionId", withdrawFeeState.stakingDefinitionId);
        emit TestProggres("withdrawFeeState.globalFee", withdrawFeeState.globalFee);
        emit TestProggres("withdrawFeeState.globalFeeEnabled", withdrawFeeState.globalFeeEnabled);
        emit TestProggres("withdrawFeeState.depositRecordedFee", withdrawFeeState.depositRecordedFee);
        emit TestProggres("withdrawFeeState.depositStatus", withdrawFeeState.depositStatus);
        emit TestProggres("withdrawFeeState.withdrawFeeUsed", withdrawFeeState.withdrawFeeUsed);
        if(withdrawFeeState.globalFeeEnabled) {
            assert(withdrawFeeState.withdrawFeeUsed == withdrawFeeState.globalFee);
        } else if(depositSender.depositTime > stakingDefinition.withdrawFeeUpdateOn) {
            assert(withdrawFeeState.withdrawFeeUsed == stakingDefinition.withdrawFeePercentage);
        } else {
            assert(withdrawFeeState.withdrawFeeUsed == depositSender.withdrawFeePercentage);
        }

        (uint256 totalRewards, uint256 currentRewards) =staking.calculateRewards(stakingDefinitionId, sender);
        uint256 withdrawFee = staking.calculateWithdrawFee(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);
        emit TestProggres("withdrawFee", withdrawFee);

        hevm.prank(sender);
        staking.withdraw(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("depositSender.depositAmount + currentRewards - withdrawFee", depositSender.depositAmount + currentRewards - withdrawFee);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter >= balanceBefore);
        assert(balanceAfter - balanceBefore == depositSender.depositAmount + currentRewards - withdrawFee);
        if(withdrawFee > 0) {
            assert(balanceAfterTreasury > balanceBeforeTreasury);
        } else {
            assert(balanceAfterTreasury == balanceBeforeTreasury);
        }
        assert(balanceAfterTreasury - balanceBeforeTreasury == withdrawFee);

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN());

        uint256 totalDeposits = calculateTotalDeposits();

        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_matured_withdraw(uint8 stakingDefinitionId) public {
        address sender = msg.sender;

        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        emit TestProggres("sender", sender);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));
        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);

        require(block.timestamp > depositSender.endTime);
        
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);

        WithdrawFeeState memory withdrawFeeState = staking.withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, sender);
        emit TestProggres("withdrawFeeState.stakingDefinitionId", withdrawFeeState.stakingDefinitionId);
        emit TestProggres("withdrawFeeState.globalFee", withdrawFeeState.globalFee);
        emit TestProggres("withdrawFeeState.globalFeeEnabled", withdrawFeeState.globalFeeEnabled);
        emit TestProggres("withdrawFeeState.depositRecordedFee", withdrawFeeState.depositRecordedFee);
        emit TestProggres("withdrawFeeState.depositStatus", withdrawFeeState.depositStatus);
        emit TestProggres("withdrawFeeState.withdrawFeeUsed", withdrawFeeState.withdrawFeeUsed);
        if(withdrawFeeState.globalFeeEnabled) {
            assert(withdrawFeeState.withdrawFeeUsed == withdrawFeeState.globalFee);
        } else if(depositSender.depositTime > stakingDefinition.withdrawFeeUpdateOn) {
            assert(withdrawFeeState.withdrawFeeUsed == stakingDefinition.withdrawFeePercentage);
        } else {
            assert(withdrawFeeState.withdrawFeeUsed == depositSender.withdrawFeePercentage);
        }

        (uint256 totalRewards, uint256 currentRewards) =staking.calculateRewards(stakingDefinitionId, sender);
        uint256 withdrawFee = staking.calculateWithdrawFee(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);
        emit TestProggres("withdrawFee", withdrawFee);
        assert(withdrawFee == 0);
        assert(currentRewards == totalRewards);

        uint256 totalParticipantsBefore = staking.totalActiveStakings();
        emit TestProggres("totalParticipantsBefore", totalParticipantsBefore);
        assert(totalParticipantsBefore > 0);

        hevm.prank(sender);
        staking.withdraw(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("depositSender.depositAmount + currentRewards - withdrawFee", depositSender.depositAmount + currentRewards - withdrawFee);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter > balanceBefore);
        assert(balanceAfter - balanceBefore == depositSender.depositAmount + currentRewards - withdrawFee);
        assert(balanceAfterTreasury == balanceBeforeTreasury);
        assert(balanceAfterTreasury - balanceBeforeTreasury == withdrawFee);

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN());

        uint256 totalParticipantsAfter = staking.totalActiveStakings();
        emit TestProggres("totalParticipantsAfter", totalParticipantsAfter);
        assert(totalParticipantsAfter == totalParticipantsBefore - 1);

        uint256 totalDeposits = calculateTotalDeposits();
        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_matured_withdraw_without_prematureWIthdrawEnabled(uint8 stakingDefinitionId) public {
        if(staking.prematureWithdrawEnabled()) {
            staking.setPrematureWithdrawEnabled(false);
        }

        address sender = msg.sender;

        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        emit TestProggres("sender", sender);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));
        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);

        require(block.timestamp > depositSender.endTime);
        
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);

        WithdrawFeeState memory withdrawFeeState = staking.withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, sender);
        emit TestProggres("withdrawFeeState.stakingDefinitionId", withdrawFeeState.stakingDefinitionId);
        emit TestProggres("withdrawFeeState.globalFee", withdrawFeeState.globalFee);
        emit TestProggres("withdrawFeeState.globalFeeEnabled", withdrawFeeState.globalFeeEnabled);
        emit TestProggres("withdrawFeeState.depositRecordedFee", withdrawFeeState.depositRecordedFee);
        emit TestProggres("withdrawFeeState.depositStatus", withdrawFeeState.depositStatus);
        emit TestProggres("withdrawFeeState.withdrawFeeUsed", withdrawFeeState.withdrawFeeUsed);
        if(withdrawFeeState.globalFeeEnabled) {
            assert(withdrawFeeState.withdrawFeeUsed == withdrawFeeState.globalFee);
        } else if(depositSender.depositTime > stakingDefinition.withdrawFeeUpdateOn) {
            assert(withdrawFeeState.withdrawFeeUsed == stakingDefinition.withdrawFeePercentage);
        } else {
            assert(withdrawFeeState.withdrawFeeUsed == depositSender.withdrawFeePercentage);
        }

        (uint256 totalRewards, uint256 currentRewards) =staking.calculateRewards(stakingDefinitionId, sender);
        uint256 withdrawFee = staking.calculateWithdrawFee(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);
        emit TestProggres("withdrawFee", withdrawFee);
        assert(withdrawFee == 0);
        assert(currentRewards == totalRewards);

        uint256 totalParticipantsBefore = staking.totalActiveStakings();
        emit TestProggres("totalParticipantsBefore", totalParticipantsBefore);
        assert(totalParticipantsBefore > 0);

        hevm.prank(sender);
        staking.withdraw(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("depositSender.depositAmount + currentRewards - withdrawFee", depositSender.depositAmount + currentRewards - withdrawFee);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter > balanceBefore);
        assert(balanceAfter - balanceBefore == depositSender.depositAmount + currentRewards - withdrawFee);
        assert(balanceAfterTreasury == balanceBeforeTreasury);
        assert(balanceAfterTreasury - balanceBeforeTreasury == withdrawFee);

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN());

        uint256 totalParticipantsAfter = staking.totalActiveStakings();
        emit TestProggres("totalParticipantsAfter", totalParticipantsAfter);
        assert(totalParticipantsAfter == totalParticipantsBefore - 1);

        uint256 totalDeposits = calculateTotalDeposits();
        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_emergency_withdraw_no_reward(uint8 stakingDefinitionId) public {
        address sender = msg.sender;

        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("sender", sender);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));

        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);

        require(block.timestamp > depositSender.depositTime);
        
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);
        uint256 rewardBalanceBefore = staking.rewardBalance();

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);
        emit TestProggres("rewardBalanceBefore", rewardBalanceBefore);

        WithdrawFeeState memory withdrawFeeState = staking.withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, sender);
        emit TestProggres("withdrawFeeState.stakingDefinitionId", withdrawFeeState.stakingDefinitionId);
        emit TestProggres("withdrawFeeState.globalFee", withdrawFeeState.globalFee);
        emit TestProggres("withdrawFeeState.globalFeeEnabled", withdrawFeeState.globalFeeEnabled);
        emit TestProggres("withdrawFeeState.depositRecordedFee", withdrawFeeState.depositRecordedFee);
        emit TestProggres("withdrawFeeState.depositStatus", withdrawFeeState.depositStatus);
        emit TestProggres("withdrawFeeState.withdrawFeeUsed", withdrawFeeState.withdrawFeeUsed);
        if(withdrawFeeState.globalFeeEnabled) {
            assert(withdrawFeeState.withdrawFeeUsed == withdrawFeeState.globalFee);
        } else if(depositSender.depositTime > stakingDefinition.withdrawFeeUpdateOn) {
            assert(withdrawFeeState.withdrawFeeUsed == stakingDefinition.withdrawFeePercentage);
        } else {
            assert(withdrawFeeState.withdrawFeeUsed == depositSender.withdrawFeePercentage);
        }

        (uint256 totalRewards, uint256 currentRewards) =staking.calculateRewards(stakingDefinitionId, sender);
        uint256 withdrawFee = staking.calculateWithdrawFee(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);
        emit TestProggres("withdrawFee", withdrawFee);

        hevm.prank(sender);
        staking.emergencyWithdrawWithoutReward(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);
        emit TestProggres("rewardBalanceAfter", staking.rewardBalance());

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("depositSender.depositAmount + currentRewards - withdrawFee", depositSender.depositAmount + currentRewards - withdrawFee);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter >= balanceBefore);
        assert(balanceAfter - balanceBefore == depositSender.depositAmount - withdrawFee);
        if(withdrawFee > 0) {
            assert(balanceAfterTreasury > balanceBeforeTreasury);
        } else {
            assert(balanceAfterTreasury == balanceBeforeTreasury);
        }
        assert(balanceAfterTreasury - balanceBeforeTreasury == withdrawFee);
        assert(rewardBalanceBefore == staking.rewardBalance());

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING_WITHDRAWN());

        uint256 totalDeposits = calculateTotalDeposits();

        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_claim_reward(uint8 stakingDefinitionId) public {
        address sender = msg.sender;

        require(stakingDefinitionId < staking.totalStakingDefinitions());
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("sender", sender);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));
        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);
        require(block.timestamp > depositSender.depositTime);

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);

        (uint256 totalRewards, uint256 currentRewards) = staking.calculateRewards(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);

        hevm.prank(sender);
        staking.claimReward(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("currentRewards", currentRewards);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter >= balanceBefore);
        assert(balanceAfter - balanceBefore == currentRewards);
        assert(balanceAfterTreasury == balanceBeforeTreasury);

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING());
        assert(depositSenderAfter.rewardClaimedTime == block.timestamp);
        (, uint256 currentRewardsAfter) = staking.calculateRewards(stakingDefinitionId, sender);
        assert(currentRewardsAfter == 0);

        uint256 totalDeposits = calculateTotalDeposits();

        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalance", staking.stakedBalance());

        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_claim_and_stake(uint8 stakingDefinitionId) public {
        address sender = msg.sender;

        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("sender", sender);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);

        require(staking.doesUserHaveActiveStake(stakingDefinitionId, sender));
        require(staking.prematureWithdrawEnabled());

        Deposit memory depositSender = staking.getUserDeposit(stakingDefinitionId, sender);

        require(block.timestamp > depositSender.depositTime);
        
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("depositSender.depositTime", depositSender.depositTime);
        emit TestProggres("depositSender.endTime", depositSender.endTime);
        emit TestProggres("depositSender.depositAmount", depositSender.depositAmount);

        (uint256 totalRewards, uint256 currentRewards) = staking.calculateRewards(stakingDefinitionId, sender);
        emit TestProggres("totalRewards", totalRewards);
        emit TestProggres("currentRewards", currentRewards);
        require(currentRewards > 0);

        uint256 balanceBefore = token.balanceOf(sender);
        uint256 balanceBeforeTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceBefore", balanceBefore);
        emit TestProggres("balanceBeforeTreasury", balanceBeforeTreasury);

        WithdrawFeeState memory withdrawFeeState = staking.withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, sender);
        emit TestProggres("withdrawFeeState.stakingDefinitionId", withdrawFeeState.stakingDefinitionId);
        emit TestProggres("withdrawFeeState.globalFee", withdrawFeeState.globalFee);
        emit TestProggres("withdrawFeeState.globalFeeEnabled", withdrawFeeState.globalFeeEnabled);
        emit TestProggres("withdrawFeeState.depositRecordedFee", withdrawFeeState.depositRecordedFee);
        emit TestProggres("withdrawFeeState.depositStatus", withdrawFeeState.depositStatus);
        emit TestProggres("withdrawFeeState.withdrawFeeUsed", withdrawFeeState.withdrawFeeUsed);
        if(withdrawFeeState.globalFeeEnabled) {
            assert(withdrawFeeState.withdrawFeeUsed == withdrawFeeState.globalFee);
        } else if(depositSender.depositTime > stakingDefinition.withdrawFeeUpdateOn) {
            assert(withdrawFeeState.withdrawFeeUsed == stakingDefinition.withdrawFeePercentage);
        } else {
            assert(withdrawFeeState.withdrawFeeUsed == depositSender.withdrawFeePercentage);
        }

        uint256 stakedBalanceBefore = staking.stakedBalance();
        uint256 rewardBalanceBefore = staking.rewardBalance();
        emit TestProggres("stakedBalanceBefore", stakedBalanceBefore);
        emit TestProggres("rewardBalanceBefore", rewardBalanceBefore);

        hevm.prank(sender);
        staking.claimAndStake(stakingDefinitionId);

        uint256 balanceAfter = token.balanceOf(sender);
        uint256 balanceAfterTreasury = token.balanceOf(treasury);

        emit TestProggres("balanceAfter", balanceAfter);
        emit TestProggres("balanceAfterTreasury", balanceAfterTreasury);

        emit TestProggres("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
        emit TestProggres("depositSender.depositAmount + currentRewards", depositSender.depositAmount + currentRewards);
        emit TestProggres("balanceAfterTreasury - balanceBeforeTreasury", balanceAfterTreasury - balanceBeforeTreasury);

        assert(balanceAfter == balanceBefore);
        assert(balanceAfterTreasury == balanceBeforeTreasury);

        Deposit memory depositSenderAfter = staking.getUserDeposit(stakingDefinitionId, sender);
        emit TestProggres("depositSenderAfter.depositTime", depositSenderAfter.depositTime);
        emit TestProggres("depositSenderAfter.endTime", depositSenderAfter.endTime);
        emit TestProggres("depositSenderAfter.depositAmount", depositSenderAfter.depositAmount);
        emit TestProggres("depositSenderAfter.rewardClaimedTime", depositSenderAfter.rewardClaimedTime);

        uint256 totalDeposits = calculateTotalDeposits();

        emit TestProggres("totalDeposits", totalDeposits);
        emit TestProggres("stakedBalanceAfter", staking.stakedBalance());
        emit TestProggres("rewardBalanceAfter", staking.rewardBalance());

        assert(depositSenderAfter.status == staking.DEPOSIT_STATUS_STAKING());
        assert(depositSender.depositAmount + currentRewards == depositSenderAfter.depositAmount);
        assert(depositSenderAfter.endTime == block.timestamp + stakingDefinition.lockDuration);
        assert(depositSenderAfter.rewardClaimedTime == 0);

        assert(stakedBalanceBefore  + currentRewards == staking.stakedBalance());
        assert(rewardBalanceBefore  - currentRewards == staking.rewardBalance());
        assert(staking.stakedBalance() == totalDeposits);
    }

    function test_add_reward(uint256 rewardAmount) public {
        uint256 tokenBalance = token.balanceOf(address(this));
        require(rewardAmount <= tokenBalance);

        (
            uint256 recordedStakingBalanceBefore, 
            uint256 recordedRewardBalanceBefore,
            uint256 actualTokenBalanceBefore
        ) = staking.getContractState();

        emit TestProggres("recordedStakingBalanceBefore", recordedStakingBalanceBefore);
        emit TestProggres("recordedRewardBalanceBefore", recordedRewardBalanceBefore);
        emit TestProggres("actualTokenBalanceBefore", actualTokenBalanceBefore);

        token.approve(address(staking), rewardAmount);
        staking.addReward(rewardAmount);
        (
            uint256 recordedStakingBalanceAfter, 
            uint256 recordedRewardBalanceAfter,
            uint256 actualTokenBalanceAfter
        ) = staking.getContractState();

        emit TestProggres("recordedStakingBalanceAfter", recordedStakingBalanceAfter);
        emit TestProggres("recordedRewardBalanceAfter", recordedRewardBalanceAfter);
        emit TestProggres("actualTokenBalanceAfter", actualTokenBalanceAfter);

        assert(recordedRewardBalanceBefore + rewardAmount == recordedRewardBalanceAfter);
        assert(actualTokenBalanceBefore + rewardAmount == actualTokenBalanceAfter);
        assert(recordedStakingBalanceBefore == recordedStakingBalanceAfter);
    }

    function test_transfer_tokens_to_staking_and_sync(uint256 rewardAmount) public {
        uint256 tokenBalance = token.balanceOf(address(this));
        require(rewardAmount <= tokenBalance);
        require(rewardAmount > 0);

        (
            uint256 recordedStakingBalanceBefore, 
            uint256 recordedRewardBalanceBefore,
            uint256 actualTokenBalanceBefore
        ) = staking.getContractState();

        emit TestProggres("recordedStakingBalanceBefore", recordedStakingBalanceBefore);
        emit TestProggres("recordedRewardBalanceBefore", recordedRewardBalanceBefore);
        emit TestProggres("actualTokenBalanceBefore", actualTokenBalanceBefore);
        emit TestProggres("XXXX => totalRewardLocalCalculation", totalRewardLocalCalculation);
        
        assert(recordedStakingBalanceBefore - totalRewardLocalCalculation == actualTokenBalanceBefore - recordedRewardBalanceBefore);

        token.transfer(address(staking), rewardAmount);
        (
            uint256 recordedStakingBalanceAfterTransfer, 
            uint256 recordedRewardBalanceAfterTransfer,
            uint256 actualTokenBalanceAfterTransfer
        ) = staking.getContractState();

        emit TestProggres("recordedStakingBalanceAfterTransfer", recordedStakingBalanceAfterTransfer);
        emit TestProggres("recordedRewardBalanceAfterTransfer", recordedRewardBalanceAfterTransfer);
        emit TestProggres("actualTokenBalanceAfterTransfer", actualTokenBalanceAfterTransfer);

        assert(recordedRewardBalanceBefore == recordedRewardBalanceAfterTransfer);
        assert(actualTokenBalanceBefore + rewardAmount == actualTokenBalanceAfterTransfer);
        assert(recordedStakingBalanceBefore == recordedStakingBalanceAfterTransfer);

        staking.sync();

        (
            uint256 recordedStakingBalanceAfterSync, 
            uint256 recordedRewardBalanceAfterSync,
            uint256 actualTokenBalanceAfterSync
        ) = staking.getContractState();

        emit TestProggres("recordedStakingBalanceAfterSync", recordedStakingBalanceAfterSync);
        emit TestProggres("recordedRewardBalanceAfterSync", recordedRewardBalanceAfterSync);
        emit TestProggres("actualTokenBalanceAfterSync", actualTokenBalanceAfterSync);
        emit TestProggres("rewardAmount", rewardAmount);

        assert(actualTokenBalanceAfterTransfer == actualTokenBalanceAfterSync);
        assert(recordedStakingBalanceAfterTransfer == recordedStakingBalanceAfterSync);
        assert(actualTokenBalanceAfterTransfer - recordedStakingBalanceAfterTransfer == recordedRewardBalanceAfterSync);
        assert(recordedRewardBalanceAfterSync >= recordedRewardBalanceAfterTransfer);
        assert(actualTokenBalanceAfterTransfer == recordedRewardBalanceAfterSync + recordedStakingBalanceAfterSync);

        // totalRewardLocalCalculation needs to be calculated, as that is total amount added to stakingBalance but without transfering tokens,
        // this happens on adding new staking and you have existing one, then currentRewards are included as well in new amount.
        assert(actualTokenBalanceAfterTransfer == (recordedRewardBalanceAfterTransfer + rewardAmount + recordedStakingBalanceAfterSync) - totalRewardLocalCalculation);
        
        // now we reset extra reward amount as it is setteld with sync
        totalRewardLocalCalculation = 0; 
    }

    function test_setGlobalWithdrawFeeForStakingDefinition(uint8 stakingDefinitionId, uint8 withdrawFee) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        require(withdrawFee <= 100);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        

        staking.setGlobalWithdrawFeeForStakingDefinition(stakingDefinition.uniqueIdentifier, withdrawFee);
    }

    function test_removeGlobalWithdrawFeeForStakingDefinition(uint8 stakingDefinitionId) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        

        staking.removeGlobalWithdrawFeeForStakingDefinition(stakingDefinition.uniqueIdentifier);
    }

    function test_setWithdrawFee(uint8 stakingDefinitionId, uint8 withdrawFee) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        require(withdrawFee <= 100);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        

        staking.setWithdrawFee(stakingDefinition.uniqueIdentifier, withdrawFee);
    }

    function test_enableStakingDefinition(uint8 stakingDefinitionId) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        
        staking.enableStakingDefinition(stakingDefinition.uniqueIdentifier);

        StakingDefinition memory stakingDefinitionAfter = staking.getStakingDefinition(stakingDefinitionId);
        assert(stakingDefinitionAfter.enabled == true);
    }

    function test_setLockDuration(uint8 stakingDefinitionId, uint32 _lockDuration) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        require(_lockDuration <= 9120); // 380 days

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        
        staking.setLockDuration(stakingDefinition.uniqueIdentifier, uint32(_lockDuration * 3600));

        StakingDefinition memory stakingDefinitionAfter = staking.getStakingDefinition(stakingDefinitionId);

        emit TestProggres("stakingDefinitionAfter.name", stakingDefinitionAfter.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinitionAfter.uniqueIdentifier", stakingDefinitionAfter.uniqueIdentifier);
        emit TestProggres("stakingDefinitionAfter.rate", stakingDefinitionAfter.rate);
        emit TestProggres("stakingDefinitionAfter.lockDuration", stakingDefinitionAfter.lockDuration);
        emit TestProggres("stakingDefinitionAfter.withdrawFeePercentage", stakingDefinitionAfter.withdrawFeePercentage);

        assert(stakingDefinitionAfter.lockDuration == uint32(_lockDuration * 3600));
    }

    function test_setRate(uint8 stakingDefinitionId, uint8 _rate) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());
        require(_rate <= 200);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        
        staking.setRate(stakingDefinition.uniqueIdentifier, _rate);

        StakingDefinition memory stakingDefinitionAfter = staking.getStakingDefinition(stakingDefinitionId);

        emit TestProggres("stakingDefinitionAfter.name", stakingDefinitionAfter.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinitionAfter.uniqueIdentifier", stakingDefinitionAfter.uniqueIdentifier);
        emit TestProggres("stakingDefinitionAfter.rate", stakingDefinitionAfter.rate);
        emit TestProggres("stakingDefinitionAfter.lockDuration", stakingDefinitionAfter.lockDuration);
        emit TestProggres("stakingDefinitionAfter.withdrawFeePercentage", stakingDefinitionAfter.withdrawFeePercentage);

        assert(stakingDefinitionAfter.rate == _rate);
    }

    function test_setIsStopped(bool _isStopped) public {
        emit TestProggres("isStopped", staking.isStopped());
        staking.setIsStopped(_isStopped);
        emit TestProggres("isStopped", staking.isStopped());

        assert(staking.isStopped() == _isStopped);
    }

    function test_setPrematureWithdrawEnabled(bool _enabled) public {
        emit TestProggres("prematureWithdrawEnabled", staking.prematureWithdrawEnabled());
        staking.setPrematureWithdrawEnabled(_enabled);
        emit TestProggres("prematureWithdrawEnabled", staking.prematureWithdrawEnabled());

        assert(staking.prematureWithdrawEnabled() == _enabled);
    }

    function test_disableStakingDefinition(uint8 stakingDefinitionId) public {
        require(stakingDefinitionId <= staking.totalStakingDefinitions());

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", stakingDefinitionId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage);
        
        staking.disableStakingDefinition(stakingDefinition.uniqueIdentifier);

        StakingDefinition memory stakingDefinitionAfter = staking.getStakingDefinition(stakingDefinitionId);
        assert(stakingDefinitionAfter.enabled == false);
    }

    function test_addStakingDefinition(uint16 _rate, uint8 _withdrawFeePercentage, uint32 _lockDuration) public {
        require(_rate <= 200);
        require(_withdrawFeePercentage <= 100);
        require(_lockDuration <= 9120); // 380 days

        uint8 newId = staking.totalStakingDefinitions();
        uint16 rate = uint16(_rate);
        string memory name = string(abi.encodePacked("Test staking ", _lockDuration));
        uint8 withdrawFeePercentage =  uint8(_withdrawFeePercentage);
        uint32 lockDuration =  uint32(_lockDuration * 3600);

        staking.addStakingDefinition(
            StakingDefinitionCreate({
                rate: rate,
                withdrawFeePercentage: withdrawFeePercentage,
                lockDuration: lockDuration,
                name: name,
                poolMultiplier: uint32(10_000)
            })
        );


        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(newId);
        emit TestProggres("stakingDefinition.name", stakingDefinition.name);
        emit TestProggres("stakingDefinitionId", newId);
        emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
        emit TestProggres("stakingDefinition.rate", stakingDefinition.rate);
        emit TestProggres("stakingDefinition.lockDuration", stakingDefinition.lockDuration);
        emit TestProggres("stakingDefinition.withdrawFeePercentage", stakingDefinition.withdrawFeePercentage); 
        emit TestProggres("stakingDefinition.numberOfActiveStakings", stakingDefinition.numberOfActiveStakings); 

        assert(keccak256(abi.encodePacked(stakingDefinition.name)) == keccak256(abi.encodePacked(name)));
        assert(stakingDefinition.rate == rate);
        assert(stakingDefinition.withdrawFeePercentage == withdrawFeePercentage);
        assert(stakingDefinition.lockDuration == lockDuration);
        assert(stakingDefinition.numberOfActiveStakings == 0);       
    }

    function test_numberOfActiveStakings() public {
        uint256 totalStakingsCalculated;

        for (uint8 stakingDefinitionId = 0; stakingDefinitionId < staking.totalStakingDefinitions(); stakingDefinitionId++) {
            StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);

            emit TestProggres("stakingDefinition.uniqueIdentifier", stakingDefinition.uniqueIdentifier);
            emit TestProggres("stakingDefinition.name", stakingDefinition.name);
            emit TestProggres("stakingDefinition.numberOfActiveStakings", stakingDefinition.numberOfActiveStakings);

            totalStakingsCalculated = totalStakingsCalculated + stakingDefinition.numberOfActiveStakings;
        }

        emit TestProggres("totalStakingsCalculated", totalStakingsCalculated);
        emit TestProggres("totalActiveStakings", staking.totalActiveStakings());

        assert(totalStakingsCalculated == staking.totalActiveStakings());
    }

    function calculateTotalDeposits() private view returns (uint256) {
        uint256 totalDeposits;

        for (uint8 stakingDefinitionId = 0; stakingDefinitionId < staking.totalStakingDefinitions(); stakingDefinitionId++) {
            for (uint i = 0; i < senders.length; i++) {
                Deposit memory deposit = staking.getUserDeposit(stakingDefinitionId, senders[i]);
                if(deposit.status == staking.DEPOSIT_STATUS_STAKING()) {
                    totalDeposits = totalDeposits + deposit.depositAmount;
                }
            }
        }

        return totalDeposits;
    }
}