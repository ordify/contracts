// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct CreateVestingInput {
    address user;
    uint128 amount;
}

/**
 * @param rate percentage vested from total amount during the phase in BPS
 * @param endAt Time when phase ends
 * @param minimumClaimablePeriod for linear vesting it would be "1 seconds", for weekly westing it would be "1 weeks", if not set(set to zero) user will be able to claim only after phase ends
 */
struct Phase {
    uint32 rate;
    uint40 endAt;
    uint32 minimumClaimablePeriod;
}

/**
 * @title Vesting
 * @dev no user can claim while contract is in locked state
 * @dev Contract that is used for token vesting by some predefined schedule. It supports cases when part(percentage) of the token was already given
 * to users and rest will be claimed here. It supports many phases and cliff at the start. Also it supports vesting by block, which means user can vest every block some tokens, 
 * by percentage defined in phase percetage.
 * For time we are using uint40, which max number is 1099511627776, presented in seconds is more than suitable for our usage.
 */
contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @param amount Total amount allocated for user
     * @param amountClaimed Total amount claimed by user so far
     * @param lastClaimAt Timestamp from user last claim
     */
    struct UserVesting {
        uint40 lastClaimAt;
        bool init;
        // during refundGracePeriod (i.e. 1, 3 or 7 days after vesting starts, user can request refund if did not claim any tokens)
        // after refundGracePeriod expires, user will be then enabled refund on fundraise chain.
        bool requestedRefund;
        uint256 amount;
        uint256 amountClaimed;
    }

    uint128 public constant BASIS_POINT_RATE_CONVERTER = 10_000; // Basis Points(bps) 1% = 100bps
    uint256 public constant MAX_ALLOWED_PHASES = 30;

    string public name;

    bool public refundMode; 
    bool public requestedRefundWithdrawn;
    bool public refundWithdrawn;
    uint40 public startDateAt;
    uint40 public vestingEndAt;
    uint16 public claimableAtStart; // in BPS
    uint32  public refundGracePeriodDuration; // in seconds

    IERC20 public vestedToken;

    // when refund mode is on this means complete project will be refunded as terms has been nreached. 
    // i.e. price is bellow IDO Price after 48 hours, etc. 
    uint256 public totalAmountAllocated; // Amount owner allocated for all users
    uint256 public totalAmountClaimed; // Amount claimed by all users
    uint256 public totalAmountRefundRequested; // Amount reserved for refund, requested by users

    Phase[] public phases;
    mapping(address => UserVesting) public vestings;

    event NewVestingCreated(address indexed user, uint256 amount);
    event NewClaim(address indexed user, uint256 amountClaimed);
    event RefundRequested(address indexed user);
    event RefundRequestedPulledBack(address indexed user);
    event RefundRequestedWithdrawn(address indexed user, uint256 amount);
    event RefundForAllWithdrawn(address indexed user, uint256 amount);

    constructor(
        IERC20 _vestedToken,
        string memory _name,
        uint40 _startDateAt,
        uint16 _claimableAtStart,
        Phase[] memory _phases,
        uint32 _refundGracePeriodDuration
    ) payable Ownable() {
        _initialize(
            _vestedToken,
            _name,
            _startDateAt,
            _claimableAtStart,
            _phases,
            _refundGracePeriodDuration
        );
    }

    /**
     * @notice owner can reinitialize vesting schedule only if vesting did not started
     */
    function reinitialize(
        IERC20 _vestedToken,
        string memory _name,
        uint40 _startDateAt,
        uint16 _claimableAtStart,
        Phase[] memory _phases,
        uint32 _refundGracePeriodDuration
    ) external onlyOwner {
        require(totalAmountClaimed == 0, "claim already started");
 
        _initialize(
            _vestedToken,
            _name,
            _startDateAt,
            _claimableAtStart,
            _phases,
            _refundGracePeriodDuration
        );
    }

    /**
     * @notice this is to make vesting refundMode. This method is used if e.g we will refund launchpad but we need to return not vested tokens, we need to make it 
     * to stop vesting contract.
     */
    function setRefundMode(bool _refundMode) external onlyOwner {
        refundMode = _refundMode;
    }

    function getUserVesting(address _userAddress) public view returns (UserVesting memory) {
        return vestings[_userAddress];
    }

    /**
     * @notice create vesting for user, only one vesting per user address
     * @dev owner needs to first deploy enough tokens to vesting contract address
     */
    function createVestings(CreateVestingInput[] calldata vestingsInput, bool depositCheck) external onlyOwner {
        require(vestingsInput.length > 0, "vestingsInput empty");
        require(block.timestamp < startDateAt, "vesting started");

        uint256 totalDepositedAmount = getDepositedAmount();
        uint256 amountAllocated;

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            amountAllocated += vestingsInput[i].amount;
        }

        if (depositCheck) {
            uint256 totalTokenAvailable = totalDepositedAmount + totalAmountClaimed - totalAmountAllocated;
            require(totalTokenAvailable >= amountAllocated, "not enough token deposited");
        }

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            _createVesting(vestingsInput[i]);
        }
    }

    /**
     * @dev method which is used for claiming if any tokens are available for claim
     */
    function claim() external nonReentrant {
        require(!refundMode, "vesting is refunded");

        address user = _msgSender();
        UserVesting storage vesting = vestings[user];
        require(!vesting.requestedRefund, "user req refund");

        require(vesting.init, "user is not participating");
        require(vesting.amount - vesting.amountClaimed > 0, "all amount claimed");
        
        uint256 claimableAmount = _claimable(vesting);
        require(getDepositedAmount() >= claimableAmount, "not enough token deposited for claim");

        require(claimableAmount > 0, "nothing to claim currently");

        totalAmountClaimed += claimableAmount;
        vesting.amountClaimed += claimableAmount;
        vesting.lastClaimAt = uint40(block.timestamp);

        assert(vesting.amountClaimed <= vesting.amount);
        assert(totalAmountClaimed <= totalAmountAllocated);

        vestedToken.safeTransfer(user, claimableAmount);
        emit NewClaim(user, claimableAmount);
    }

    /**
     * @dev return amount user can claim from locked tokens at the moment
     */
    function claimable(address _user) external view returns (uint256 amount) {
        if (refundMode) {
            return 0;
        }

        amount = _claimable(vestings[_user]);
    }

    function getDepositedAmount() public view returns (uint256 amount) {
        amount = vestedToken.balanceOf(address(this));
    }

    /**
     * @dev method which is used for user to request refund
     */
    function requestRefund() external nonReentrant {
        address user = _msgSender();
        UserVesting storage vesting = vestings[user];

        require(vesting.init, "user is not participating");
        require(vesting.amountClaimed == 0, "user already claimed");
        require(block.timestamp <= (startDateAt + refundGracePeriodDuration), "refund period passed");

        vesting.requestedRefund = true;
        totalAmountRefundRequested += vesting.amount;
        totalAmountAllocated -= vesting.amount;
        
        emit RefundRequested(user);
    }

    /**
     * @dev method which is used for user to request refund
     */
    function pullBackRequestRefund() external nonReentrant {
        address user = _msgSender();
        UserVesting storage vesting = vestings[user];

        require(vesting.init, "user is not participating");
        require(vesting.amountClaimed == 0, "user already claimed");
        require(vesting.requestedRefund, "nothin to pull back");
        require(block.timestamp <= (startDateAt + refundGracePeriodDuration), "refund period passed");
        
        vesting.requestedRefund = false;
        totalAmountRefundRequested -= vesting.amount;
        totalAmountAllocated += vesting.amount;

        emit RefundRequestedPulledBack(user);
    }

    /**
     * @dev Returns time until next vesting batch will be unlocked for vesting contract provided in arguments
     * in case of linear vesting (or next block vesting) it is returned 1, which for the caller indicates it will be next block
     * for other use cases it is returned time when next phase will be available
     */
    function nextBatchAt() external view returns (uint256) {
        if (block.timestamp >= vestingEndAt) {
            return vestingEndAt;
        }

        // we assume all vesting contracts release at least some funds on start date/TGE
        if (block.timestamp < startDateAt) {
            return startDateAt;
        }

        uint256 nextBatchIn;
        uint256 prevEndDate = startDateAt;
        
        // iterate over phases until we find current phase contract does not returns phases length
        for (uint256 i = 0; block.timestamp > prevEndDate; i++) {
            Phase memory phase = phases[i];
            if (block.timestamp <= phase.endAt) {
                // vesting per sec/block
                if (phase.minimumClaimablePeriod == 1) {
                    nextBatchIn = 1;
                } else if (phase.minimumClaimablePeriod == 0) {
                    // vested at the end of the phase
                    nextBatchIn = phase.endAt;
                } else {
                    // if the funds are released in batches in current phase every `minimumClaimablePeriod` time,
                    nextBatchIn = block.timestamp + phase.minimumClaimablePeriod - ((block.timestamp - prevEndDate) % phase.minimumClaimablePeriod);
                }
                break;
            }
            
            prevEndDate = phase.endAt;
        }

        return nextBatchIn;
    }

    /**
     * @dev rescue any token accidentally sent to this contract
     */
    function emergencyWithdrawToken(IERC20 token) external onlyOwner {
        require(token != vestedToken, "must not be vestedToken");

        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    /**
     * @dev withdraw toknes which requested refund. These tokens will be returned to the project and user will be enabled refund on fundraiseChain
     */
    function withdrawRequestRefundToken() external onlyOwner {
        require(!requestedRefundWithdrawn, "already withdrawn");
        require(startDateAt + refundGracePeriodDuration > block.timestamp, "refund period active");
        uint256 vestedbalance = vestedToken.balanceOf(address(this));
        require(vestedbalance >= totalAmountRefundRequested, "refund period active");

        requestedRefundWithdrawn = true;
        vestedToken.safeTransfer(msg.sender, totalAmountRefundRequested);

        emit RefundRequestedWithdrawn(msg.sender, totalAmountRefundRequested);
    }

    /**
     * @dev withdraw refund tokens. These tokens will be returned to project and user will be enabled refund on fundraiseChain
     */
    function withdrawRefundForAll() external onlyOwner {
        require(!refundWithdrawn, "already withdrawn");
        require(refundMode, "refund mode is off");

        refundWithdrawn = true;
        vestedToken.safeTransfer(msg.sender, vestedToken.balanceOf(address(this)));

        emit RefundForAllWithdrawn(msg.sender, totalAmountRefundRequested);
    }

    function _initialize(
        IERC20 _vestedToken,
        string memory _name,
        uint40 _startDateAt,
        uint16 _claimableAtStart,
        Phase[] memory _phases,
        uint32 _refundGracePeriodDuration
    ) private {
        require(_phases.length <= MAX_ALLOWED_PHASES, "phases size exceeds max allowed");

        uint256 prevStartDate = _startDateAt;
        uint256 total = _claimableAtStart;
        for (uint256 i = 0; i < _phases.length; i++) {
            Phase memory phase = _phases[i];

            require(phase.endAt > prevStartDate, "phases not ordered");
            
            total += phase.rate;
            prevStartDate = phase.endAt;
        }

        require(total == BASIS_POINT_RATE_CONVERTER, "total == 10000");
        require(address(_vestedToken) != address(0), "vesttedToken address is zero");
        
        name = _name;
        vestedToken = _vestedToken;
        startDateAt = _startDateAt;
        // set vesting end date to last phase end date, if there is not phases then set end date to start date(e.g. for 100% claim at TGE)
        vestingEndAt = _phases.length > 0
            ? _phases[_phases.length - 1].endAt
            : _startDateAt;
        claimableAtStart = _claimableAtStart;
        // clear the phases array in case of reinitialization
        delete phases;
        for (uint256 i = 0; i < _phases.length; i++) {
            phases.push(_phases[i]);
        }

        refundGracePeriodDuration = _refundGracePeriodDuration;
    }

    /**
     * @dev create vesting for an user
     */
    function _createVesting(CreateVestingInput memory v) private {
        require(v.user != address(0), "user address is zero");
        require(v.amount > 0, "amount is zero");
        require(vestings[v.user].amount == 0, "one vesting per addr");

        totalAmountAllocated += v.amount;

        vestings[v.user] = UserVesting({
            init: true,
            amount: v.amount,
            amountClaimed: 0,
            lastClaimAt: 0,
            requestedRefund: false
        });

        emit NewVestingCreated(v.user, v.amount);
    }

    /**
     * @dev claimable amount available at the time function is called
     */
    function _claimable(UserVesting memory v) private view returns (uint256 amount) {
        if (refundMode || v.requestedRefund) {
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
                amount += (claimableAtStart * v.amount) / BASIS_POINT_RATE_CONVERTER;
            }
            uint256 prevEndDate = startDateAt;
            for (uint256 i = 0; i < phases.length; i++) {
                Phase memory phase = phases[i];
                uint40 phaseLength = uint40(phase.endAt - prevEndDate);

                // if last claim time is larger than the end of phase then skip it, already calculated in previous claim
                if (v.lastClaimAt < phase.endAt) {
                    if (block.timestamp >= phase.endAt && phase.minimumClaimablePeriod == 0) {
                        // if phase completely passed then calculate amount with every second in phase
                        amount += (v.amount * phase.rate) / BASIS_POINT_RATE_CONVERTER;
                    } else if (phase.minimumClaimablePeriod != 0) {
                        uint40 start = uint40(max(v.lastClaimAt, prevEndDate));
                        uint40 end = uint40(min(block.timestamp, phase.endAt));

                        // only take full increments of minimumClaimablePeriod in calculation of amount. 
                        // e.g. if end (current block.timestamp) is at 170, and start is at 100,  and if minimumClaimable perios is 20s. 
                        // then we have following: end - start = 170 - 100 = 70, and of that 70 we can only take in calculation 60 seconds, only full amount of claimable period.
                        // timePassed = 170 - 100 - ((170 - 100) % 20) = 70 - (70 % 20) = 70 - 10 = 60
                        uint40 timePassed = end - start - ((end - start) % phase.minimumClaimablePeriod);

                        amount += (v.amount * phase.rate * timePassed) / (phaseLength * BASIS_POINT_RATE_CONVERTER);
                    }

                    if (block.timestamp < phase.endAt) {
                        // if current time is less than end of this phase then there is no need to calculate remaining phases
                        break;
                    }
                }
                prevEndDate = phase.endAt;
            }
        }

        return min(amount, amountLeft);
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
