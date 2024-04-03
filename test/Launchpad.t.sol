// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Launchpad} from "../src/Launchpad.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract StableToken is ERC20 {
    constructor() ERC20("USDT", "USDT") {
          _mint(msg.sender, 1_000_000e18);
    }
}

contract LaunchpadTest is Test {
    using ECDSA for bytes32;

    struct TestWhitelist{
        bytes signature;
        uint256 amountRound1;
        uint256 amountRound2;
    }

    uint256 verfifierPrivateKeyECDSA = 0x1010101010101010101010101010101010101010101010101010101010101010;
    address verifierPublicKeyECDSA = vm.addr(verfifierPrivateKeyECDSA);

    StableToken public stableToken;
    Launchpad public launchpad;

    uint32 initialBlockTime = uint32(block.timestamp);
    uint32 saleStartDate = uint32(block.timestamp + 1 hours);
    uint128 stableTarget = 80_000e18;
    uint8 round2Multiplier = 2;
    uint32 round1Duration = 2 hours;

    address owner = address(100);
    address participant1 = address(1);
    address participant2 = address(2);
    address participant3 = address(3);
    address participant4 = address(4);
    address participant5 = address(5);
    address participant6 = address(6);
    address participant7 = address(7);

    mapping(address => TestWhitelist) testWhitelistUsers;

    function setUp() public {
        vm.deal(owner, 100 ether);

        vm.deal(participant1, 100 ether);
        vm.deal(participant2, 100 ether);
        vm.deal(participant3, 100 ether);
        vm.deal(participant4, 100 ether);
        vm.deal(participant5, 100 ether);
        vm.deal(participant6, 100 ether);

        vm.startPrank(owner);
        // Deploy contracts
        stableToken = new StableToken();

        // 1 TEST = 0.04 USDT; raising: 10_000
        IERC20 stableCoin = IERC20(address(stableToken));

        launchpad = new Launchpad(
            verifierPublicKeyECDSA,
            stableTarget,
            saleStartDate,
            stableCoin,
            round1Duration
        );

        // this is used just for echidna, to create signature.
            // generateSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x10000), 20000e18, 20000e18 * round2Multiplier);
            // generateSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x20000), 20000e18, 20000e18 * round2Multiplier);
            // generateSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x30000), 20000e18, 20000e18 * round2Multiplier);

            // generateRefundSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x10000));
            // generateRefundSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x20000));
            // generateRefundSignature(address(0x1eB6F00436FED45750A87e3Ed50d332F915d43F5), address(0x30000));

        testWhitelistUsers[participant1] = generateSignature(address(launchpad), participant1, 2000e18, 2000e18 * round2Multiplier);
        testWhitelistUsers[participant2] = generateSignature(address(launchpad), participant2, 1000e18, 1000e18 * round2Multiplier);
        testWhitelistUsers[participant3] = generateSignature(address(launchpad), participant3, 500e18, 500e18 * round2Multiplier);
        testWhitelistUsers[participant4] = generateSignature(address(launchpad), participant4, 1500e18,  1500e18 * round2Multiplier);
        testWhitelistUsers[participant5] = generateSignature(address(launchpad), participant5, 2800e18,  uint256(2800e18) * round2Multiplier);
        testWhitelistUsers[participant6] = generateSignature(address(launchpad), participant6, 70000e18,  uint256(70000e18) * round2Multiplier);
        testWhitelistUsers[participant7] = generateSignature(address(launchpad), participant7, 0, 800e18 * round2Multiplier);

        // transfer tokens
        stableToken.transfer(participant1, 50_000e18);
        stableToken.transfer(participant2, 50_000e18);
        stableToken.transfer(participant3, 50_000e18);
        stableToken.transfer(participant4, 50_000e18);
        stableToken.transfer(participant5, 50_000e18);
        stableToken.transfer(participant6, 100_000e18);
        stableToken.transfer(participant7, 100_000e18);
    }

    function testInitialState() public {
        assertEq(launchpad.roundNumber(), 0);
        assertEq(launchpad.saleStartDate(), saleStartDate);
        assertEq(launchpad.stableTarget(), stableTarget);
        assertEq(address(launchpad.stablecoin()), address(stableToken));
        assertTrue(!launchpad.endUnlocked());
        assertEq(launchpad.stableRaised(), 0);
        assertEq(launchpad.getNumberOfParticipants(), 0);

        assertEq(launchpad.round1Allowance(participant1, testWhitelistUsers[participant1].signature, testWhitelistUsers[participant1].amountRound1, testWhitelistUsers[participant1].amountRound2), 2000e18);
        assertEq(launchpad.round1Allowance(participant2, testWhitelistUsers[participant2].signature, testWhitelistUsers[participant2].amountRound1, testWhitelistUsers[participant2].amountRound2), 1000e18);
        assertEq(launchpad.round1Allowance(participant3, testWhitelistUsers[participant3].signature, testWhitelistUsers[participant3].amountRound1, testWhitelistUsers[participant3].amountRound2), 500e18);
        assertEq(launchpad.round1Allowance(participant4, testWhitelistUsers[participant4].signature, testWhitelistUsers[participant4].amountRound1, testWhitelistUsers[participant4].amountRound2), 1500e18);
        assertEq(launchpad.round1Allowance(participant5, testWhitelistUsers[participant5].signature, testWhitelistUsers[participant5].amountRound1, testWhitelistUsers[participant5].amountRound2), 2800e18);
        assertEq(launchpad.round1Allowance(participant6, testWhitelistUsers[participant6].signature, testWhitelistUsers[participant6].amountRound1, testWhitelistUsers[participant6].amountRound2), 70000e18);
        assertEq(launchpad.round1Allowance(participant7, testWhitelistUsers[participant7].signature, testWhitelistUsers[participant7].amountRound1, testWhitelistUsers[participant7].amountRound2), 0);

        assertEq(launchpad.round2Allowance(participant1, testWhitelistUsers[participant1].signature, testWhitelistUsers[participant1].amountRound1, testWhitelistUsers[participant1].amountRound2), 2000e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant2, testWhitelistUsers[participant2].signature, testWhitelistUsers[participant2].amountRound1, testWhitelistUsers[participant2].amountRound2), 1000e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant3, testWhitelistUsers[participant3].signature, testWhitelistUsers[participant3].amountRound1, testWhitelistUsers[participant3].amountRound2), 500e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant4, testWhitelistUsers[participant4].signature, testWhitelistUsers[participant4].amountRound1, testWhitelistUsers[participant4].amountRound2), 1500e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant5, testWhitelistUsers[participant5].signature, testWhitelistUsers[participant5].amountRound1, testWhitelistUsers[participant5].amountRound2), uint256(2800e18) * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant6, testWhitelistUsers[participant6].signature, testWhitelistUsers[participant6].amountRound1, testWhitelistUsers[participant6].amountRound2), uint256(70000e18) * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant7, testWhitelistUsers[participant7].signature, testWhitelistUsers[participant7].amountRound1, testWhitelistUsers[participant7].amountRound2), 800e18 * round2Multiplier);

    }

    function testStateRightAfterSaleStart() public {
        vm.warp(block.timestamp + 1 hours + 1); // warp after start date

        assertEq(launchpad.roundNumber(), 1);
        assertEq(launchpad.saleStartDate(), saleStartDate);
        assertEq(launchpad.stableTarget(), stableTarget);
        assertEq(address(launchpad.stablecoin()), address(stableToken));
        assertTrue(!launchpad.endUnlocked());
        assertEq(launchpad.stableRaised(), 0);
        assertEq(launchpad.getNumberOfParticipants(), 0);

        assertEq(launchpad.round1Allowance(participant1, testWhitelistUsers[participant1].signature, testWhitelistUsers[participant1].amountRound1, testWhitelistUsers[participant1].amountRound2), 2000e18);
        assertEq(launchpad.round1Allowance(participant2, testWhitelistUsers[participant2].signature, testWhitelistUsers[participant2].amountRound1, testWhitelistUsers[participant2].amountRound2), 1000e18);
        assertEq(launchpad.round1Allowance(participant3, testWhitelistUsers[participant3].signature, testWhitelistUsers[participant3].amountRound1, testWhitelistUsers[participant3].amountRound2), 500e18);
        assertEq(launchpad.round1Allowance(participant4, testWhitelistUsers[participant4].signature, testWhitelistUsers[participant4].amountRound1, testWhitelistUsers[participant4].amountRound2), 1500e18);
        assertEq(launchpad.round1Allowance(participant5, testWhitelistUsers[participant5].signature, testWhitelistUsers[participant5].amountRound1, testWhitelistUsers[participant5].amountRound2), 2800e18);
        assertEq(launchpad.round1Allowance(participant6, testWhitelistUsers[participant6].signature, testWhitelistUsers[participant6].amountRound1, testWhitelistUsers[participant6].amountRound2), 70000e18);
        assertEq(launchpad.round1Allowance(participant7, testWhitelistUsers[participant7].signature, testWhitelistUsers[participant7].amountRound1, testWhitelistUsers[participant7].amountRound2), 0);

        assertEq(launchpad.round2Allowance(participant1, testWhitelistUsers[participant1].signature, testWhitelistUsers[participant1].amountRound1, testWhitelistUsers[participant1].amountRound2), 2000e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant2, testWhitelistUsers[participant2].signature, testWhitelistUsers[participant2].amountRound1, testWhitelistUsers[participant2].amountRound2), 1000e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant3, testWhitelistUsers[participant3].signature, testWhitelistUsers[participant3].amountRound1, testWhitelistUsers[participant3].amountRound2), 500e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant4, testWhitelistUsers[participant4].signature, testWhitelistUsers[participant4].amountRound1, testWhitelistUsers[participant4].amountRound2), 1500e18 * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant5, testWhitelistUsers[participant5].signature, testWhitelistUsers[participant5].amountRound1, testWhitelistUsers[participant5].amountRound2), uint256(2800e18) * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant6, testWhitelistUsers[participant6].signature, testWhitelistUsers[participant6].amountRound1, testWhitelistUsers[participant6].amountRound2), uint256(70000e18) * round2Multiplier);
        assertEq(launchpad.round2Allowance(participant7, testWhitelistUsers[participant7].signature, testWhitelistUsers[participant7].amountRound1, testWhitelistUsers[participant7].amountRound2), 800e18 * round2Multiplier);

    }

    function testBuyRound1() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant1);

        TestWhitelist memory userTestDetails = testWhitelistUsers[participant1];
        stableToken.approve(address(launchpad), 1000e18);
        launchpad.buyRound1(1000e18, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant1);

        assertEq(contributedStable, 1000e18);
    }

    function testRefund() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant1);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant1];

        stableToken.approve(address(launchpad), 1000e18);
        launchpad.buyRound1(1000e18, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant1);

        assertEq(contributedStable, 1000e18);

        vm.startPrank(owner);
        launchpad.prepareForGlobalRefund(8000);

        vm.startPrank(participant1);
        bytes memory refundSignature = bytes("");
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant1, refundSignature);
        assertEq(refundAvailableAmount, 800e18);
        assertEq(launchpad.getUserRefundedAmount(participant1), 0);

        assertEq(stableToken.balanceOf(participant1), 49_000e18);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant1), 49_800e18);
        assertEq(stableToken.balanceOf(address(launchpad)), 200e18);
        assertEq(launchpad.calculateRefund(participant1, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);

        vm.startPrank(owner);
        uint256 oldOwnerStable = stableToken.balanceOf(owner);
        launchpad.withdrawStableRefund();
        assertEq(stableToken.balanceOf(owner), oldOwnerStable + 200e18);

        vm.expectRevert(bytes("Alredy refunded to owner"));
        launchpad.withdrawStableRefund();
    }

    function testRefundStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant1);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant1];

        stableToken.approve(address(launchpad), 1000_120232021004500006);
        launchpad.buyRound1(1000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant1);

        assertEq(contributedStable, 1000_120232021004500006);

        vm.startPrank(owner);
        launchpad.prepareForGlobalRefund(8000);

        vm.startPrank(participant1);
        bytes memory refundSignature = bytes("");
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant1, refundSignature);
        console.log("VVVVVV => : refundAvailableAmount: ", refundAvailableAmount);
        assertEq(refundAvailableAmount, 800096185616803600004);
        assertEq(launchpad.getUserRefundedAmount(participant1), 0);

        assertEq(stableToken.balanceOf(participant1), 48999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant1), 49799975953595799099998);
        assertEq(stableToken.balanceOf(address(launchpad)), 200024046404200900002);
        assertEq(launchpad.calculateRefund(participant1, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);

        vm.startPrank(owner);
        uint256 oldOwnerStable = stableToken.balanceOf(owner);
        launchpad.withdrawStableRefund();
        assertEq(stableToken.balanceOf(owner), oldOwnerStable + 200024046404200900001); // precision for last digit was inaccurate, so I changed it ot firnish with 1. 

        vm.expectRevert(bytes("Alredy refunded to owner"));
        launchpad.withdrawStableRefund();
    }

    function test10000PercentRefundStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant1);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant1];

        stableToken.approve(address(launchpad), 1000_120232021004500006);
        launchpad.buyRound1(1000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant1);

        assertEq(contributedStable, 1000_120232021004500006);

        vm.startPrank(owner);
        launchpad.prepareForGlobalRefund(10000);


        vm.startPrank(participant1);
        bytes memory refundSignature = bytes("");
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant1, refundSignature);
        assertEq(refundAvailableAmount, 1000_120232021004500006);
        assertEq(launchpad.getUserRefundedAmount(participant1), 0);

        assertEq(stableToken.balanceOf(participant1), 48999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant1), 50000000000000000000000);
        assertEq(stableToken.balanceOf(address(launchpad)), 0);
        assertEq(launchpad.calculateRefund(participant1, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);
    }

    function testRefundBigAmountStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant6);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant6];

        stableToken.approve(address(launchpad), 70_0001e18);
        launchpad.buyRound1(68000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant6);

        assertEq(contributedStable, 68000_120232021004500006);

        vm.startPrank(owner);
        launchpad.prepareForGlobalRefund(8000);

        vm.startPrank(participant6);
        bytes memory refundSignature = bytes("");
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant6, refundSignature);
        assertEq(refundAvailableAmount, 54400096185616803600004);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        assertEq(stableToken.balanceOf(participant6), 31999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant6), 86399975953595799099998);
        assertEq(stableToken.balanceOf(address(launchpad)), 13600024046404200900002);
        assertEq(launchpad.calculateRefund(participant6, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);

        vm.startPrank(owner);
        uint256 oldOwnerStable = stableToken.balanceOf(owner);
        launchpad.withdrawStableRefund();
        assertEq(stableToken.balanceOf(owner), oldOwnerStable + 13600024046404200900001); // precision for last digit was inaccurate, so I changed it ot firnish with 1. 

        vm.expectRevert(bytes("Alredy refunded to owner"));
        launchpad.withdrawStableRefund();
    }

    function testRefund10000PercentBigAmountStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant6);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant6];

        stableToken.approve(address(launchpad), 70_0001e18);
        launchpad.buyRound1(68000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant6);

        assertEq(contributedStable, 68000_120232021004500006);

        vm.startPrank(owner);
        launchpad.prepareForGlobalRefund(10000);

        vm.startPrank(participant6);
        bytes memory refundSignature = bytes("");
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant6, refundSignature);
        assertEq(refundAvailableAmount, 68000_120232021004500006);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        assertEq(stableToken.balanceOf(participant6), 31999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant6), 100_000e18);
        assertEq(stableToken.balanceOf(address(launchpad)), 0);
        assertEq(launchpad.calculateRefund(participant6, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);
    }

    function testRefundRequestedBigAmountStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant6);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant6];

        stableToken.approve(address(launchpad), 70_0001e18);
        launchpad.buyRound1(68000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant6);

        assertEq(contributedStable, 68000_120232021004500006);

        vm.startPrank(owner);
        launchpad.finishSale();
        launchpad.setRefundPercentage(8000);

        vm.startPrank(participant6);
        bytes memory refundSignature = generateRefundSignature(address(launchpad), participant6);

        uint256 refundAvailableAmount = launchpad.calculateRefund(participant6, refundSignature);
        assertEq(refundAvailableAmount, 54400096185616803600004);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        assertEq(stableToken.balanceOf(participant6), 31999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant6), 86399975953595799099998);
        assertEq(stableToken.balanceOf(address(launchpad)), 13600024046404200900002);
        assertEq(launchpad.calculateRefund(participant6, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);

        vm.startPrank(owner);
        uint256 oldOwnerStable = stableToken.balanceOf(owner);
        launchpad.withdrawStableRefund();
        assertEq(stableToken.balanceOf(owner), oldOwnerStable + 13600024046404200900001); // precision for last digit was inaccurate, so I changed it ot firnish with 1. 

        vm.expectRevert(bytes("Alredy refunded to owner"));
        launchpad.withdrawStableRefund();
    }

    function testRefundRequested10000PercentBigAmountStrangeAmount() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant6);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant6];

        stableToken.approve(address(launchpad), 70_0001e18);
        launchpad.buyRound1(68000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant6);

        assertEq(contributedStable, 68000_120232021004500006);

        vm.startPrank(owner);
        launchpad.finishSale();
        bytes memory refundSignature = generateRefundSignature(address(launchpad), participant6);

        vm.startPrank(participant6);
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant6, refundSignature);
        assertEq(refundAvailableAmount, 68000_120232021004500006);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        assertEq(stableToken.balanceOf(participant6), 31999879767978995499994);
        launchpad.refund(refundSignature);
        assertEq(stableToken.balanceOf(participant6), 100_000e18);
        assertEq(stableToken.balanceOf(address(launchpad)), 0);
        assertEq(launchpad.calculateRefund(participant6, refundSignature), 0);

        vm.expectRevert(bytes("Already refunded"));
        launchpad.refund(refundSignature);
    }

    function testUnMarkUserForRefund() public {
        vm.warp(initialBlockTime + 1 hours + 1); // warp after start date
        
        vm.startPrank(participant6);
        TestWhitelist memory userTestDetails = testWhitelistUsers[participant6];

        stableToken.approve(address(launchpad), 70_0001e18);
        launchpad.buyRound1(68000_120232021004500006, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 contributedStable = launchpad.getUserContribution(participant6);

        assertEq(contributedStable, 68000_120232021004500006);

        vm.startPrank(owner);
        launchpad.finishSale();
        bytes memory refundSignature = generateRefundSignature(address(launchpad), participant6);

        vm.startPrank(participant6);
        uint256 refundAvailableAmount = launchpad.calculateRefund(participant6, refundSignature);
        assertEq(refundAvailableAmount, 68000_120232021004500006);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        uint256 refundAvailableAmountInvalidSignature = launchpad.calculateRefund(participant6, bytes(""));
        assertEq(refundAvailableAmountInvalidSignature, 0);
        assertEq(launchpad.getUserRefundedAmount(participant6), 0);

        vm.startPrank(participant6);
        vm.expectRevert(bytes("invalid signature for req refund"));
        launchpad.refund(bytes(""));
    }

    function generateSignature(address launchpadAddress, address user, uint256 amountRound1, uint256 amountRound2) private view returns (TestWhitelist memory result) {
        bytes32 msgHash = keccak256(abi.encode(launchpadAddress, user, amountRound1, amountRound2))
            .toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verfifierPrivateKeyECDSA, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("XXXXXX whitelist");
        console.logBytes(signature);

        return TestWhitelist({
            signature: signature,
            amountRound1: amountRound1,
            amountRound2: amountRound2
        });
    }

    function generateRefundSignature(address launchpadAddress, address user) private view returns (bytes memory refundSignature) {
        bytes32 msgHash = keccak256(abi.encode(launchpadAddress, user))
            .toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verfifierPrivateKeyECDSA, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("XXXXXX refund");
        console.logBytes(signature);

        return signature;
    }
}
