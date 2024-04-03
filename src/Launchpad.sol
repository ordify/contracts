// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

struct UserDetails {
    uint32 refundedAt;
    uint256 contributedRound1;
    uint256 contributedRound2;
    uint256 refundedAmount;
}

/**
 * @title Launchpad - raise funds for IDO
 * @notice 4 rounds : 0 = not open, 1 = guaranteed tier round, 2 = fcfs, 3 = sale finished
 * @dev For time we are using uint32, which max number is 4294967296, and that in seconds is following date: Sunday, February 7, 2106 6:28:16 AM. 82 years from now.
    Which is suitable for our usage.
 */
contract Launchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    uint256 public constant BASIS_POINT_RATE_CONVERTER = 10_000; // Basis Points(bps) 1% = 100bps

    uint32 public saleStartDate;
    uint32 public round1Duration;
    bool public endUnlocked;
    bool public globalRefundEnabled;
    bool ownerRefundExecuted;
    uint16 public refundPercentage;
    
    uint256 public immutable stableTarget;
    address public immutable verifyingAddressECDSA; // public address of off chain signer
    uint256 public stableRaised;
    IERC20 public immutable stablecoin;
    mapping(address => UserDetails) public userDetails;
    address[] public participants;

    event SaleWillStart(uint256 startTimestamp);
    event SaleEnded(uint256 endTimestamp);
    event PoolProgress(uint256 stableRaised, uint256 stableTarget);
    event Round2MultiplierChanged(uint16 round2Multiplier);
    event Refunded(address indexed user, uint256 refundAmount);
    event Round1Duration(uint256 duration);

    modifier atRound(uint8 requiredRound) {
        uint8 currentRound = roundNumber();
        require(currentRound == requiredRound, "invalid round");
        _;
    }

    modifier hasStableAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        uint256 ourAllowance = stablecoin.allowance(allower, address(this));
        require(ourAllowance >= amount, "allowance too low");

        _;
    }

    /**
     *  @param _verifyingAddressECDSA public key for ECDSA verfication of off chain signatures
     *  @param _stableTarget amount of stable tokens we are targeting to raise
     *  @param _saleStartDate start of the sale
     *  @param _stableCoinAddress stable coin contract address
     */
    constructor(
        address _verifyingAddressECDSA,
        uint256 _stableTarget,
        uint32 _saleStartDate,
        IERC20 _stableCoinAddress,
        uint32 _round1Duration
    ) payable Ownable() {
        require(_verifyingAddressECDSA != address(0), "_verifyingAddressECDSA is 0");
        require(_stableTarget > 0, "_stableTarget is zero");
        require(address(_stableCoinAddress) != address(0), "stableCoin == address(0)");
        require(_round1Duration > 0, "_round1Duration is zero");

        verifyingAddressECDSA = _verifyingAddressECDSA;
        round1Duration = _round1Duration;
        stableTarget = _stableTarget;
        saleStartDate = _saleStartDate;
        stablecoin = _stableCoinAddress;
        refundPercentage = 10_000; // 10000bps = 100% initial
    }

    /**
     * @dev method that is used to refund investment for users when refund is enabled.
     * Refund percentage needs to be set, `refundPercentage` > 0
     * Refund needs to be enabled. `globalRefundEnabled` = true or user should have signature of requested refund, generated and signed off chain
     * Launchpad needs to end. `endUnlocked` = true
     * @param signature used to check if user is valid for requested signature, send empy if not needed in case of global refund for all users
    */
    function refund(bytes calldata signature) nonReentrant public {
        require(endUnlocked, "Sale not marked as ended");
        address user = _msgSender();  

        require(refundPercentage > 0, "Refund percentage is 0");
        UserDetails storage userDetailsRecord = userDetails[user];
        
        require(userDetailsRecord.contributedRound1 > 0 || userDetailsRecord.contributedRound2 > 0, "Not participated");
        require(userDetailsRecord.refundedAmount == 0, "Already refunded");

        if(!globalRefundEnabled) {
            bytes32 signedMessageHash = keccak256(abi.encode(address(this), user)).toEthSignedMessageHash();
            (address recoveredSigner, ) = signedMessageHash.tryRecover(signature);
            require(recoveredSigner == verifyingAddressECDSA, "invalid signature for req refund");
        } else {
            require(globalRefundEnabled, "Refund not enabled");
        }

        uint256 userRefoundAmount = calculateRefund(user, signature);
        uint256 userContribution = userDetailsRecord.contributedRound1 + userDetailsRecord.contributedRound2;
        require(userRefoundAmount <= userContribution, "Refund to big");

        userDetailsRecord.refundedAmount = userRefoundAmount;
        userDetailsRecord.refundedAt = uint32(block.timestamp);

        stablecoin.safeTransfer(user, userRefoundAmount);
        emit Refunded(user, userRefoundAmount);
    }

    /**
     * @dev method is used to calculate available refund for provided user address
     * @param user user address that will be used for refund calculation
     * @param signature used to check if user is valid for requested signature, send empy if not needed in case of global refund for all users
     */
    function calculateRefund(address user, bytes calldata signature) public view returns (uint256 userRefoundAmount) {
        UserDetails memory userDetailsRecord = userDetails[user];

        bytes32 signedMessageHash = keccak256(abi.encode(address(this), user)).toEthSignedMessageHash();
        (address recoveredSigner, ) = signedMessageHash.tryRecover(signature);

        if(
            !endUnlocked 
            || refundPercentage == 0 
            || !(globalRefundEnabled || recoveredSigner == verifyingAddressECDSA)
            || userDetailsRecord.refundedAmount > 0 
            || !(userDetailsRecord.contributedRound1 > 0 || userDetailsRecord.contributedRound2 > 0)
        ) {
            return 0;
        }

        uint256 userContributed = userDetailsRecord.contributedRound1 + userDetailsRecord.contributedRound2;

        uint256 refundCalculationDividend = userContributed * refundPercentage;
        userRefoundAmount = refundCalculationDividend / (BASIS_POINT_RATE_CONVERTER);
    }

    /**
     * @dev method is used to get round1 contribution for user
     * @param user user address
     */
    function contributedRound1(address user) public view returns (uint256 amount) {
        amount = userDetails[user].contributedRound1;
    }

     /**
     * @dev method is used to get round2 contribution for user
     * @param user user address
     */
    function contributedRound2(address user) public view returns (uint256 amount) {
        amount = userDetails[user].contributedRound2;
    }

    /**
     * @dev method is used to get amount which is refunded for user
     * @param user user address that will be used for check refunded amount
     */
    function getUserRefundedAmount(address user) public view returns (uint256 userRefoundedAmount) {
        userRefoundedAmount =  userDetails[user].refundedAmount;
    }

    /**
     * @dev method is used to set active/deactive refund functionality
     * @param _globalRefundEnabled refundEnabled flag
     */
    function setGlobalRefundEnabled(bool _globalRefundEnabled) external onlyOwner {
        globalRefundEnabled = _globalRefundEnabled;
    }

    /**
     * @dev method is used to set refund percentage
     * @param _refundPercentage refund percentage. Must be bigger than 0 and less or equal 10000. 
     */
    function setRefundPercentage(uint16 _refundPercentage) external onlyOwner {
        require(_refundPercentage <= 10000, "Refund perc. greater than 10000");
        require(_refundPercentage > 0, "Refund perc. is 0");

        refundPercentage = _refundPercentage;
    }

    /**
     * @dev method is used to set prepare contract for refund state where all users will be available for refund.
     * @param _refundPercentage refund percentage. Must be bigger than 0 and less or equal 10000. 
     */
    function prepareForGlobalRefund(uint16 _refundPercentage) external onlyOwner {
        require(_refundPercentage <= 10000, "Refund perc. greater than 10000");
        require(_refundPercentage > 0, "Refund perc. is 0");

        refundPercentage = _refundPercentage;
        globalRefundEnabled = true;
        endUnlocked = true;
    }

    /**
     * @dev method is used to set sale start date
     * @param _saleStartDate sale start date. Must be in future and sale is not yet started
     */
    function setSaleStartDate(uint32 _saleStartDate) external onlyOwner atRound(0) {
        require(block.timestamp < _saleStartDate, "saleDate in past");

        saleStartDate = _saleStartDate;

        emit SaleWillStart(_saleStartDate);
    }

    /**
     * @dev method is used to set sale start date
     * @param _round1Duration sale start date. Must be in future and sale is not yet started
     */
    function setRound1Duration(uint32 _round1Duration) external onlyOwner atRound(0) {
        require(_round1Duration > 0, "_round1Duration is zero");
        require(!endUnlocked, "sale has ended");
        require(participants.length == 0, "sale has started");

        round1Duration = _round1Duration;

        emit Round1Duration(round1Duration);
    }

    /**
     * @dev method used to mark sale as finished
    */
    function finishSale() external onlyOwner {
        require(!endUnlocked, "sale already ended");

        endUnlocked = true;
        emit SaleEnded(block.timestamp);
    }

    /**
     * @dev method used to collect stable token raised after sale has ended
    */
    function withdrawStable() external onlyOwner {
        require(endUnlocked, "sale not ended");

        stablecoin.safeTransfer(
            _msgSender(),
            stablecoin.balanceOf(address(this))
        );
    }

    /**
     * @dev method used to refund stable token after refund is activated. Only part of refund is available. 10000 - refundPercentage
    */
    function withdrawStableRefund() external onlyOwner {
        require(endUnlocked, "sale not ended");

        require(!ownerRefundExecuted, "Alredy refunded to owner");
        
        ownerRefundExecuted = true;
        
        uint256 ownerRefundPercentage = 10000 - refundPercentage;

        uint256 refundCalculationDividend = stableRaised * ownerRefundPercentage;
        uint256 amountToWithdraw = refundCalculationDividend / (BASIS_POINT_RATE_CONVERTER);

        require(amountToWithdraw <= stableRaised, "Refund withdraw too big.");
        require(amountToWithdraw > 0, "Refund withdraw must bigger > 0");

        stablecoin.safeTransfer(
            _msgSender(),
            amountToWithdraw
        );
    }

    /**
     * @dev method used to get user contribution. It is returning stable token invested and token amoun that will receive once vesting starts
     * @param user user address
    */
    function getUserContribution(address user) external view returns (uint256 contributedStable) {
        UserDetails memory userDetailsRecord = userDetails[user];

        contributedStable = userDetailsRecord.contributedRound1 + userDetailsRecord.contributedRound2;
    }

    /**
     * @dev method used to get user details by address
     * @param user user address
    */
    function getUserDetails(address user) external view returns (UserDetails memory userDetail) {
        userDetail = userDetails[user];
    }

    /**
     * @dev rescue any token accidentally sent to this contract
     * @param token address of IREC20 token
    */
    function emergencyWithdrawToken(IERC20 token) external onlyOwner atRound(3) {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    /**
     * @dev participate in round1. User can invest up to amount whitelisted for sale.
     * @param stableAmount amount to buy
     * @param signature ECDSA signature. signed using following concatenated payload (user,whitelistAmount).
     * @param amountRound1 amount which is guaranteed for user in round1
     * @param amountRound2 amount which allowed for user to buy in FCFS round
     * @notice for of chain sginature privateKey of verifyingAddressECDSA has been used.
    */
    function buyRound1(uint256 stableAmount, bytes calldata signature, uint256 amountRound1, uint256 amountRound2) external nonReentrant atRound(1) hasStableAllowance(_msgSender(), stableAmount) {
        address user = _msgSender();

        _checkWhitelistSignature(signature, user, amountRound1, amountRound2);

        uint256 allowance = _round1Allowance(user, amountRound1);

        _checkAllowance(allowance, stableAmount);

        _registerParticipation(user);

        userDetails[user].contributedRound1 += stableAmount;

        _buy(stableAmount);
    }

    /**
     * @dev participate in round2 (FCFS). User can invest up to amountRound2 which is signed off chain. round2 allowance will be 
     * product of round2Multiplier and round1 allowance for smallest tier and weight of user tier.
     * @param stableAmount amount to buy
     * @param signature ECDSA signature. signed using following concatenated payload (user,whitelistAmount).
     * @param amountRound1 amount which is guaranteed for user in round1
     * @param amountRound2 amount which allowed for user to buy in FCFS round
     * @notice for of chain sginature privateKey of verifyingAddressECDSA has been used.
    */
    function buyRound2(uint256 stableAmount, bytes calldata signature, uint256 amountRound1, uint256 amountRound2) external nonReentrant atRound(2) hasStableAllowance(_msgSender(), stableAmount) {
        address user = _msgSender();

        _checkWhitelistSignature(signature, user, amountRound1, amountRound2);

        uint256 allowance = _round2Allowance(user, amountRound2);

        _checkAllowance(allowance, stableAmount);

        _registerParticipation(user);

        userDetails[user].contributedRound2 += stableAmount;

        _buy(stableAmount);
    }

    /**
     * @dev returns current round calculated, depnding on state of contract
    */
    function roundNumber() public view returns (uint8 _roundNumber) {
        if (endUnlocked) return 3;

        if (block.timestamp < saleStartDate || saleStartDate == 0) {
            return 0;
        }

        if (block.timestamp >= saleStartDate && block.timestamp < saleStartDate + round1Duration) {
            return 1;
        }

        if (block.timestamp >= (saleStartDate + round1Duration)) {
            return 2;
        }
    }

    /**
     * @dev returns number of participatns
    */
    function getNumberOfParticipants() public view returns (uint256) {
        return participants.length;
    }

    /**
     * @dev returns round1 allowance
     * @param user user address
     * @param signature ECDSA signature. signed using following concatenated payload (user,whitelistAmount).
     * @param amountRound1 amount which is guaranteed for user in round1
     * @param amountRound2 amount which allowed for user to buy in FCFS round
     * @notice for of chain sginature privateKey of verifyingAddressECDSA has been used.
    */
    function round1Allowance(address user, bytes calldata signature, uint256 amountRound1, uint256 amountRound2) public view returns (uint256 allowance)  {
        _checkWhitelistSignature(signature, user, amountRound1, amountRound2);
        allowance = _round1Allowance(user, amountRound1);
    }

    /**
     * @dev returns round2 allowance
     * @param user user address
     * @param signature ECDSA signature. signed using following concatenated payload (user,whitelistAmount).
     * @param amountRound1 amount which is guaranteed for user in round1
     * @param amountRound2 amount which allowed for user to buy in FCFS round
     * @notice for of chain sginature privateKey of verifyingAddressECDSA has been used.
    */
    function round2Allowance(address user, bytes calldata signature, uint256 amountRound1, uint256 amountRound2) public view returns (uint256 allowance) {
        _checkWhitelistSignature(signature, user, amountRound1, amountRound2);
        
        allowance = _round2Allowance(user, amountRound2);
    }

    function _checkAllowance(uint256 allowance, uint256 amount) private pure {
        require(allowance > 0, "invlaid allowance");
        require(allowance >= amount, "amount bigger than allowance");
    }

    function _buy(uint256 stableAmount) private {
        require(stableAmount > 0, "stableAmount is 0");

        stableRaised += stableAmount;
        require(stableTarget >= stableRaised, "soldout");

        uint256 balanceBefore = stablecoin.balanceOf(address(this));
        stablecoin.safeTransferFrom(_msgSender(), address(this), stableAmount);
        uint256 balanceAfter = stablecoin.balanceOf(address(this));
        uint256 tokensReceived = balanceAfter - balanceBefore;
        require(stableAmount == tokensReceived, "less than stableAmount transfered");
        
        emit PoolProgress(stableRaised, stableTarget);

        if (stableRaised == stableTarget) {
            endUnlocked = true;
            emit SaleEnded(block.timestamp);
        }
    }

    function _registerParticipation(address user) private {
        UserDetails storage userDetailsRecord = userDetails[user];
        if (userDetailsRecord.contributedRound1 == 0 && userDetailsRecord.contributedRound2 == 0) {
            participants.push(user);
        }
    }

   function _round1Allowance(address user, uint256 whitelistedAmount) private view returns (uint256 allowance) {
        UserDetails memory userDetailsRecord = userDetails[user];

        allowance = whitelistedAmount - userDetailsRecord.contributedRound1;
    }


    function _round2Allowance(address user, uint256 whitelistedAmount) private view returns (uint256 allowance) {
        UserDetails memory userDetailsRecord = userDetails[user];

        allowance = whitelistedAmount - userDetailsRecord.contributedRound2;
    }

    function _checkWhitelistSignature(bytes calldata signature, address user, uint256 amountRound1, uint256 amountRound2) private view {
        bytes32 signedMessageHash = keccak256(abi.encode(address(this), user, amountRound1, amountRound2)).toEthSignedMessageHash();
        require(
            signedMessageHash.recover(signature) == verifyingAddressECDSA,
            "signature not valid"
        );
    }
}