// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "./base/HelperBaseTest.sol";
import {Staking, StakingDefinition} from "../src/Staking.sol";
import {UserDeposit} from "../src/Helper.sol";

contract TestHelperInitialData is HelperBaseTest {
    function testGetTiersData() public {
        Tier[] memory tiers = helper.getTiersData();
        assertEq(tiers[1].name, "SNAKE");
        assertEq(tiers[1].amountNeeded, 200e18);
        assertEq(tiers[1].weight, 1);

        assertEq(tiers[3].name, "BEAR");
        assertEq(tiers[3].amountNeeded, 2500e18);
        assertEq(tiers[3].weight, 6);
    }

    function testGetStakingContractsInfo() public {
        StakingDefinition[] memory stakingConctractsInfo = helper.getStakingDefinitions();

        StakingDefinition memory info1 = stakingConctractsInfo[0];
        assertEq(info1.name, "7days");
        assertEq(info1.rate, 6);
        assertEq(info1.lockDuration, 7 days);
        assertEq(info1.withdrawFeePercentage, 10);

        StakingDefinition memory info3 = stakingConctractsInfo[3];
        assertEq(info3.name, "60days");
        assertEq(info3.rate, 65);
        assertEq(info3.lockDuration, 60 days);
        assertEq(info3.withdrawFeePercentage, 40);
    }
}

contract TestGetUserStakingData is HelperBaseTest {
    function testWhenStakingOnSingle() public {
        Staking first = helper.stakingContract();
        uint256 amount = 1000e18;
        vm.startPrank(staker);
        token.approve(address(first), amount);
        first.stake(0, amount);
        vm.stopPrank();
        uint256 depositTimestamp = block.timestamp;

        vm.warp(block.timestamp + 1);
        (
            string memory tier,
            uint256 totalAmount,
            uint256 totalAmountWithMultiplier,
            UserDeposit[] memory deposits
        ) = helper.getUserStakingData(staker);

        StakingDefinition memory firstInfo = first.getStakingDefinition(0);

        assertEq(tier, "SCORPION");
        assertEq(totalAmount, amount);
        assertEq(deposits.length, first.totalStakingDefinitions());
        assertEq(deposits[0].depositAmount, amount);
        assertEq(deposits[0].depositTime, depositTimestamp);
        assertEq(
            deposits[0].endTime,
            depositTimestamp + uint256(firstInfo.lockDuration)
        );
        assertEq(deposits[0].stakingRate, firstInfo.rate);
        assertEq(deposits[0].stakingName, firstInfo.name);
        assertEq(deposits[0].stakingPoolMultiplier, firstInfo.poolMultiplier);
        assertEq(deposits[0].status, first.DEPOSIT_STATUS_STAKING());
        assertEq(deposits[0].depositAmount, amount);
    }

    function testWhenStakingOnMultiple() public {
        uint256[4] memory amounts = [
            uint256(1000e18),
            200e18,
            10_000e18,
            10_000e18
        ];
        uint256 total = 21_200e18;

        Staking staking = helper.stakingContract();
        token.approve(address(staking), 10e18);
        staking.addReward(10e18);

        for (uint8 i = 0; i < amounts.length; i++) {
            token.approve(address(staking), 10e18);
            staking.addReward(10e18);
        }

        vm.startPrank(staker);
        for (uint8 i = 0; i < amounts.length; i++) {
            token.approve(address(staking), amounts[i]);
            staking.stake(i, amounts[i]);
        }
        vm.stopPrank();
        vm.warp(block.timestamp + 1);

        (
            string memory tier,
            uint256 totalAmount,
            uint256 totalAmountWithMultiplier,
            UserDeposit[] memory deposits
        ) = helper.getUserStakingData(staker);

        assertEq(tier, "LION");
        assertEq(totalAmount, total);
        assertEq(deposits.length, staking.totalStakingDefinitions());

        for (uint8 i = 0; i < deposits.length; i++) {
            StakingDefinition memory stakingDef = staking.getStakingDefinition(i);

            assertEq(deposits[i].stakingRate, stakingDef.rate);
            assertEq(deposits[i].stakingName, stakingDef.name);
            assertEq(deposits[i].stakingPoolMultiplier, stakingDef.poolMultiplier);
        }

        vm.prank(staker);
        staking.withdraw(3);

        (tier, totalAmount, totalAmountWithMultiplier, deposits) = helper.getUserStakingData(staker);

        assertEq(tier, "BULL");
        assertEq(totalAmount, total - 10_000e18);
    }
}
