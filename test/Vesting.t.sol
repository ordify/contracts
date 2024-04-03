// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "./base/VestingBaseTest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestVesting is VestingBaseTest {
    Phase[] internal  newPhases;

    function testInitialState() public {
        assertEq(vesting.totalAmountAllocated(), 0);
        assertTrue(!vesting.refundMode());
        assertEq(vesting.name(), "VestingIDO");
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(address(token), address(vesting.vestedToken()));
    }

    function testReinitialize() public {
        assertEq(vesting.totalAmountAllocated(), 0);
        assertTrue(!vesting.refundMode());
        assertEq(vesting.name(), "VestingIDO");
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(address(token), address(vesting.vestedToken()));

        newPhases.push(Phase(2000, 1651329000, 0)); // '2022-04-30T14:30:00.000Z'
        newPhases.push(Phase(1500, 1653921000, 0)); // '2022-05-30T14:30:00.000Z'
        newPhases.push(Phase(1500, 1656599400, 0)); // '2022-06-30T14:30:00.000Z'

        IERC20 prevToken = vesting.vestedToken();
        vesting.reinitialize({
            _vestedToken: vesting.vestedToken(),
            _name: "VestingIDORe",
            _startDateAt: 1555550600, /// '2022-03-30T14:30:00.000Z'
            _claimableAtStart: 5000,
            _phases: newPhases,
            _refundGracePeriodDuration: 2 days
        });

        assertEq(address(prevToken), address(vesting.vestedToken()));
        assertEq(vesting.name(), "VestingIDORe");
        assertEq(vesting.startDateAt(), 1555550600);
        assertEq(vesting.claimableAtStart(), 5000);
    }

    function testIfNotOwner(address nonOwner) public {
        if (vesting.owner() == nonOwner) return;
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(nonOwner);
        vesting.setRefundMode(true);
    }

    function testSetRefundAvailableAndUnlocking() public {
        assertTrue(!vesting.refundMode());
        vesting.setRefundMode(true);
        assertTrue(vesting.refundMode());
        vesting.setRefundMode(false);
        assertTrue(!vesting.refundMode());
    }

    function testDepositedWithNonOwner(address nonOwner) public {
        vm.prank(nonOwner);
        assertEq(vesting.getDepositedAmount(), 0);

        uint256 amount = 10_000e18;
        token.transfer(address(vesting), amount);

        vm.prank(nonOwner);
        assertEq(vesting.getDepositedAmount(), amount);
    }

    function testDepositedWithOwner() public {
        assertEq(vesting.getDepositedAmount(), 0);

        uint256 amount1 = 10_000e18;
        token.transfer(address(vesting), amount1);

        assertEq(vesting.getDepositedAmount(), amount1);

        uint256 amount2 = 30_000e18;
        token.transfer(address(vesting), amount2);

        assertEq(vesting.getDepositedAmount(), amount1 + amount2);
    }
}

contract TestVestingIDOCreation is VestingBaseTest {
    mapping(address => bool) addressExist;

    function testIfNotOwner(
        address nonOwner,
        CreateVestingInput[] memory vestingsInput
    ) public {
        if (vesting.owner() == nonOwner) return;
        for (uint256 i = 0; i < vestingsInput.length; i++) {
            if (
                vestingsInput[i].amount == 0 ||
                vestingsInput[i].user == address(0)
            ) {
                return;
            }
        }
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(nonOwner);
        vesting.createVestings(vestingsInput, true);
    }

    function testShouldFilWithoutPreviousDeposit(
        CreateVestingInput[] memory vestingsInput
    ) public {
        if (vestingsInput.length == 0) { return; }
        for (uint256 i = 0; i < vestingsInput.length; i++) {
            if (
                vestingsInput[i].amount == 0 ||
                vestingsInput[i].user == address(0)
            ) {
                // skip test
                return;
            }
        }

        vm.startPrank(vesting.owner());
        vm.expectRevert("not enough token deposited");
        vesting.createVestings(vestingsInput, true);
    }

    function testVestingCreation(CreateVestingInput[] memory vestingsInput) public {
        if (vestingsInput.length == 0) return;
        
        uint256 totalAmount;
        for (uint64 i = 0; i < vestingsInput.length; i++) {
            totalAmount += vestingsInput[i].amount;
            if (
                vestingsInput[i].amount == 0 ||
                vestingsInput[i].user == address(0)
            ) {
                // skip test
                return;
            }

            if(addressExist[vestingsInput[i].user]) {
                return;
            }

            addressExist[vestingsInput[i].user] = true;
        }
        token.transfer(address(vesting), totalAmount);
        vesting.createVestings(vestingsInput, true);

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            (   
                uint40 lastClaimAt,
                bool init,
                bool requestedRefund,
                uint256 amount,
                uint256 amountClaimed
            ) = vesting.vestings(vestingsInput[i].user);
            assertTrue(init);
            assertTrue(!requestedRefund);
            assertEq(amount, vestingsInput[i].amount);
            assertEq(amountClaimed, 0);
            assertEq(lastClaimAt, 0);
        }
    }

    function testVestingCreationWithoutDepositCheck(
        CreateVestingInput[] memory vestingsInput
    ) public {
        if (vestingsInput.length == 0) return;
        uint256 totalAmount;
        for (uint64 i = 0; i < vestingsInput.length; i++) {
            totalAmount += vestingsInput[i].amount;
            if (
                vestingsInput[i].amount == 0 ||
                vestingsInput[i].user == address(0)
            ) {
                // skip test
                return;
            }

            if(addressExist[vestingsInput[i].user]) {
                return;
            }

            addressExist[vestingsInput[i].user] = true;
        }
        
        vesting.createVestings(vestingsInput, false);

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            (
                uint40 lastClaimAt,
                bool init,
                bool requestedRefund,
                uint256 amount,
                uint256 amountClaimed
            ) = vesting.vestings(vestingsInput[i].user);
            assertTrue(init);
            assertTrue(!requestedRefund);
            assertEq(amount, vestingsInput[i].amount);
            assertEq(amountClaimed, 0);
            assertEq(lastClaimAt, 0);
        }
    }

    function testVestingCreation(address user1, address user2) public {
        if (user1 == user2) return;
        if (user1 == address(0) || user2 == address(0)) return;
        uint128 amount = 10_000e18;
        token.transfer(address(vesting), 3 * amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](2);
        vestingsInput[0] = CreateVestingInput({user: user1, amount: amount});
        vestingsInput[1] = CreateVestingInput({
            user: user2,
            amount: amount / 2
        });

        vesting.createVestings(vestingsInput, true);

        (
            uint40 lastClaimAtUser1,
            bool initUser1,
            bool requestedRefund1,
            uint256 amountUser1,
            uint256 amountClaimedUser1
        ) = vesting.vestings(user1);
        assertTrue(initUser1);
        assertTrue(!requestedRefund1);
        assertEq(amount, amountUser1);
        assertEq(amountClaimedUser1, 0);
        assertEq(lastClaimAtUser1, 0);

        (
            uint40 lastClaimAtUser2,
            bool initUser2,
            bool requestedRefund2,
            uint256 amountUser2,
            uint256 amountClaimedUser2
        ) = vesting.vestings(user2);
        assertTrue(initUser2);
        assertTrue(!requestedRefund2);
        assertEq(amount/2, amountUser2);
        assertEq(amountClaimedUser2, 0);
        assertEq(lastClaimAtUser2, 0);
    }
}

contract TestClaimFunctionality is VestingBaseTest {
    function testClaimableFunction() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), 3 * amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        uint256 claimableBeforeStart = vesting.claimable(user);
        assertEq(claimableBeforeStart, 0);

        vm.warp(vesting.startDateAt());

        uint256 claimableAtStart = vesting.claimable(user);
        assertEq(claimableAtStart, (amount * 20) / 100);

        uint256 lastClaimable = claimableAtStart;
        for (uint i = 0; i < 6; i++) {
            (uint256 rate, uint256 secondEndsAt, ) = vesting.phases(i);
            vm.warp(secondEndsAt);
            uint256 currentClaimable = vesting.claimable(user);
            assertEq(currentClaimable, lastClaimable + (amount * rate) / 10000);
            lastClaimable = currentClaimable;
        }
        assertEq(lastClaimable, amount);

        vm.warp(vesting.vestingEndAt());
        assertEq(vesting.claimable(user), amount);
    }

    function testClaimWhenRefundModeIsOn() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), 3 * amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);
        vesting.setRefundMode(true);

        vm.prank(user);
        vm.expectRevert("vesting is refunded");
        vesting.claim();
    }

    function testClaimBeforeStartDate() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), 3 * amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.expectRevert("nothing to claim currently");
        vm.prank(user);
        vesting.claim();
    }

    function testClaimWhenNoVesting() public {
        address user = 0x0000000000000000000000000000000000000001;

        vm.prank(user);
        vm.expectRevert("user is not participating");
        vesting.claim();
    }

    function testClaimableFunctionalityAtStart() public {
        uint128 amount = 9_000_000e18;
        uint128 claimableAtTGE = 1_800_000e18;
        uint128 claimablePerMonth = 1_199_700e18;
        uint128 claimableLastMonth = 1_201_500e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), 3 * amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        assertEq(token.balanceOf(user), 0);

        vm.expectRevert("nothing to claim currently");
        vm.prank(user);
        vesting.claim();

        vm.warp(startDate);
        vm.prank(user);
        vesting.claim();

        assertEq(token.balanceOf(user), claimableAtTGE);
        assertEq(vesting.totalAmountClaimed(), claimableAtTGE);
        assertEq(vesting.claimable(user), 0);
        (, , , , uint256 amountClaimed ) = vesting.vestings(user);
        assertEq(amountClaimed, claimableAtTGE);

        vm.warp(startDate + 1000);
        assertEq(vesting.claimable(user), 0);

        (, uint256 firstEndsAt, ) = vesting.phases(0);
        vm.warp(firstEndsAt - 1);
        assertEq(vesting.claimable(user), 0);
        vm.warp(firstEndsAt);
        assertEq(vesting.claimable(user), claimablePerMonth);

        (, uint256 secondEndsAt, ) = vesting.phases(1);
        vm.warp(secondEndsAt - 1);
        assertEq(vesting.claimable(user), claimablePerMonth);
        vm.warp(secondEndsAt);
        assertEq(vesting.claimable(user), 2 * claimablePerMonth);

        assertEq(token.balanceOf(user), claimableAtTGE);
        vm.prank(user);
        vesting.claim();
        assertEq(token.balanceOf(user), claimableAtTGE + 2 * claimablePerMonth);
        assertEq(vesting.totalAmountAllocated(), amount);
        assertEq(
            vesting.totalAmountClaimed(),
            claimableAtTGE + 2 * claimablePerMonth
        );
        assertEq(vesting.claimable(user), 0);

        vm.warp(vesting.vestingEndAt() - 1);
        assertEq(vesting.claimable(user), 3 * claimablePerMonth);
        vm.warp(vesting.vestingEndAt());
        assertEq(
            vesting.claimable(user),
            3 * claimablePerMonth + claimableLastMonth
        );

        vm.prank(user);
        vesting.claim();
        assertEq(token.balanceOf(user), amount);
        assertEq(vesting.totalAmountAllocated(), vesting.totalAmountClaimed());
    }
}

contract TestMultipleClaims is VestingBaseTest {
    mapping(uint256 => uint256) claimablePerPhase;

    function testMultipleClaims() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.warp(vesting.startDateAt());
        assertEq(token.balanceOf(user), 0);
        vm.prank(user);
        vesting.claim();
        uint256 RATE_CONVERTER = vesting.BASIS_POINT_RATE_CONVERTER();
        assertEq(
            token.balanceOf(user),
            (amount * vesting.claimableAtStart()) / RATE_CONVERTER
        );

        for (uint256 i = 0; i < 6; i++) {
            (uint256 rate, uint256 endAt, ) = vesting.phases(i);
            assertEq(vesting.claimable(user), 0);
            vm.warp(endAt + 1000);

            assertEq(vesting.claimable(user), (amount * rate) / RATE_CONVERTER);

            vm.prank(user);
            vesting.claim();
        }

        assertEq(token.balanceOf(user), amount);
    }

    function testMultipleClaimsStrangeAmounts() public {
        uint128 amount = 10000_120232021004500006;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.warp(vesting.startDateAt());
        assertEq(token.balanceOf(user), 0);
        vm.prank(user);
        vesting.claim();
        assertEq(token.balanceOf(user), 2000024046404200900001);

        claimablePerPhase[0] = 1333016026928399899850;
        claimablePerPhase[1] = 1333016026928399899850;
        claimablePerPhase[2] = 1333016026928399899850;
        claimablePerPhase[3] = 1333016026928399899850;
        claimablePerPhase[4] = 1333016026928399899850;
        claimablePerPhase[5] = 1335016050974804100755;

        for (uint256 i = 0; i < 6; i++) {
            (, uint256 endAt, ) = vesting.phases(i);
            assertEq(vesting.claimable(user), 0);
            vm.warp(endAt + 1000);

            assertEq(vesting.claimable(user), claimablePerPhase[i]);

            vm.prank(user);
            vesting.claim();
        }

        assertEq(token.balanceOf(user), amount);
    }

    function testRefundModeAndWIthdraw() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.warp(vesting.startDateAt());
        assertEq(token.balanceOf(user), 0);
        vm.prank(user);
        vesting.claim();
        assertTrue(!(token.balanceOf(user) == 0));

        vesting.setRefundMode(true);

        vm.prank(user);
        vm.expectRevert("vesting is refunded");
        vesting.claim();

        uint256 balance = token.balanceOf(address(this));
        
        vesting.withdrawRefundForAll();
        assertEq(token.balanceOf(address(vesting)), 0);
        uint256 newBalance = token.balanceOf(address(this));
        assertLt(balance, newBalance);
    }

    function testRequestRefundWithdraw() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;
        token.transfer(address(vesting), amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.warp(vesting.startDateAt());

        assertEq(token.balanceOf(user), 0);
        vm.prank(user);
        vesting.requestRefund();
        assertTrue(token.balanceOf(user) == 0);

        vm.prank(user);
        vm.expectRevert("user req refund");
        vesting.claim();

        uint256 beforeBalance = token.balanceOf(address(this));
        vesting.withdrawRequestRefundToken();
        assertEq(token.balanceOf(address(this)), beforeBalance + amount);
    }
}

contract TestMultipleClaimsOnLinearVesting is VestingBaseTest {
    function testMultipleClaims() public {
        uint128 amount = 10_000e18;
        address user = 0x0000000000000000000000000000000000000001;

        delete phases;

        phases.push(Phase(1333, 1651329000, 1)); // '2022-04-30T14:30:00.000Z'
        phases.push(Phase(1333, 1653921000, 1)); // '2022-05-30T14:30:00.000Z'
        phases.push(Phase(1333, 1656599400, 1)); // '2022-06-30T14:30:00.000Z'
        phases.push(Phase(1333, 1659191400, 1)); // '2022-07-30T14:30:00.000Z'
        phases.push(Phase(1333, 1661869800, 1)); // '2022-08-30T14:30:00.000Z'
        phases.push(Phase(1335, 1664548200, 1)); // '2022-09-30T14:30:00.000Z'

        vesting.reinitialize({
            _vestedToken: token,
            _name: "VestingIDO",
            _startDateAt: 1648650600, /// '2022-03-30T14:30:00.000Z'
            _claimableAtStart: 2000,
            _phases: phases,
            _refundGracePeriodDuration: 3 days
        });
        token.transfer(address(vesting), amount);

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](1);
        vestingsInput[0] = CreateVestingInput({user: user, amount: amount});
        vesting.createVestings(vestingsInput, true);

        vm.warp(vesting.startDateAt());
        assertEq(token.balanceOf(user), 0);
        vm.prank(user);
        vesting.claim();
        uint256 RATE_CONVERTER = vesting.BASIS_POINT_RATE_CONVERTER();
        assertEq(
            token.balanceOf(user),
            (amount * vesting.claimableAtStart()) / RATE_CONVERTER
        );

        uint256 offset = 1;
        uint256 prevEndDate = startDate;
        uint256 prevPhaseDuration;
        uint256 prevRate;
        for (uint256 i = 0; i < 6; i++) {
            (uint256 rate, uint256 endAt, ) = vesting.phases(i);
            assertEq(vesting.claimable(user), 0);

            vm.warp(endAt - offset);

            uint256 phaseDuration = endAt - prevEndDate;
            uint256 claimable = (amount * rate * (phaseDuration - offset)) / (phaseDuration * RATE_CONVERTER);

            if (prevPhaseDuration != 0) {
                claimable +=
                    (amount * prevRate * offset) /
                    (prevPhaseDuration * RATE_CONVERTER);
            }

            assertEq(vesting.claimable(user), claimable);

            vm.prank(user);
            vesting.claim();
            prevEndDate = endAt;
            prevPhaseDuration = phaseDuration;
            prevRate = rate;
        }

        vm.warp(block.timestamp + offset + 10);

        vm.prank(user);
        vesting.claim();

        assertEq(vesting.claimable(user), 0);
        assertEq(token.balanceOf(user), amount);
    }
}
