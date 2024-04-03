// SPDX-License Identifier:MIT
pragma solidity 0.8.23;

import {Phase, CreateVestingInput, Vesting} from "../../../../src/Vesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IHevm {
    function prank(address) external;
}

contract VestingEchidna {
    address echidnaUser1 = address(0x10000);
    address echidnaUser2 = address(0x20000);
    address echidnaUser3 = address(0x30000);

    mapping(uint256 => address) private senderRandomizer;


    address internal treasury = address(0x40000);

    address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    IHevm hevm = IHevm(HEVM_ADDRESS);

    Vesting public vesting;
    IERC20 public token;
    Phase[] internal phases;

    bool private pass = true;
    uint private createdAt = block.timestamp;
    uint256 initialBlockTime = block.timestamp;

    event TestProggres(
        string msg,
        uint256 amount
    );

    event TestProggres(
        string msg,
        string value
    );

    event TestProggres(
        string msg,
        bool value
    );

    event TestProggresBool(
        string msg,
        bool value
    );

    constructor() {
        vesting = Vesting(0x53d8c63cC052B54127023218f565aD1288433f52);
        token = IERC20(0x59C69F9fe3C83d346C5c6198d9BD3DD74A7Dfea5);

        senderRandomizer[0] = echidnaUser1;
        senderRandomizer[1] = echidnaUser2;
        senderRandomizer[2] = echidnaUser3;
        

        token.transfer(address(vesting), 200_000e18);

        phases.push(Phase(1333, uint40(initialBlockTime + 10 days), 3600)); // every hour
        phases.push(Phase(1333, uint40(initialBlockTime + 20 days), 1));    // linear
        phases.push(Phase(1333, uint40(initialBlockTime + 30 days), 0));    // at the end of phase
        phases.push(Phase(1333, uint40(initialBlockTime + 40 days), 1));    // linear
        phases.push(Phase(1333, uint40(initialBlockTime + 50 days), 50));   // every 50 seconds
        phases.push(Phase(1335, uint40(initialBlockTime + 60 days), 3));    // every 3 seconds

        vesting.reinitialize(
            {
                _vestedToken: token,
                _name: "VestingIDO",
                _startDateAt: uint40(initialBlockTime + 1 days),
                _claimableAtStart: 2000,
                _phases: phases,
                _refundGracePeriodDuration: 7 days
            }
        );
    }

    function test_createVestings(uint256 amount) public {
        require(block.timestamp < vesting.startDateAt());
        require(amount > 1000e18 && amount < 90_000e18);
        
        uint128 amount1 = uint128(amount / 2);
        uint128 amount2 = uint128(amount / 3);
        uint128 amount3 = uint128(amount / 4);

        emit TestProggres("amount1", amount1);
        emit TestProggres("amount2", amount2);
        emit TestProggres("amount3", amount3);

        Vesting.UserVesting memory echidnaUser1Vestings = vesting.getUserVesting(echidnaUser1);
        Vesting.UserVesting memory echidnaUser2Vestings = vesting.getUserVesting(echidnaUser2);
        Vesting.UserVesting memory echidnaUser3Vestings = vesting.getUserVesting(echidnaUser3);

        require(!echidnaUser1Vestings.init);
        require(!echidnaUser2Vestings.init);
        require(!echidnaUser3Vestings.init);

        logVesting(echidnaUser1Vestings, "echidnaUser1Vestings");
        logVesting(echidnaUser2Vestings, "echidnaUser2Vestings");
        logVesting(echidnaUser3Vestings, "echidnaUser3Vestings");

        CreateVestingInput[] memory vestingsInput = new CreateVestingInput[](3);
        vestingsInput[0] = CreateVestingInput({user: echidnaUser1, amount: amount1});
        vestingsInput[1] = CreateVestingInput({user: echidnaUser2, amount: amount2});
        vestingsInput[2] = CreateVestingInput({user: echidnaUser3, amount: amount3});

        vesting.createVestings(vestingsInput, true);

        Vesting.UserVesting memory echidnaUser1VestingsAfter = vesting.getUserVesting(echidnaUser1);
        Vesting.UserVesting memory echidnaUser2VestingsAfter = vesting.getUserVesting(echidnaUser2);
        Vesting.UserVesting memory echidnaUser3VestingsAfter = vesting.getUserVesting(echidnaUser3);

        logVesting(echidnaUser1VestingsAfter, "echidnaUser1VestingsAfter");
        logVesting(echidnaUser2VestingsAfter, "echidnaUser2VestingsAfter");
        logVesting(echidnaUser3VestingsAfter, "echidnaUser3VestingsAfter");

        assert(echidnaUser1VestingsAfter.init);
        assert(echidnaUser2VestingsAfter.init);
        assert(echidnaUser3VestingsAfter.init);

        assert(echidnaUser1VestingsAfter.amount == amount1);
        assert(echidnaUser2VestingsAfter.amount == amount2);
        assert(echidnaUser3VestingsAfter.amount == amount3);
    }

    function test_claim_before_start() public {
        require(block.timestamp < vesting.startDateAt());

        Vesting.UserVesting memory echidnaUser1Vestings = vesting.getUserVesting(echidnaUser1);
        Vesting.UserVesting memory echidnaUser2Vestings = vesting.getUserVesting(echidnaUser2);
        Vesting.UserVesting memory echidnaUser3Vestings = vesting.getUserVesting(echidnaUser3);

        require(echidnaUser1Vestings.init);
        require(echidnaUser2Vestings.init);
        require(echidnaUser3Vestings.init);

        address sender = msg.sender;
        uint256 claimable = vesting.claimable(sender);
        emit TestProggres("claimable", claimable);

        assert(claimable == 0);

        uint256 nextBatchAt = vesting.nextBatchAt();
        uint256 startDateAt = vesting.startDateAt();
        emit TestProggres("nextBatchAt", nextBatchAt);
        emit TestProggres("startDateAt", startDateAt);

        assert(nextBatchAt == vesting.startDateAt());
    }

    function test_request_refund() public {
        require(block.timestamp < vesting.startDateAt() + vesting.refundGracePeriodDuration());

        address sender = msg.sender;
        Vesting.UserVesting memory senderVestings = vesting.getUserVesting(sender);
        emit TestProggres("senderVestings.init", senderVestings.init);
        emit TestProggres("senderVestings.requestedRefund", senderVestings.requestedRefund);
        emit TestProggres("senderVestings.amount", senderVestings.amount);
        emit TestProggres("senderVestings.amountClaimed", senderVestings.amountClaimed);
        emit TestProggres("senderVestings.lastClaimAt", senderVestings.lastClaimAt);

        require(senderVestings.init);
        require(!senderVestings.requestedRefund);
        require(senderVestings.amountClaimed == 0);

        uint256 claimable = vesting.claimable(sender);
        emit TestProggres("claimable", claimable);
        assert(claimable >= 0);

        hevm.prank(sender);
        vesting.requestRefund();

        Vesting.UserVesting memory senderVestingsAfter = vesting.getUserVesting(sender);
        emit TestProggres("senderVestingsAfter.init", senderVestingsAfter.init);
        emit TestProggres("senderVestingsAfter.requestedRefund", senderVestingsAfter.requestedRefund);
        emit TestProggres("senderVestingsAfter.amount", senderVestingsAfter.amount);
        emit TestProggres("senderVestingsAfter.amountClaimed", senderVestingsAfter.amountClaimed);
        emit TestProggres("senderVestingsAfter.lastClaimAt", senderVestingsAfter.lastClaimAt);
        assert(senderVestingsAfter.requestedRefund);

        uint256 claimableAfter = vesting.claimable(sender);
        emit TestProggres("claimableAfter", claimableAfter);
        assert(claimableAfter == 0);
    }

    function test_pull_back_request_refund() public {
        require(block.timestamp < vesting.startDateAt() + vesting.refundGracePeriodDuration());

        address sender = msg.sender;
        Vesting.UserVesting memory senderVestings = vesting.getUserVesting(sender);
        emit TestProggres("senderVestings.init", senderVestings.init);
        emit TestProggres("senderVestings.requestedRefund", senderVestings.requestedRefund);
        emit TestProggres("senderVestings.amount", senderVestings.amount);
        emit TestProggres("senderVestings.amountClaimed", senderVestings.amountClaimed);
        emit TestProggres("senderVestings.lastClaimAt", senderVestings.lastClaimAt);
        require(senderVestings.init);
        require(senderVestings.requestedRefund);
        require(senderVestings.amountClaimed == 0);

        uint256 claimable = vesting.claimable(sender);
        emit TestProggres("claimable", claimable);
        assert(claimable == 0);

        hevm.prank(sender);
        vesting.pullBackRequestRefund();

        Vesting.UserVesting memory senderVestingsAfter = vesting.getUserVesting(sender);
        emit TestProggres("senderVestingsAfter.init", senderVestingsAfter.init);
        emit TestProggres("senderVestingsAfter.requestedRefund", senderVestingsAfter.requestedRefund);
        emit TestProggres("senderVestingsAfter.amount", senderVestingsAfter.amount);
        emit TestProggres("senderVestingsAfter.amountClaimed", senderVestingsAfter.amountClaimed);
        emit TestProggres("senderVestingsAfter.lastClaimAt", senderVestingsAfter.lastClaimAt);
        assert(!senderVestingsAfter.requestedRefund);

        uint256 claimableAfter = vesting.claimable(sender);
        emit TestProggres("claimableAfter", claimableAfter);
        assert(claimableAfter >= 0);
    }

    function test_claim_after_start_pick_phase(uint8 phaseIndex) public {
        require(phaseIndex < phases.length);
        emit TestProggres("phaseIndex", phaseIndex);
        Phase memory currentPhase = phases[phaseIndex]; 
        emit TestProggres("currentPhase.endAt", currentPhase.endAt);
        emit TestProggres("currentPhase.rate", currentPhase.rate);
        emit TestProggres("currentPhase.minimumClaimablePeriod", currentPhase.minimumClaimablePeriod);
        emit TestProggres("block.timestamp", block.timestamp);

        uint256 phaseStartAt;
        if(phaseIndex == 0) {
            require(block.timestamp > vesting.startDateAt() + 1);
            phaseStartAt = vesting.startDateAt();
        } else {
            require(block.timestamp > phases[phaseIndex - 1].endAt + 1);
            phaseStartAt = phases[phaseIndex - 1].endAt;
        }
        require(block.timestamp < currentPhase.endAt);
        emit TestProggres("phaseStartAt", phaseStartAt);

        address sender = msg.sender;
        Vesting.UserVesting memory senderVestings = vesting.getUserVesting(sender);
        // require(senderVestings.amountClaimed == 0);
        require(senderVestings.init);
        
        emit TestProggres("senderVestings.amount", senderVestings.amount);
        uint256 claimable = vesting.claimable(sender);
        uint256 claimableCalc = _claimableLocal(senderVestings);
        emit TestProggres("claimable", claimable);
        emit TestProggres("calculatedAmountClaimable", claimableCalc);
        assert(claimable == claimableCalc);

        uint256 nextBatchAt = vesting.nextBatchAt();
        uint256 startDateAt = vesting.startDateAt();
        emit TestProggres("nextBatchAt", nextBatchAt);
        emit TestProggres("startDateAt", startDateAt);

        if(currentPhase.minimumClaimablePeriod == 0) {
            assert(nextBatchAt == currentPhase.endAt);
        } else if(currentPhase.minimumClaimablePeriod == 1) {
            assert(nextBatchAt == 1);
        } else {
            assert(nextBatchAt >= phaseStartAt);
            assert((nextBatchAt - phaseStartAt) % currentPhase.minimumClaimablePeriod == 0);
        }
        
        if(claimable > 0) {
            hevm.prank(sender);
            vesting.claim();

            Vesting.UserVesting memory senderVestingsAfter = vesting.getUserVesting(sender);
            logVesting(senderVestingsAfter, "senderVestingsAfter");

            uint256 claimableAfter = vesting.claimable(sender);
            emit TestProggres("claimableAfter", claimableAfter);

            assert(claimableAfter == 0);
            assert(senderVestingsAfter.lastClaimAt == block.timestamp);

        }

        // with this later in coverage report I want to be sure all of these values were covered at least once.
        if(phaseIndex == 0) {
            emit TestProggres("phaseIndex", phaseIndex);
        } else if(phaseIndex == 1) {
            emit TestProggres("phaseIndex", phaseIndex);
        } else if(phaseIndex == 2) {
            emit TestProggres("phaseIndex", phaseIndex);
        } else if(phaseIndex == 3) {
            emit TestProggres("phaseIndex", phaseIndex);
        } else if(phaseIndex == 4) {
            emit TestProggres("phaseIndex", phaseIndex);
        } else if(phaseIndex == 5) {
            emit TestProggres("phaseIndex", phaseIndex);
        }
    }

    function _claimableLocal(Vesting.UserVesting memory v) private view returns (uint256 amount) {
        uint256 startDateAt = vesting.startDateAt();
        uint256 vestingEndAt = vesting.vestingEndAt();
        uint256 claimableAtStart = vesting.claimableAtStart();

        if (vesting.refundMode() || v.requestedRefund) {
            // refundMode is on or user requested refund
            return 0;
        } else if (block.timestamp < startDateAt) {
            // vesting has not started
            return 0;
        }

        uint256 amountLeft = v.amount - v.amountClaimed;
        // user already claimed everything
        if (amountLeft == 0) return 0;

        if (block.timestamp >= vestingEndAt) {
            // if vesting ended return everything left
            amount = amountLeft;
        } else {
            if (v.lastClaimAt == 0) {
                // if this is first claim also calculate amount available at start
                amount += (claimableAtStart * v.amount) / vesting.BASIS_POINT_RATE_CONVERTER();
            }
            uint256 prevEndDate = startDateAt;
            for (uint256 i = 0; i < phases.length; i++) {
                Phase memory phase = phases[i];
                uint256 phaseLength = phase.endAt - prevEndDate;

                // if last claim time is larger than the end of phase then skip it, already calculated in previous claim
                if (v.lastClaimAt < phase.endAt) {
                    if (block.timestamp >= phase.endAt && phase.minimumClaimablePeriod == 0) {
                        // if phase completely passed then calculate amount with every second in phase
                        amount += (v.amount * phase.rate) / vesting.BASIS_POINT_RATE_CONVERTER();
                    } else if (phase.minimumClaimablePeriod != 0) {
                        uint256 start = Math.max(v.lastClaimAt, prevEndDate);
                        uint256 end = Math.min(block.timestamp, phase.endAt);

                        uint256 timePassed = end - start - ((end - start) % phase.minimumClaimablePeriod);
                        amount += (v.amount * phase.rate * timePassed) / (phaseLength * vesting.BASIS_POINT_RATE_CONVERTER());
                    }

                    if (block.timestamp < phase.endAt) {
                        // if current time is less than end of this phase then there is no need to calculate remaining phases
                        break;
                    }
                }
                prevEndDate = phase.endAt;
            }
        }

        return Math.min(amount, amountLeft);
    }

    function getPhaseForCurrentDate() private view returns (Phase memory phase, uint256 phaseIndex) {
        for (uint256 i = 0; i < phases.length; i++) {
            if(block.timestamp > phases[i].endAt) {
                phase = phases[i];
                phaseIndex = i;
            }
        }
    }

    function getTotalClaimRateForPhase(Vesting.UserVesting memory userVesting) private view returns (uint256 totalRate) {
        if (userVesting.lastClaimAt == 0) {
            totalRate = totalRate + vesting.claimableAtStart();
        }
        for (uint256 i = 0; i < phases.length; i++) {
            Phase memory phase = phases[i];
            if (userVesting.lastClaimAt < phase.endAt && block.timestamp >= phase.endAt && phase.minimumClaimablePeriod == 0) {
                totalRate = totalRate + phase.rate;
            }
        }
        
        return totalRate;
    }

    function logPhase(Phase memory phase, string memory prefixLog) private {
        emit TestProggres("###################", "###################");
        emit TestProggres("prefixLog", prefixLog);
        emit TestProggres("phase.rate", phase.rate);
        emit TestProggres("phase.endAt", phase.endAt);
        emit TestProggres("phase.minimumClaimablePeriod", phase.minimumClaimablePeriod);
        emit TestProggres("*************************", "*************************");
    }

    function logVesting(Vesting.UserVesting memory userVesting, string memory prefixLog) private {
        emit TestProggres("###################", "###################");
        emit TestProggres("prefixLog", prefixLog);
        emit TestProggres("userVesting.init", userVesting.init);
        emit TestProggres("userVesting.amount", userVesting.amount);
        emit TestProggres("userVesting.amountClaimed", userVesting.amountClaimed);
        emit TestProggres("userVesting.lastClaimAt", userVesting.lastClaimAt);
        emit TestProggres("*************************", "*************************");
    }
}