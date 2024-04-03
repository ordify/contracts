// SPDX-License Identifier:MIT
pragma solidity 0.8.23;

import {Launchpad, UserDetails} from "../../../../src/Launchpad.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IHevm {
    function prank(address) external;
}

contract LaunchpadEchidna {
    using ECDSA for bytes32;

    struct TestWhitelist{
        bytes signature;
        bytes refundSignature;
        uint256 amountRound1;
        uint256 amountRound2;
    }

    uint8 private constant round2Multiplier = 2;

    address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    IHevm hevm = IHevm(HEVM_ADDRESS);

    uint256 verfifierPrivateKeyECDSA = 0x1010101010101010101010101010101010101010101010101010101010101010;
    address verifierPublicKeyECDSA = 0xef045a554cbb0016275E90e3002f4D21c6f263e1; // derived form private key
    
    Launchpad public launchpad;
    IERC20 public stableToken;

    bool private pass = true;
    uint private createdAt = block.timestamp;

    uint256 initialBlockTime = block.timestamp;
    uint32 saleStartDate;

    mapping(address => TestWhitelist) testWhitelistUsers;

    event TestProggres(
        string msg,
        uint256 value
    );

    event TestProggres(
        string msg,
        bool value
    );

    event TestProggres(
        string msg,
        address value
    );

    event TestProggres(
        string msg,
        ECDSA.RecoverError value
    );

    constructor() {
        saleStartDate = uint32(block.timestamp + 100);
        launchpad = Launchpad(0x22e07A3412456F758d0C4b9725765697aBBD304F);
        stableToken = IERC20(0x0b6388Ee11f5B3B095d3eBa3cfc5fF90cC9b84D9);

        assert(launchpad.roundNumber() == 0);
        launchpad.setSaleStartDate(saleStartDate);
        assert(launchpad.saleStartDate() == saleStartDate);

        testWhitelistUsers[address(0x10000)] = TestWhitelist({
            signature: hex"0a42a890edeb820ba3d80121d921f0dbc1bf94240bb7450dd945e16657937ce6235b01f938af9203b13226874d87ab997115fad3377254a79f0550f3a82ec66d1c",
            refundSignature: hex"b273d1718aa69c201c31c4ed3ab8bf34ee6e311247b70ea449d2b57fa2af0b5511d489f5e3f7d97a66a092d6e7a4b86f437fb2848186d450d9a752ea6330d0a41b",
            amountRound1: 20000e18,
            amountRound2: 20000e18 * round2Multiplier
        });
        testWhitelistUsers[address(0x20000)] = TestWhitelist({
            signature: hex"84f59aa0aaab738b584ba054fb2fc326e226bbbe9c317b8e800adf7ebacb35c04170f040a6f71a20550ee29b4d7a958e3b69d3446fb82032d4e497dd11965c1f1c",
            refundSignature: hex"5b093b8d31d8a153658102c21169226676c8173710c1ce58164afffc198f2fe67f797fcef15f5bd2ac5dc7f73cce851a49190e5266bae5a406196fd1607636ee1b",
            amountRound1: 20000e18,
            amountRound2: 20000e18 * round2Multiplier
        });
        testWhitelistUsers[address(0x30000)] = TestWhitelist({
            signature: hex"76cace906ca5ce06f1a0a742d7af9ab127ffdeac990288bd025315b1ca6238b867b4f9a4ae61ced5e0771ee4f5577fecb559822b9d33bde04bca2233419507a41c",
            refundSignature: hex"6240ccca59ce6bf401ea8ee5818c5f81eda61eadc57318d13043ceffca28a9017b77e567ad86be322691a3a74140e96c2e68a3020b96f4034e796304e41541c81b",
            amountRound1: 20000e18,
            amountRound2: 20000e18 * round2Multiplier
        });

        launchpad.setRefundPercentage(2000);
    }

    function test_buyRound1(uint128 _amount) public {
        require(block.timestamp >= saleStartDate);
        require(block.timestamp < saleStartDate + launchpad.round1Duration());
        require(launchpad.roundNumber() == 1);

        address sender = msg.sender;
        require(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        TestWhitelist memory userTestDetails = testWhitelistUsers[sender];

        uint256 tokenBalance = stableToken.balanceOf(sender);
        uint256 allowanceRound1 = launchpad.round1Allowance(sender, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);
        uint256 senderContributionBefore = launchpad.getUserContribution(sender);
        uint256 launchpadSaleStartDate = launchpad.saleStartDate();

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("saleStartDate", saleStartDate);
        emit TestProggres("launchpadSaleStartDate", launchpadSaleStartDate);
        emit TestProggres("stableTarget", launchpad.stableTarget());
        emit TestProggres("stableRaised", launchpad.stableRaised());
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("tokenBalance", tokenBalance);
        emit TestProggres("allowanceRound1", allowanceRound1);
        emit TestProggres("senderContributionBefore", senderContributionBefore);

        require(_amount <= tokenBalance);
        require(_amount <= allowanceRound1);
        require(_amount > 1e18);
        require(allowanceRound1 - senderContributionBefore >= _amount);

        hevm.prank(sender);
        stableToken.approve(address(launchpad), _amount);        

        hevm.prank(sender);
        launchpad.buyRound1(_amount, userTestDetails.signature, userTestDetails.amountRound1, userTestDetails.amountRound2);

        uint256 senderContributionAfter = launchpad.getUserContribution(sender);
        uint256 contributedRound1After = launchpad.contributedRound1(sender);
        uint256 numberOfParticipants = launchpad.getNumberOfParticipants();

        emit TestProggres("senderContributionAfter", senderContributionAfter);
        emit TestProggres("contributedRound1After", contributedRound1After);
        emit TestProggres("numberOfParticipants", numberOfParticipants);

        assert(numberOfParticipants > 0);
        assert(senderContributionAfter == senderContributionBefore + _amount);
        assert(senderContributionAfter == contributedRound1After);

        uint256 totalStableCalc = 0;
        uint256 totalTokenCalc = 0;

        uint256 totalParticipants = launchpad.getNumberOfParticipants();
        for (uint i = 0; i < totalParticipants; i++) {
            address participantAddress = launchpad.participants(i);
            uint256 contributedStable = launchpad.getUserContribution(participantAddress);
            totalStableCalc = totalStableCalc + contributedStable;
        }

        emit TestProggres("totalStableCalc", totalStableCalc);
        emit TestProggres("totalTokenCalc", totalTokenCalc);

        assert(totalStableCalc >= _amount);
        assert(totalStableCalc <= launchpad.stableTarget());
    }

    function test_buyRound2(uint128 _amount) public {
        require(block.timestamp > saleStartDate + launchpad.round1Duration());
        require(launchpad.roundNumber() == 2);

        address sender = msg.sender;
        require(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        uint256 tokenBalance = stableToken.balanceOf(sender);
        uint256 allowanceRound2 = launchpad.round2Allowance(sender, testWhitelistUsers[sender].signature,  20000e18, 20000e18 * round2Multiplier);
        uint256 stableRaised = launchpad.stableRaised();
        uint256 stableTarget = launchpad.stableTarget();
        uint256 senderContributionBefore = launchpad.getUserContribution(sender);
        uint256 roundNumber = launchpad.roundNumber();
        uint256 launchpadSaleStartDate = launchpad.saleStartDate();

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("saleStartDate", saleStartDate);
        emit TestProggres("launchpadSaleStartDate", launchpadSaleStartDate);
        emit TestProggres("stableTarget", stableTarget);
        emit TestProggres("stableRaised", stableRaised);
        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("tokenBalance", tokenBalance);
        emit TestProggres("allowanceRound1", allowanceRound2);
        emit TestProggres("senderContributionBefore", senderContributionBefore);
        emit TestProggres("roundNumber", roundNumber);

        require(_amount <= tokenBalance);
        require(_amount <= allowanceRound2);
        require(_amount <= stableTarget - stableRaised);
        require(_amount > 1e18);
        
        hevm.prank(sender);
        stableToken.approve(address(launchpad), _amount);

        hevm.prank(sender);
        launchpad.buyRound2(_amount, testWhitelistUsers[sender].signature, 20000e18, 20000e18 * round2Multiplier);

        uint256 senderContributionAfter = launchpad.getUserContribution(sender);
        uint256 contributedRound1After = launchpad.contributedRound1(sender);
        uint256 contributedRound2After = launchpad.contributedRound2(sender);
        uint256 numberOfParticipants = launchpad.getNumberOfParticipants();

        emit TestProggres("senderContributionAfter", senderContributionAfter);
        emit TestProggres("contributedRound1After", contributedRound1After);
        emit TestProggres("contributedRound2After", contributedRound2After);
        emit TestProggres("numberOfParticipants", numberOfParticipants);


        assert(numberOfParticipants > 0);
        assert(senderContributionAfter == senderContributionBefore + _amount);
        assert(senderContributionAfter == contributedRound1After + contributedRound2After);

        uint256 totalStableCalc = 0;
        uint256 totalTokenCalc = 0;

        uint256 totalParticipants = launchpad.getNumberOfParticipants();
        for (uint i = 0; i < totalParticipants; i++) {
            address participantAddress = launchpad.participants(i);
            uint256 contributedStable = launchpad.getUserContribution(participantAddress);
            totalStableCalc = totalStableCalc + contributedStable;
        }

        emit TestProggres("totalStableCalc", totalStableCalc);
        emit TestProggres("totalTokenCalc", totalTokenCalc);

        assert(totalStableCalc >= _amount);
        assert(totalStableCalc <= launchpad.stableTarget());
    }

    function test_refund_after_round_1() public {
        require(block.timestamp > saleStartDate);
        require(block.timestamp < saleStartDate + launchpad.round1Duration() - 10);

        address sender = msg.sender;
        require(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        uint256 stableRaised = launchpad.stableRaised();
        uint256 stableTarget = launchpad.stableTarget();
        uint256 launchpadSaleStartDate = launchpad.saleStartDate();
        uint256 contribution = launchpad.getUserContribution(sender);
        bool endUnlocked = launchpad.endUnlocked();
        bool refundEnabled = launchpad.globalRefundEnabled();
        uint256 userRefundedAmount = launchpad.getUserRefundedAmount(sender);
        uint256 roundNumber = launchpad.roundNumber();

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("saleStartDate", saleStartDate);
        emit TestProggres("launchpadSaleStartDate", launchpadSaleStartDate);
        emit TestProggres("stableRaised", stableRaised);
        emit TestProggres("stableTarget", stableTarget);
        emit TestProggres("contribution", contribution);
        emit TestProggres("endUnlocked", endUnlocked);
        emit TestProggres("refundEnabled", refundEnabled);
        emit TestProggres("userRefundedAmount", userRefundedAmount);
        emit TestProggres("roundNumber", roundNumber);

        require(userRefundedAmount == 0);
        require(contribution > 0);

        assert(roundNumber == 1 || roundNumber == 3);
        assert(contribution > 0);
        assert(userRefundedAmount == 0);

        if(!endUnlocked) {
            launchpad.finishSale();
        }
        if(!refundEnabled) {
            launchpad.setGlobalRefundEnabled(true);
        }

        uint256 beforeBalance = stableToken.balanceOf(sender);
        emit TestProggres("beforeBalance", beforeBalance);

        hevm.prank(sender);
        launchpad.refund(testWhitelistUsers[sender].refundSignature);

        uint256 afterBalance = stableToken.balanceOf(sender);
        emit TestProggres("afterBalance", afterBalance);
        emit TestProggres("beforeBalance + (contribution * 2000 / 10000)", beforeBalance + (contribution * 2000 / 10000));
        
        assert(afterBalance >= beforeBalance + (contribution * 2000 / 10000));
    }

    function test_refund_after_round_2() public {
        require(block.timestamp > saleStartDate + launchpad.round1Duration() + 1 hours);

        address sender = msg.sender;
        require(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        uint256 stableRaised = launchpad.stableRaised();
        uint256 stableTarget = launchpad.stableTarget();
        uint256 launchpadSaleStartDate = launchpad.saleStartDate();
        uint256 contribution = launchpad.getUserContribution(sender);
        bool endUnlocked = launchpad.endUnlocked();
        bool refundEnabled = launchpad.globalRefundEnabled();
        uint256 userRefundedAmount = launchpad.getUserRefundedAmount(sender);
        uint256 roundNumber = launchpad.roundNumber();

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("saleStartDate", saleStartDate);
        emit TestProggres("launchpadSaleStartDate", launchpadSaleStartDate);
        emit TestProggres("stableRaised", stableRaised);
        emit TestProggres("stableTarget", stableTarget);
        emit TestProggres("contribution", contribution);
        emit TestProggres("endUnlocked", endUnlocked);
        emit TestProggres("refundEnabled", refundEnabled);
        emit TestProggres("userRefundedAmount", userRefundedAmount);
        emit TestProggres("roundNumber", roundNumber);

        require(contribution > 0);
        require(userRefundedAmount == 0);

        assert(roundNumber == 2 || roundNumber == 3);
        assert(userRefundedAmount == 0);
        assert(contribution > 0);

        if(!endUnlocked) {
            launchpad.finishSale();
        }
        if(!refundEnabled) {
            launchpad.setGlobalRefundEnabled(true);
        }

        uint256 beforeBalance = stableToken.balanceOf(sender);
        emit TestProggres("beforeBalance", beforeBalance);

        hevm.prank(sender);
        launchpad.refund(testWhitelistUsers[sender].refundSignature);

        uint256 afterBalance = stableToken.balanceOf(sender);
        emit TestProggres("afterBalance", afterBalance);
        emit TestProggres("beforeBalance + (contribution * 2000 / 10000)", beforeBalance + (contribution * 2000 / 10000));
        
        assert(afterBalance >= beforeBalance + (contribution * 2000 / 10000));
    }

    function test_requested_refund() public {
        require(block.timestamp > saleStartDate + launchpad.round1Duration() + 1 hours);

        address sender = msg.sender;
        require(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        uint256 stableRaised = launchpad.stableRaised();
        uint256 stableTarget = launchpad.stableTarget();
        uint256 launchpadSaleStartDate = launchpad.saleStartDate();
        uint256 contribution = launchpad.getUserContribution(sender);
        bool endUnlocked = launchpad.endUnlocked();
        bool refundEnabled = launchpad.globalRefundEnabled();
        uint256 userRefundedAmount = launchpad.getUserRefundedAmount(sender);
        uint256 roundNumber = launchpad.roundNumber();

        emit TestProggres("block.timestamp", block.timestamp);
        emit TestProggres("saleStartDate", saleStartDate);
        emit TestProggres("launchpadSaleStartDate", launchpadSaleStartDate);
        emit TestProggres("stableRaised", stableRaised);
        emit TestProggres("stableTarget", stableTarget);
        emit TestProggres("contribution", contribution);
        emit TestProggres("endUnlocked", endUnlocked);
        emit TestProggres("refundEnabled", refundEnabled);
        emit TestProggres("userRefundedAmount", userRefundedAmount);
        emit TestProggres("roundNumber", roundNumber);

        require(contribution > 0);
        require(userRefundedAmount == 0);

        assert(roundNumber == 2 || roundNumber == 3);
        assert(userRefundedAmount == 0);
        assert(contribution > 0);

        if(!endUnlocked) {
            launchpad.finishSale();
        }
        if(refundEnabled) {
            launchpad.setGlobalRefundEnabled(false);
        }
        
        UserDetails memory userDetail = launchpad.getUserDetails(sender);
        emit TestProggres("userDetail.contributedRound1", userDetail.contributedRound1);
        emit TestProggres("userDetail.contributedRound2", userDetail.contributedRound2);
        emit TestProggres("userDetail.refundedAmount", userDetail.refundedAmount);

        uint256 beforeBalance = stableToken.balanceOf(sender);
        emit TestProggres("beforeBalance", beforeBalance);

        hevm.prank(sender);
        launchpad.refund(testWhitelistUsers[sender].refundSignature);

        uint256 afterBalance = stableToken.balanceOf(sender);
        emit TestProggres("afterBalance", afterBalance);
        emit TestProggres("beforeBalance + (contribution * 20 / 10000)", beforeBalance + (contribution * 2000 / 10000));
        
        assert(afterBalance >= beforeBalance + (contribution * 2000 / 10000));
    }

    function test_verify_signatures_valid() public {
        address sender = msg.sender;
        emit TestProggres("sender", sender);
        assert(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        TestWhitelist memory userTestDetails = testWhitelistUsers[sender];
        bytes32 signedMessageHash = keccak256(abi.encode(address(launchpad), sender, userTestDetails.amountRound1, userTestDetails.amountRound2)).toEthSignedMessageHash();

        (address recoveredSigner, ECDSA.RecoverError returnedError) = signedMessageHash.tryRecover(userTestDetails.signature);
        assert(recoveredSigner == launchpad.verifyingAddressECDSA());
        assert(returnedError == ECDSA.RecoverError.NoError);
    }

    function test_verify_signatures_invalid() public {
        address sender = msg.sender;
        emit TestProggres("sender", sender);
        assert(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        bytes32 signedMessageHash = keccak256(abi.encode(address(launchpad), sender, 100)).toEthSignedMessageHash();

        (address recoveredSigner, ECDSA.RecoverError returnedError) = signedMessageHash.tryRecover(hex"de09970c56bf3b0608be81e25ab13c");

        emit TestProggres("recoveredSigner", recoveredSigner);
        emit TestProggres("returnedError", returnedError);

        assert(recoveredSigner == address(0));
    }

    function test_refund_verify_signatures_valid() public {
        address sender = msg.sender;
        emit TestProggres("sender", sender);
        assert(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        TestWhitelist memory userTestDetails = testWhitelistUsers[sender];
        bytes32 signedMessageHash = keccak256(abi.encode(address(launchpad), sender)).toEthSignedMessageHash();

        (address recoveredSigner, ECDSA.RecoverError returnedError) = signedMessageHash.tryRecover(userTestDetails.refundSignature);
        assert(recoveredSigner == launchpad.verifyingAddressECDSA());
        assert(returnedError == ECDSA.RecoverError.NoError);
    }

    function test_refund_verify_signatures_invalid() public {
        address sender = msg.sender;
        emit TestProggres("sender", sender);
        assert(sender == address(0x10000) || sender == address(0x20000) || sender == address(0x30000));

        bytes32 signedMessageHash = keccak256(abi.encode(address(launchpad), address(0x111222))).toEthSignedMessageHash();

        (address recoveredSigner, ECDSA.RecoverError returnedError) = signedMessageHash.tryRecover(hex"de09970c56bf3b0608be81e25ab13c");

        emit TestProggres("recoveredSigner", recoveredSigner);
        emit TestProggres("returnedError", returnedError);

        assert(recoveredSigner == address(0));
    }
}