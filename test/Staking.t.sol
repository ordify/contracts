// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./base/StakingBaseTest.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {StakingDefinition, StakingDefinitionCreate, Deposit, Staking} from "../src/Staking.sol";

contract TestSetRateAndLockduration is StakingBaseTest {
    function testInitialParameters() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            StakingDefinition memory sd = staking.getStakingDefinition(i);

            assertEq(sd.name, stakingContractName);
            assertEq(sd.rate, rate);
            assertEq(sd.lockDuration, lockDuration);
        }

        assertEq(staking.treasury(), treasury);
    }
}

contract TestInitialData is StakingBaseTest {
    function testOwnerShiptTransfer() public {
        assertEq(address(this), staking.owner());
        staking.transferOwnership(nonOwner);
        assertEq(nonOwner, staking.owner());
    }

    function testSetZeroRate() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            staking.setRate(i, 0);   
        }
    }

    function testSetZeroLock() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            staking.setLockDuration(i, 0);   
        }
    }

    function testSetRateAndLockduration() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            staking.setRate(i, 800);   
            staking.setLockDuration(i, 5000);   
        }

        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            StakingDefinition memory sd = staking.getStakingDefinition(i);
            
            assertEq(sd.rate, 800);
            assertEq(sd.lockDuration, 5000);
        }
    }

    function testFailOwnerSetLockDuration() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            vm.prank(nonOwner);
            staking.setLockDuration(i, 5000);   
        }
    }

    function testNoOwnerSetRate() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            vm.prank(nonOwner);
            vm.expectRevert("Ownable: caller is not the owner");
            staking.setRate(i, 800);   
        }
    }

    function testOwnerSetName() public {
        StakingDefinition memory sd = staking.getStakingDefinition(0);
        assertEq("Test staking", sd.name);

        staking.setName(0, "Name Updated");

        StakingDefinition memory sdAfter = staking.getStakingDefinition(0);
        assertEq("Name Updated", sdAfter.name);
    }

    function testNoOwnerSetName() public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.setName(0, "Name Updated");
    }
}

contract TestAddStakingDefinition is StakingBaseTest {
    function testNoOwnerAddStakingDefinition() public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.addStakingDefinition(
            StakingDefinitionCreate({
                rate: uint32(2000),
                withdrawFeePercentage: uint32(1000),
                lockDuration: uint32(720),
                name: "Test staking",
                poolMultiplier: uint32(10_000)
            })
        );
    }

    function testOwnerAddStakingDefinition() public {
        assertEq(staking.totalStakingDefinitions(), 1);

        staking.addStakingDefinition(
            StakingDefinitionCreate({
                rate: uint32(2000),
                withdrawFeePercentage: uint32(2000),
                lockDuration: uint32(1000),
                name: "Test staking 2",
                poolMultiplier: uint32(10_000)
            })
        );

        assertEq(staking.totalStakingDefinitions(), 2);
    }

    function testOwnerAddStakingDefinitionsShpuldFailIfMaxReached() public {
        assertEq(staking.totalStakingDefinitions(), 1);

        while(staking.totalStakingDefinitions() < staking.MAX_STAKING_DEFINITIONS_SIZE()) {
            staking.addStakingDefinition(
                StakingDefinitionCreate({
                    rate: uint32(10_000),
                    withdrawFeePercentage: uint32(2000),
                    lockDuration: uint32(1000),
                    name: "Test staking 2",
                    poolMultiplier: uint32(10_000)
                })
            );
        }
        assertEq(staking.totalStakingDefinitions(), 30);

        vm.expectRevert("too many staking defs");
        staking.addStakingDefinition(
            StakingDefinitionCreate({
                rate: uint32(10_000),
                withdrawFeePercentage: uint32(2000),
                lockDuration: uint32(1000),
                name: "Test staking 2",
                poolMultiplier: uint32(10_000)
            })
        );
    }
}

contract TestStatusChange is StakingBaseTest {
    function testNoOwnerSetStatus(bool status) public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.setIsStopped(status);
    }

    function testSetStatus(bool status) public {
        staking.setIsStopped(status);

        assertTrue(staking.isStopped() == status);
    }
}

contract TestSetWithdrawFee is StakingBaseTest {
    function testSetFeeWithNonOwnerShouldNotSucceed() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            vm.prank(nonOwner);
            vm.expectRevert("Ownable: caller is not the owner");
            staking.setWithdrawFee(i, 33);
        } 
    }

    function testWithOwner() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            staking.setWithdrawFee(i, 33);
        }

        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            StakingDefinition memory sd = staking.getStakingDefinition(i);
            assertEq(sd.withdrawFeePercentage, 33);
        }
    }

    function testOutOfRangeFee() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            vm.expectRevert("percentage too big");
            staking.setWithdrawFee(i, 10001);
        }
    }
}

contract TestSetTreasury is StakingBaseTest {
    function testSetTreasuryWithNonOwnerShouldNotSucceed() public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.setTreasury(address(111));
    }

    function testWithOwner() public {
        assertEq(staking.treasury(), 0x8C9bdbf68e52226448367c00948333Dda7d9bA20);
        
        staking.setTreasury(address(111));

        assertEq(staking.treasury(), address(111));
    }
}

contract TestAddReward is StakingBaseTest {
    function testAddReward() public {
        (
            uint256 recordedStakingBalanceBefore, 
            uint256 recordedRewardBalanceBefore,
            uint256 actualTokenBalanceBefore
        ) = staking.getContractState();
        
        token.approve(address(staking), 10e18);
        staking.addReward(10e18);

        (
            uint256 recordedStakingBalanceAfter, 
            uint256 recordedRewardBalanceAfter,
            uint256 actualTokenBalanceAfter
        ) = staking.getContractState();

        assertEq(recordedStakingBalanceBefore, recordedStakingBalanceAfter);
        assertEq(recordedRewardBalanceBefore + 10e18, recordedRewardBalanceAfter);
        assertTrue(staking.stakedBalance() == recordedStakingBalanceAfter);
        assertTrue(staking.rewardBalance() == recordedRewardBalanceAfter);
        assertEq(actualTokenBalanceBefore + 10e18, actualTokenBalanceAfter);
        assertEq(actualTokenBalanceAfter - (actualTokenBalanceBefore + 10e18), 0);
    }

    function testSyncAddReward() public {
        (
            uint256 recordedStakingBalance, 
            uint256 recordedRewardBalance,
            uint256 actualTokenBalance
        ) = staking.getContractState();
        assertEq(actualTokenBalance, recordedStakingBalance + recordedRewardBalance);

        token.transfer(address(staking), 20e18);
        (
            uint256 recordedStakingBalanceBefore, 
            uint256 recordedRewardBalanceBefore,
            uint256 actualTokenBalanceBefore
        ) = staking.getContractState();
        
        assertEq(actualTokenBalanceBefore - 20e18, recordedStakingBalance + recordedRewardBalance);

        token.approve(address(staking), 10e18);
        staking.addReward(10e18);

        (
            uint256 recordedStakingBalanceAfter, 
            uint256 recordedRewardBalanceAfter,
            uint256 actualTokenBalanceAfter
        ) = staking.getContractState();

        assertEq(recordedStakingBalanceBefore, recordedStakingBalanceAfter);
        assertEq(recordedRewardBalanceBefore + 10e18, recordedRewardBalanceAfter);
        assertTrue(staking.stakedBalance() == recordedStakingBalanceAfter);
        assertTrue(staking.rewardBalance() == recordedRewardBalanceAfter);
        assertEq(actualTokenBalanceBefore + 10e18, actualTokenBalanceAfter);
        assertEq(actualTokenBalanceAfter - (actualTokenBalanceBefore + 10e18), 0);

        assertEq(actualTokenBalanceAfter - 20e18, recordedStakingBalanceAfter + recordedRewardBalanceAfter);
        staking.sync();

        (
            uint256 recordedStakingBalanceAfterSync, 
            uint256 recordedRewardBalanceAfterSync,
            uint256 actualTokenBalanceAfterSync
        ) = staking.getContractState();

        assertEq(actualTokenBalanceAfterSync, recordedStakingBalanceAfterSync + recordedRewardBalanceAfterSync);
        assertEq(recordedStakingBalanceAfter, recordedStakingBalanceAfterSync);
        assertEq(recordedRewardBalanceAfterSync, recordedRewardBalanceAfter + 20e18);
    }
}

contract TestStakeFunctionality is StakingBaseTest {
    function testShouldNotSucceedWithoutApprove() public {
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            vm.prank(staker);
            vm.expectRevert("allowance too low");
            staking.stake(i, 10_000);
        }
    }

    function testStakeShouldFailIfStakingDefinitionIsDisabled(uint256 _amount1) public {
        uint256 amount =  bound(_amount1, 0.001 ether, 50_000_000e18);

        staking.disableStakingDefinition(0);

        vm.startPrank(staker);
        token.approve(address(staking), amount);
        vm.expectRevert("staking def not enabled");
        staking.stake(0, amount);
        vm.stopPrank();
    }

    function testEstimateReward() public {
        uint8 stakingDefinitionId = 0;

        uint256 rewards = staking.estimateRewards(stakingDefinitionId, 100_000 ether);
        
        // amount * duration / year in seconds = 100_000 * 30 days / 365 days
        assertTrue(rewards == 1643835616438356164383);
    }

    function testStakeShouldSucceedIfStakingDefinitionIsEnabled(uint256 _amount) public {
        uint256 amount =  bound(_amount, 0.001 ether, 50_000_000e18);
        uint8 stakingDefinitionId = 0;

        Deposit memory userDepositBefore = staking.getUserDeposit(stakingDefinitionId, staker);
        (, uint256 current) = staking.calculateRewards(stakingDefinitionId, staker);

        staking.disableStakingDefinition(stakingDefinitionId);

        vm.startPrank(staker);
        token.approve(address(staking), amount);
        vm.expectRevert("staking def not enabled");
        staking.stake(stakingDefinitionId, amount);
        vm.stopPrank();

        staking.enableStakingDefinition(stakingDefinitionId);

        vm.startPrank(staker);
        token.approve(address(staking), amount);
        staking.stake(0, amount);
        vm.stopPrank();

        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinitionId, staker);
        assertEq(userDeposit.depositAmount, amount + userDepositBefore.depositAmount + current);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(stakingDefinitionId);

        assertEq(
            userDeposit.depositTime + stakingDefinition.lockDuration,
            userDeposit.endTime
        );

        assertTrue(userDeposit.status == staking.DEPOSIT_STATUS_STAKING());
        assertTrue(staking.doesUserHaveActiveStake(stakingDefinitionId, staker));
    }

    function testMultipleSequentialStakes(uint256 _amount1, uint256 _amount2) public {
        uint256 amount1 =  bound(_amount1, 0.001 ether, 50_000_000e18);
        uint256 amount2 =  bound(_amount2, 0.001 ether, 50_000_000e18);


        utilsStake(staking, amount1);
        utilsStake(staking, amount2);

        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            Deposit memory userDeposit = staking.getUserDeposit(i, staker);
            assertTrue(userDeposit.depositAmount == amount1 + amount2); // reward calculated here is 0 as no time warp happened

            StakingDefinition memory stakingDefinition = staking.getStakingDefinition(i);

            assertEq(
                userDeposit.depositTime + stakingDefinition.lockDuration,
                userDeposit.endTime
            );
            assertTrue(userDeposit.status == staking.DEPOSIT_STATUS_STAKING());
        }
    }

    function testWithdrawWithPenalty(uint256 _amount) public {
        uint256 prevBalance = token.balanceOf(staker);

        uint256 amount =  bound(_amount, 0.001 ether, 50_000_000e18);
        utilsStake(staking, amount);


        uint256 postStakeBalance = token.balanceOf(staker);
        assertEq(prevBalance - amount, postStakeBalance);

        
        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            uint256 withdrawFee = staking.calculateWithdrawFee(0, staker);

            vm.prank(staker);
            staking.withdraw(i);

            StakingDefinition memory stakingDeinition = staking.getStakingDefinition(i);

            uint256 currBalance = token.balanceOf(staker);
            uint256 penalty = (amount * stakingDeinition.withdrawFeePercentage) / staking.BASIS_POINT_RATE_CONVERTER();

            assertEq(prevBalance - penalty, currBalance);
            assertEq(withdrawFee,  penalty);
        }
    }

    function testEmergencyWithdrawWithPenalty(uint256 _amount) public {
        uint256 prevBalance = token.balanceOf(staker);

        uint256 amount =  bound(_amount, 0.001 ether, 100_000_000e18);
        utilsStake(staking, amount);

        uint256 postStakeBalance = token.balanceOf(staker);
        assertEq(prevBalance - amount, postStakeBalance);

        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {

            (uint256 totalRewards, uint currentRewards) = staking.calculateRewards(0, staker);
            uint256 withdrawFee = staking.calculateWithdrawFee(0, staker);
            console.log("XXXXXXXX totalRewards: ", totalRewards);
            console.log("XXXXXXXX currentRewards: ", currentRewards);
            console.log("XXXXXXXX withdrawFee: ", withdrawFee);

            vm.prank(staker);
            staking.withdraw(i);

            StakingDefinition memory stakingDeinition = staking.getStakingDefinition(i);

            uint256 currBalance = token.balanceOf(staker);
            uint256 penalty = (amount * stakingDeinition.withdrawFeePercentage) / staking.BASIS_POINT_RATE_CONVERTER();
            console.log("XXXXXXXX penalty: ", penalty);

            assertEq(prevBalance - penalty, currBalance);
            assertEq(withdrawFee,  penalty);
        }
    }

    function testEmergencyWithdrawWithoutPenalty(uint256 _amount) public {
        uint256 prevBalance = token.balanceOf(staker);

        uint256 amount =  bound(_amount, 0.001 ether, 100_000_000e18);
        utilsStake(staking, amount);

        uint256 postStakeBalance = token.balanceOf(staker);
        assertEq(prevBalance - amount, postStakeBalance);

        for (uint8 i = 0; i < staking.totalStakingDefinitions(); i++) {
            StakingDefinition memory stakingDeinition = staking.getStakingDefinition(i);
            
            vm.warp(block.timestamp + stakingDeinition.lockDuration + 1);

            (, uint256 current) = staking.calculateRewards(i, staker);

            vm.prank(staker);
            staking.withdraw(i);

            uint256 currBalance = token.balanceOf(staker);

            assertEq(prevBalance + current, currBalance);   
        }
    }

    function testEmergencyWIthdrawTokenAsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.emergencyWithdrawToken(IERC20(address(111)));
    }

    function testEmergencyWIthdrawTokenAsOwner() public {        
        uint256 balanceBefore = token.balanceOf(staking.owner());
        uint256 balanceBeforeStakingContract = token.balanceOf(address(staking));
        
        vm.prank(staking.owner());
        staking.emergencyWithdrawToken(IERC20(address(token)));

        uint256 balanceAfter = token.balanceOf(staking.owner());
        uint256 balanceAfterStakingContract = token.balanceOf(address(staking));

        assertEq(balanceAfter, balanceBefore + balanceBeforeStakingContract);
        assertEq(balanceAfterStakingContract, 0);
    }
}

contract TestStakingRewards is StakingBaseTest {
    function testProperCalculationOfRewards(
        uint128 _amount,
        uint16 _rate,
        uint32 _lockDuration
    ) public {
        if (_rate == 0 || _lockDuration == 0) return;
        
        uint256 lockDuration =  bound(_lockDuration, 100, 10000);
        uint32 rateValue =  uint32(bound(_rate, 1, 10_000));

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](2);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: rateValue,
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDuration),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: rateValue / 2,
            withdrawFeePercentage: uint32(2000),
            lockDuration: uint32(lockDuration) * 2,
            name: "Test staking 2",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        
        Staking _stakingNew = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );

        console.log("XXXXX => _rate: ", uint32(rate));
        console.log("XXXXX => _lockDuration: ", uint32(lockDuration));

        // vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);
        console.log("XXXXX => amount: ", amount);

        utilsStake(_stakingNew, amount);
        // vm.stopPrank();

        for (uint8 i = 0; i < _stakingNew.totalStakingDefinitions(); i++) {
            StakingDefinition memory stakingDeinition = _stakingNew.getStakingDefinition(i);
            Deposit memory userDeposit = _stakingNew.getUserDeposit(i, address(staker));


            console.log("XXXXX => stakingDefinitionId: ", i);
            console.log("XXXXX => depositTime: ", userDeposit.depositTime);
            console.log("XXXXX => endTime: ", userDeposit.endTime);

            uint256 lockDurationInSeconds = uint256(stakingDeinition.lockDuration);
            uint256 stakingTime = userDeposit.depositTime;
            uint256 endOfLock = block.timestamp + lockDurationInSeconds;
            uint256 step = lockDurationInSeconds / 10;

            console.log("XXXXX => lockDurationInSeconds: ", lockDurationInSeconds);
            console.log("XXXXX => stakingTime: ", stakingTime);
            console.log("XXXXX => endOfLock: ", endOfLock);
            console.log("XXXXX => step: ", step);
            
            while (block.timestamp <= endOfLock) {
                uint256 totalReward = calculateRewardLocal(
                    _stakingNew, 
                    amount, 
                    stakingDeinition.rate, 
                    userDeposit.endTime - userDeposit.depositTime
                );
    
               uint256 currentReward = calculateRewardLocal(
                    _stakingNew,
                    amount, 
                    stakingDeinition.rate, 
                    Math.min(block.timestamp, userDeposit.endTime) - userDeposit.depositTime
                );
    
                (uint256 total, uint256 current) = _stakingNew.calculateRewards(i, staker);
                emit log_uint(current);
                assertEq(total, totalReward);
                assertEq(current, currentReward);
                vm.warp(block.timestamp + step);
            }
        }
    }

    function testClaimReward(
        uint128 _amount,
        uint16 _rate,
        uint32 _lockDuration
    ) public {
        if (_rate == 0 || _lockDuration == 0) return;
        
        uint256 lockDuration =  bound(_lockDuration, 100, 10000);
        uint32 rateValue =  uint32(bound(_rate, 100, 10_000));

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](2);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: rateValue,
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDuration),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: rateValue / 2,
            withdrawFeePercentage: uint32(2000),
            lockDuration: uint32(lockDuration) * 2,
            name: "Test staking 2",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        
        Staking _stakingNew = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );

        token.approve(address(_stakingNew), 500_000_000e18);
        _stakingNew.addReward(500_000_000e18);

        console.log("XXXXX => _rate: ", uint32(rate));
        console.log("XXXXX => _lockDuration: ", uint32(lockDuration));

        // vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);
        console.log("XXXXX => amount: ", amount);

        utilsStake(_stakingNew, amount);
        // vm.stopPrank();

        vm.warp(block.timestamp + (lockDuration / 2));

        for (uint8 i = 0; i < _stakingNew.totalStakingDefinitions(); i++) {
            Deposit memory userDeposit = _stakingNew.getUserDeposit(i, address(staker));

            console.log("XXXXX => stakingDefinitionId: ", i);
            console.log("XXXXX => depositTime: ", userDeposit.depositTime);
            console.log("XXXXX => endTime: ", userDeposit.endTime);

            (uint256 totalRewardBefore, uint256 currentRewardBefore) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardBefore: ", totalRewardBefore);
            console.log("XXXXX => currentRewardBefore: ", currentRewardBefore);
            uint256 stakerBalanceBefore = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceBefore: ", stakerBalanceBefore);

            vm.prank(staker);
            _stakingNew.claimReward(i);

            (uint256 totalRewardAfter, uint256 currentRewardAfter) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardAfter: ", totalRewardAfter);
            console.log("XXXXX => currentRewardAfter: ", currentRewardAfter);
            uint256 stakerBalanceAfter = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceAfter: ", stakerBalanceAfter);
            Deposit memory userDepositAfter = _stakingNew.getUserDeposit(i, address(staker));

            assertEq(stakerBalanceAfter, stakerBalanceBefore + currentRewardBefore);
            assertEq(block.timestamp, userDepositAfter.rewardClaimedTime);
            assertEq(userDeposit.endTime, userDepositAfter.endTime);
        }
    }

    function testClaimRewardAfterMaturityReached(
        uint128 _amount,
        uint16 _rate,
        uint32 _lockDuration
    ) public {
        if (_rate == 0 || _lockDuration == 0) return;
        
        uint256 lockDuration =  bound(_lockDuration, 100, 10000);
        uint32 rateValue =  uint32(bound(_rate, 100, 10_000));

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](2);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: rateValue,
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDuration),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: rateValue / 2,
            withdrawFeePercentage: uint32(2000),
            lockDuration: uint32(lockDuration) * 2,
            name: "Test staking 2",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        
        Staking _stakingNew = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );

        token.approve(address(_stakingNew), 500_000_000e18);
        _stakingNew.addReward(500_000_000e18);

        console.log("XXXXX => _rate: ", uint32(rate));
        console.log("XXXXX => _lockDuration: ", uint32(lockDuration));

        // vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);
        console.log("XXXXX => amount: ", amount);

        utilsStake(_stakingNew, amount);
        // vm.stopPrank();

        vm.warp(block.timestamp + lockDuration + 100);

        for (uint8 i = 0; i < _stakingNew.totalStakingDefinitions(); i++) {
            Deposit memory userDeposit = _stakingNew.getUserDeposit(i, address(staker));

            console.log("XXXXX => stakingDefinitionId: ", i);
            console.log("XXXXX => depositTime: ", userDeposit.depositTime);
            console.log("XXXXX => endTime: ", userDeposit.endTime);
            console.log("XXXXX => block.timestamp: ", block.timestamp);

            (uint256 totalRewardBefore, uint256 currentRewardBefore) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardBefore: ", totalRewardBefore);
            console.log("XXXXX => currentRewardBefore: ", currentRewardBefore);
            uint256 stakerBalanceBefore = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceBefore: ", stakerBalanceBefore);

            vm.prank(staker);
            _stakingNew.claimReward(i);

            (uint256 totalRewardAfter, uint256 currentRewardAfter) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardAfter: ", totalRewardAfter);
            console.log("XXXXX => currentRewardAfter: ", currentRewardAfter);
            uint256 stakerBalanceAfter = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceAfter: ", stakerBalanceAfter);
            Deposit memory userDepositAfter = _stakingNew.getUserDeposit(i, address(staker));

            assertEq(stakerBalanceAfter, stakerBalanceBefore + currentRewardBefore);
            assertEq(block.timestamp, userDepositAfter.rewardClaimedTime);
            assertEq(userDeposit.endTime, userDepositAfter.endTime);
        }
    }

    function testClaimRewardAndStake(
        uint128 _amount,
        uint16 _rate,
        uint32 _lockDuration
    ) public {
        if (_rate == 0 || _lockDuration == 0) return;
        
        uint256 lockDuration =  bound(_lockDuration, 100, 10000);
        uint32 rateValue =  uint32(bound(_rate, 100, 10_000));

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](2);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: rateValue,
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDuration),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: rateValue / 2,
            withdrawFeePercentage: uint32(2000),
            lockDuration: uint32(lockDuration) * 2,
            name: "Test staking 2",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        
        Staking _stakingNew = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );

        token.approve(address(_stakingNew), 500_000_000e18);
        _stakingNew.addReward(500_000_000e18);

        console.log("XXXXX => _rate: ", uint32(rate));
        console.log("XXXXX => _lockDuration: ", uint32(lockDuration));

        // vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);
        console.log("XXXXX => amount: ", amount);

        utilsStake(_stakingNew, amount);
        // vm.stopPrank();

        vm.warp(block.timestamp + (lockDuration / 2));

        for (uint8 i = 0; i < _stakingNew.totalStakingDefinitions(); i++) {
            Deposit memory userDeposit = _stakingNew.getUserDeposit(i, address(staker));
            StakingDefinition memory sd = _stakingNew.getStakingDefinition(i);

            console.log("XXXXX => stakingDefinitionId: ", i);
            console.log("XXXXX => depositTime: ", userDeposit.depositTime);
            console.log("XXXXX => endTime: ", userDeposit.endTime);

            (uint256 totalRewardBefore, uint256 currentRewardBefore) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardBefore: ", totalRewardBefore);
            console.log("XXXXX => currentRewardBefore: ", currentRewardBefore);
            uint256 stakerBalanceBefore = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceBefore: ", stakerBalanceBefore);

            vm.prank(staker);
            _stakingNew.claimAndStake(i);

            (uint256 totalRewardAfter, uint256 currentRewardAfter) = _stakingNew.calculateRewards(i, staker);
            console.log("XXXXX => totalRewardAfter: ", totalRewardAfter);
            console.log("XXXXX => currentRewardAfter: ", currentRewardAfter);
            uint256 stakerBalanceAfter = token.balanceOf(staker);
            console.log("XXXXX => stakerBalanceAfter: ", stakerBalanceAfter);
            Deposit memory userDepositAfter = _stakingNew.getUserDeposit(i, address(staker));

            assertEq(stakerBalanceAfter, stakerBalanceBefore);
            assertEq(userDepositAfter.rewardClaimedTime, 0);
            assertEq(currentRewardAfter, 0);
            assertEq(userDepositAfter.endTime, block.timestamp + sd.lockDuration);
            assertEq(userDeposit.depositAmount + currentRewardBefore, userDepositAfter.depositAmount);
        }
    }

    function calculateRewardLocal(
        Staking _stakingContract, 
        uint256 amount, 
        uint256 rate, 
        uint256 timePassed
    ) public view returns(uint256 reward) {
        uint256 totalRewardCalculation1 = amount * rate * timePassed;
        uint256 totalRewardCalculation2 = _stakingContract.YEAR_IN_SECONDS() * _stakingContract.BASIS_POINT_RATE_CONVERTER();
        uint256 totalReward = totalRewardCalculation1 / totalRewardCalculation2;

        console.log(" ZZZZZ => timePassed: ", timePassed);
        console.log(" ZZZZZ => calculateRewardLocal =>  rate: ", rate);
        console.log(" ZZZZZ => calculateRewardLocal => amount: ", amount);
        console.log(" ZZZZZ => calculateRewardLocal =>  totalReward: ", totalReward);
        
        reward = totalReward;
    }

    function testWithdrawWithRewardsAndPenalty(uint128 _amount) public {
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);

        vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1, 100_000_000e18);
        console.log("XXXX => amount: ", amount);
        console.log("XXXX => totalSupply: ", token.totalSupply());

        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();

        vm.roll(block.number + 1);
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));

        uint256 stakingTime = block.timestamp;
        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);

        uint256 localReardCalculation = calculateRewardLocal(staking, amount, stakingDefinition.rate, userDeposit.endTime - userDeposit.depositTime);

        assertEq(total, localReardCalculation);
        assertEq(current, 0);

        uint256 balanceBefore = token.balanceOf(staker);

        uint256 currentReward =  calculateRewardLocal(staking, amount, stakingDefinition.rate, block.timestamp - stakingTime);

        (
            uint256 recordedStakingBalance, 
            uint256 recordedrewardBalance, 
        ) = staking.getContractState();
        assertTrue(staking.stakedBalance() == recordedStakingBalance);
        assertTrue(staking.rewardBalance() == recordedrewardBalance);
        assertTrue(staking.stakedBalance() >= amount);
        assertTrue(staking.rewardBalance() >= current);
        uint256 penalty = staking.calculateWithdrawFee(stakingDefinition.uniqueIdentifier, staker);

        vm.prank(staker);
        staking.withdraw(stakingDefinition.uniqueIdentifier);

        uint256 balanceAfter = token.balanceOf(staker);

        assertEq(
            balanceAfter,
            balanceBefore + amount + currentReward - penalty
        );

        vm.roll(block.number + 1);

        (total, current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        assertEq(total, 0);
        assertEq(current, 0);
    }

    function testClaimRewardIfRewardIs0(uint128 _amount) public {
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);

        staking.setPrematureWithdrawEnabled(false);

        vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1, 100_000_000e18);
        console.log("XXXX => amount: ", amount);
        console.log("XXXX => totalSupply: ", token.totalSupply());

        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();

        vm.roll(block.number + 1);
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));

        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        uint256 localReardCalculation = calculateRewardLocal(staking, amount, stakingDefinition.rate, userDeposit.endTime - userDeposit.depositTime);

        assertEq(total, localReardCalculation);
        assertEq(current, 0);

        vm.prank(staker);
        vm.expectRevert("reward is 0");
        staking.claimReward(stakingDefinition.uniqueIdentifier);
    }

    function testPreMatureWithdrawWIthPreMatureWithdrawDisabled(uint128 _amount) public {
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);

        staking.setPrematureWithdrawEnabled(false);

        vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1, 100_000_000e18);
        console.log("XXXX => amount: ", amount);
        console.log("XXXX => totalSupply: ", token.totalSupply());

        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();

        vm.roll(block.number + 1);
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));

        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        uint256 localReardCalculation = calculateRewardLocal(staking, amount, stakingDefinition.rate, userDeposit.endTime - userDeposit.depositTime);

        assertEq(total, localReardCalculation);
        assertEq(current, 0);

        vm.warp(block.timestamp + (stakingDefinition.lockDuration / 2));
        console.log("XXXXX userDeposit.endTime: ", userDeposit.endTime);
        console.log("XXXXX block.timestamp: ", block.timestamp);

        vm.prank(staker);
        vm.expectRevert("premature withdraw not enabled");
        staking.withdraw(stakingDefinition.uniqueIdentifier);
    }

    function testPreMatureWithdrawWIthPreMatureWithdrawDisabledAndMaturityReached(uint128 _amount) public {
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);

        staking.setPrematureWithdrawEnabled(false);

        vm.startPrank(staker);
        uint256 amount =  bound(_amount, 1, 100_000_000e18);
        console.log("XXXX => amount: ", amount);
        console.log("XXXX => totalSupply: ", token.totalSupply());

        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();

        vm.roll(block.number + 1);
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));

        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        uint256 localReardCalculation = calculateRewardLocal(staking, amount, stakingDefinition.rate, userDeposit.endTime - userDeposit.depositTime);

        assertEq(total, localReardCalculation);
        assertEq(current, 0);

        vm.warp(block.timestamp + stakingDefinition.lockDuration  + 100);

        uint256 balanceBefore = token.balanceOf(staker);
        (uint256 totalReward, ) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);

        vm.prank(staker);
        staking.withdraw(stakingDefinition.uniqueIdentifier);
        uint256 balanceAfter = token.balanceOf(staker);


        assertEq(balanceAfter, balanceBefore + amount + totalReward);
    }

    function testWithdrawWithRewardsAfterLockEnds(uint32 _amount) public {
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);
        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);
        uint256 stakingTime = block.timestamp;

        vm.startPrank(staker);
        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));
        vm.warp(
            block.timestamp + uint256(stakingDefinition.lockDuration) * 3600 + 10 * 3600
        );

        uint256 totalReward = calculateRewardLocal(staking, amount, stakingDefinition.rate, Math.min(block.timestamp, userDeposit.endTime) - stakingTime);
        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        (
            uint256 recordedStakingBalance, 
            uint256 recordedrewardBalance, 
        ) = staking.getContractState();
        assertTrue(staking.stakedBalance() == recordedStakingBalance);
        assertTrue(staking.rewardBalance() == recordedrewardBalance);

        assertEq(total, totalReward);
        assertEq(current, totalReward);
        assertTrue(staking.stakedBalance() >= amount);
        assertTrue(staking.rewardBalance() >= current);
        uint256 balanceBefore = token.balanceOf(staker);

        vm.prank(staker);
        staking.withdraw(stakingDefinition.uniqueIdentifier);

        uint256 balanceAfter = token.balanceOf(staker);
        emit log_uint(balanceAfter);

        assertEq(balanceAfter, balanceBefore + amount + totalReward);
    }

    function testwithdrawWithRewards(uint128 _amount, uint64 step) public {
        uint256 amount =  bound(_amount, 1 ether, 100_000_000e18);

        StakingDefinition memory stakingDefinition = staking.getStakingDefinition(0);
        // add rewards to staking contract

        token.approve(address(staking), 1e26);
        emit log_uint(token.balanceOf(staker));
        vm.startPrank(staker);
        token.approve(address(staking), amount);
        staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        Deposit memory userDeposit = staking.getUserDeposit(stakingDefinition.uniqueIdentifier, address(staker));

        uint256 stakingTime = block.timestamp;

        vm.warp(block.timestamp + step);

        uint256 balanceBefore = token.balanceOf(staker);

        uint256 currentReward = calculateRewardLocal(staking, amount, stakingDefinition.rate, Math.min(block.timestamp, userDeposit.endTime) - stakingTime);

        (uint256 total, uint256 current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        assertEq(currentReward, current);
        assertTrue(staking.stakedBalance() >= amount);
        assertTrue(staking.rewardBalance() >= current);
        uint256 penalty = staking.calculateWithdrawFee(stakingDefinition.uniqueIdentifier, staker);

        vm.prank(staker);
        staking.withdraw(stakingDefinition.uniqueIdentifier);

        uint256 balanceAfter = token.balanceOf(staker);

        assertEq(
            balanceAfter,
            balanceBefore + amount + currentReward - penalty
        );

        vm.roll(block.number + 1);

        (total, current) = staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
        assertEq(total, 0);
        assertEq(current, 0);
    }

    function testStakeAndFullRewardStaticAmount() public {
        uint256 amount = 1000e18;
        uint256 lockDurationInHours =  365 * 24 * 3600;
        uint32 rate =  5000;

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](1);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint32(rate),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDurationInHours),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        
        Staking _staking = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );
        StakingDefinition memory stakingDefinition = _staking.getStakingDefinition(0);

        vm.startPrank(address(staker));
        token.approve(address(_staking), amount);
        _staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        
        for (uint i = 1; i <= 12; i++) {
            uint256 hoursToJump;
            if(i == 12) {
                hoursToJump = 35 days;
            } else {
                hoursToJump = 30 days;
            }
            vm.warp(block.timestamp + hoursToJump);

            (uint256 total, uint256 current) = _staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
            assertEq(total, 500e18);

            (
                uint256 recordedStakingBalance, 
                uint256 recordedrewardBalance, 
            ) = staking.getContractState();
            assertTrue(staking.stakedBalance() == recordedStakingBalance);
            assertTrue(staking.rewardBalance() == recordedrewardBalance);

            assertTrue(_staking.stakedBalance() >= amount);
            
            uint256 curretnExpected;
            if(i == 12) {
                assertEq(current, 500e18);
            } else {
                curretnExpected = i * 41095890410958904109; // 30 days interest
                uint256 diff = current - curretnExpected;

                assertTrue(diff <= i/2 + 1);
            }
        }
    }

    function testStakeAndWithdrawFeeStaticAmount() public {
        uint256 amount = 1000e18;

        uint256 lockDurationInHours =  365 * 24 * 3600;
        uint256 rate =  5000;

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](1);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint32(rate),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDurationInHours),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        
        Staking _staking = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );
        StakingDefinition memory stakingDefinition = _staking.getStakingDefinition(0);

        vm.startPrank(address(staker));
        token.approve(address(_staking), amount);
        _staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        
        for (uint i = 1; i <= 12; i++) {
            uint256 hoursToJump;
            if(i == 12) {
                hoursToJump = 35 days + 1;
            } else {
                hoursToJump = 30 days;
            }
            vm.warp(block.timestamp + hoursToJump);

            uint256 fee = _staking.calculateWithdrawFee(stakingDefinition.uniqueIdentifier, staker);
            
            if(i == 12) {
                assertEq(fee, 0);
            } else {
                assertEq(fee, 100e18);
            }
        }
    }
}

contract TestStakingRewardsImperfectAmounts is StakingBaseTest {
    function testStakeAndFullRewardStaticStrangeAmount() public {
        uint256 amount = 1000_120232021004500003;
        uint256 lockDurationInHours =  365 * 24 * 3600;
        uint256 rate =  5000;

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](1);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint32(rate),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDurationInHours),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        
        Staking _staking = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );
        StakingDefinition memory stakingDefinition = _staking.getStakingDefinition(0);

        vm.startPrank(address(staker));
        token.approve(address(_staking), amount);
        _staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        
        uint256 totalDiff = 0;
        for (uint i = 1; i <= 12; i++) {
            uint256 hoursToJump;
            if(i == 12) {
                hoursToJump = 35 days;
            } else {
                hoursToJump = 30 days;
            }
            vm.warp(block.timestamp + hoursToJump);

            (uint256 total, uint256 current) = _staking.calculateRewards(stakingDefinition.uniqueIdentifier, staker);
            console.log("i: ", i);
            console.log("total: ", total);
            console.log("current: ", current);
            assertEq(total, 500_060116010502250001);

            (
                uint256 recordedStakingBalance, 
                uint256 recordedrewardBalance, 
            ) = staking.getContractState();
            assertTrue(staking.stakedBalance() == recordedStakingBalance);
            assertTrue(staking.rewardBalance() == recordedrewardBalance);

            assertTrue(_staking.stakedBalance() >= amount);
            
            uint256 curretnExpected;
            if(i == 12) {
                assertEq(current, 500_060116010502250001);
            } else {
                curretnExpected = i * 41100831452917993150; // 30 days interest

                uint256 diff = current - curretnExpected;
                console.log("DIFF: ", diff);
                console.log("curretnExpected: ", curretnExpected);
                totalDiff = totalDiff + diff;
                assertTrue(diff < i);
            }
        }

        console.log("TOTAL DIFF: ", totalDiff);
    }


    function testStakeAndWithdrawFeeStaticStrangeAmount() public {
        uint256 amount = 1000_120232021004500006;

        uint256 lockDurationInHours =  365 * 24 * 3600;
        uint256 rate =  5000;

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](1);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint32(rate),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(lockDurationInHours),
            name: "Test staking 1",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        
        Staking _staking = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );
        StakingDefinition memory stakingDefinition = _staking.getStakingDefinition(0);

        vm.startPrank(address(staker));
        token.approve(address(_staking), amount);
        _staking.stake(stakingDefinition.uniqueIdentifier, amount);
        vm.stopPrank();
        
        for (uint i = 1; i <= 12; i++) {
            uint256 hoursToJump;
            if(i == 12) {
                hoursToJump = 35 days + 1;
            } else {
                hoursToJump = 30 days;
            }
            vm.warp(block.timestamp + hoursToJump);

            uint256 fee = _staking.calculateWithdrawFee(stakingDefinition.uniqueIdentifier, staker);
            
            if(i == 12) {
                assertEq(fee, 0);
            } else {
                assertEq(fee, 100_012023202100450000);
            }
        }
    }
}
