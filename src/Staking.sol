// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 *  @dev Structs to store user staking data.
 */
struct Deposit {
    uint8 stakingDefinitionId;
    uint8 status; // [DEPOSIT_STATUS_NOT_STAKING, DEPOSIT_STATUS_STAKING, DEPOSIT_STATUS_STAKING_WITHDRAWN]
    uint32 rate;
    uint32 withdrawFeePercentage;
    uint64 depositTime;
    uint64 endTime;
    uint64 rewardClaimedTime;
    uint256 depositAmount;
}

/**
 *  @dev Struct to store staking definition basic information
 */
struct StakingDefinition {
    uint8 uniqueIdentifier;
    bool enabled;
    uint32 rate;
    uint64 withdrawFeeUpdateOn;
    uint32 lockDuration; // in seconds
    bool exists;
    uint32 globalWithdrawFeePercentage;
    bool globalWithdrawFeePercentageEnabled;
    uint32 numberOfActiveStakings;
    uint32 withdrawFeePercentage;
    uint32 poolMultiplier;
    string name;    
}

/**
 *  @dev Struct to create staking definitions
 */
struct StakingDefinitionCreate {
    uint32 rate;
    uint32 withdrawFeePercentage;
    uint32 lockDuration; // in seconds
    uint32 poolMultiplier;
    string name;    
}

/**
 * @dev Struct to get withdrawFeeState
*/
struct WithdrawFeeState {
    uint8 stakingDefinitionId;
    uint32 globalFee;
    bool globalFeeEnabled;
    uint32 depositRecordedFee;
    uint8 depositStatus;
    uint32 withdrawFeeUsed;
}

/**
 * @title Staking - stake tokens and earn rewards based on defined staking defintions
 * @dev Owner can define up to 30 staking definitions, that number is big, real use cases will have up to 10. 
 * Users can stake their tokens by choosing one of staking definitions which have defined lockDuration, prematured withdraw fee and rewarde yearly rate.
 */
contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant DEPOSIT_STATUS_NOT_STAKING = 0;
    uint8 public constant DEPOSIT_STATUS_STAKING = 1;
    uint8 public constant DEPOSIT_STATUS_STAKING_WITHDRAWN = 2;
    uint256 public constant YEAR_IN_SECONDS = 31536000;
    uint256 public constant BASIS_POINT_RATE_CONVERTER = 10_000; // Basis Points(bps) 1% = 100bps
    uint8 public constant MAX_STAKING_DEFINITIONS_SIZE = 30;

    bool public isStopped;
    // if premature withdraw is enabled. If true (default) user will be able to withdraw staked amount but with penalty calculated. 
    // if this is set to false user will not be able to withdraw before deposit.endTime is reached. User will be obly able to collect reward.
    bool public prematureWithdrawEnabled;
    uint8 public totalStakingDefinitions;
    address public treasury;
    IERC20 public tokenAddress;
    
    uint256 public stakedBalance;
    uint256 public rewardBalance;
    uint256 public totalActiveStakings;

    mapping(address => mapping(uint8 => Deposit)) private deposits;
    mapping(uint8 => StakingDefinition) private stakingDefinitions;
    /**
     *  @notice Emitted when user stakes new value of tokens
     */
    event Staked(address indexed staker, uint8 indexed stakeDefinition, uint64 indexed endTime, uint256 stakedAmount);

    /**
     *  @notice Emitted when user withdraws his deposit
     */
    event PaidOut(address indexed staker, uint256 amount, uint256 reward);

    /**
     *  @notice Emitted when user collects reward
     */
    event RewardCollected(address indexed staker, uint256 reward);

    /**
     *  @notice Emitted when rate is changed
     */
    event RateChanged(uint32 newRate);

    /**
     *  @notice Emitted when lock duration is changed
     */
    event LockDurationChanged(uint32 lockDuration);

    /**
     *  @notice Emitted when new amount of rewards is added to contract
     */
    event RewardsAdded(uint256 amount, uint256 time);

    /**
     *  @notice Emitted when contract is paused/unpaused
     */
    event IsStoppedChanged(bool isStopped, uint256 time);

    /**
     *  @notice Emitted when contract is paused/unpaused
     */
    event PrematureWithdrawFlagUpdated(bool prematureWithdrawEnabled, uint256 time);

    /**
     *  @notice Emitted when owner changes withdraw fee
     */
    event WithdrawFeeChanged(uint8 indexed stakingDefinitionId, uint32 newFee);

    /**
     *  @notice Emitted when owner changes pool multiplier
     */
    event PoolMultiplierChanged(uint8 indexed stakingDefinitionId, uint32 poolMultiplier);

    /**
     *  @notice Emitted when owner changes global withdraw fee
     */
    event GlobalWithdrawFeeSet(uint8 indexed stakingDefinitionId, uint32 newFee);

    /**
     *  @notice Emitted when owner removes global withdraw fee
     */
    event GlobalWithdrawFeeRemoved(uint8 indexed stakingDefinitionId);

    /**
     *  @notice Emitted when owner enables staking definition
     */
    event StakingDefinitionEnabled(uint8 indexed stakingDefinitionId);

    /**
     *  @notice Emitted when owner disables staking definition
     */
    event StakingDefinitionDisabled(uint8 indexed stakingDefinitionId);

    event StakingDefinitionAdded(uint8 indexed stakingDefinitionId);

    modifier withdrawCheck(uint8 stakingDefinitionId, address from) {
        Deposit memory userDeposit = deposits[from][stakingDefinitionId];
        require(userDeposit.status == DEPOSIT_STATUS_STAKING, "no active staking for stakingId");
        _;
    }

    modifier hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        uint256 ourAllowance = tokenAddress.allowance(allower, address(this));
        require(ourAllowance >= amount, "allowance too low");

        _;
    }

    /**
     *  @param _stakingDefinitions definition of different stakings which user can choose
     *  @param _tokenAddress contract address of the token
     */
    constructor(
        StakingDefinitionCreate[] memory _stakingDefinitions,
        address _tokenAddress,
        address _treasury,
        bool _prematureWithdrawEnabled
    ) Ownable() {
        require(address(_tokenAddress) != address(0), "token address is 0");
        require(address(_treasury) != address(0), "treasury address is 0");
        require(_stakingDefinitions.length <= MAX_STAKING_DEFINITIONS_SIZE, "too many staking defs");

        for (uint256 i = 0; i < _stakingDefinitions.length; i++) {
            StakingDefinitionCreate memory _stakingDefinition = _stakingDefinitions[i];

            // max fe is 50% or 5000 bps
            require(_stakingDefinition.withdrawFeePercentage <= 5000, "withdraw perct too big");
            require(_stakingDefinition.rate <= BASIS_POINT_RATE_CONVERTER, "rate too big");
            // 10_000 is referring to multiplier 1 in basis points. Min poool multiplier is 1
            require(_stakingDefinition.poolMultiplier >= 10000, "poolMultiplier < 10000");
            
            uint8 uqIdentifier = uint8(i);
            stakingDefinitions[uqIdentifier] = StakingDefinition({
                uniqueIdentifier: uqIdentifier,
                enabled: true,
                rate: _stakingDefinition.rate,
                withdrawFeePercentage: _stakingDefinition.withdrawFeePercentage,
                withdrawFeeUpdateOn: uint64(block.timestamp),
                lockDuration: _stakingDefinition.lockDuration,
                exists: true,
                globalWithdrawFeePercentage: 0,
                globalWithdrawFeePercentageEnabled: false,
                numberOfActiveStakings: 0,
                poolMultiplier: _stakingDefinition.poolMultiplier,
                name: _stakingDefinition.name
            });

            totalStakingDefinitions++;
        }
        assert(_stakingDefinitions.length == totalStakingDefinitions);

        tokenAddress = IERC20(_tokenAddress);
        treasury = _treasury;
        prematureWithdrawEnabled = _prematureWithdrawEnabled;
    }

    /**
     *  @notice only owner can add new staking definition
     *  @param _stakingDefinition staking definition to add
     */
    function addStakingDefinition(StakingDefinitionCreate memory _stakingDefinition) external onlyOwner {
        require(totalStakingDefinitions < MAX_STAKING_DEFINITIONS_SIZE, "too many staking defs");

        require(_stakingDefinition.withdrawFeePercentage <= 5000, "withdraw perct too big");
        require(_stakingDefinition.rate <= BASIS_POINT_RATE_CONVERTER, "rate too big");
        // 10_000 is referring to multiplier 1 in basis points. Min poool multiplier is 1
        require(_stakingDefinition.poolMultiplier >= 10000, "poolMultiplier < 10000");
            
        uint8 uqIdentifier = totalStakingDefinitions;
        stakingDefinitions[uqIdentifier] = StakingDefinition({
            uniqueIdentifier: uqIdentifier,
            enabled: true,
            rate: _stakingDefinition.rate,
            withdrawFeePercentage: _stakingDefinition.withdrawFeePercentage,
            withdrawFeeUpdateOn: uint64(block.timestamp),
            lockDuration: _stakingDefinition.lockDuration,
            exists: true,
            globalWithdrawFeePercentage: 0,
            globalWithdrawFeePercentageEnabled: false,
            numberOfActiveStakings: 0,
            poolMultiplier: _stakingDefinition.poolMultiplier,
            name: _stakingDefinition.name
        });

        totalStakingDefinitions++;

        emit StakingDefinitionAdded(uqIdentifier);
    }

    /**
     *  @notice only owner can add custom withdraw fee for user to override one form deposit struct
     *  @param _stakingDefinitionId staking definitionId
     *  @param _feePercentage withdraw fee percentage
     */
    function setGlobalWithdrawFeeForStakingDefinition(uint8 _stakingDefinitionId, uint32 _feePercentage) external onlyOwner {
        require(_stakingDefinitionId < totalStakingDefinitions, "_stakingDefinitionId not exist");
        require(_feePercentage <= 5000, "percentage too big");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        stakingDefinition.globalWithdrawFeePercentage = _feePercentage;
        stakingDefinition.globalWithdrawFeePercentageEnabled = true;

        emit GlobalWithdrawFeeSet(_stakingDefinitionId, _feePercentage);
    }

    /**
     *  @notice only owner can remove custom withdraw fee for user
     *  @param _stakingDefinitionId staking definitionId
     */
    function removeGlobalWithdrawFeeForStakingDefinition(uint8 _stakingDefinitionId) external onlyOwner {
        require(_stakingDefinitionId < totalStakingDefinitions, "_stakingDefinitionId not exist");
        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        stakingDefinition.globalWithdrawFeePercentage = 1; //cheaper to set it to non zero. On addGlobalWithdrawFeeForStakingDefinition will be overwritten
        stakingDefinition.globalWithdrawFeePercentageEnabled = false;

        emit GlobalWithdrawFeeRemoved(_stakingDefinitionId);
    }

    /**
     *  @notice only owner can change current withdraw fee for stakers
     *  @param _stakingDefinitionId staking definition id
     *  @param _percentage withdraw fee percentage
     */
    function setWithdrawFee(uint8 _stakingDefinitionId, uint32 _percentage) external onlyOwner {
        require(_percentage <= 5000, "percentage too big");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");

        stakingDefinition.withdrawFeePercentage = _percentage;
        stakingDefinition.withdrawFeeUpdateOn = uint64(block.timestamp);
        
        emit WithdrawFeeChanged(_stakingDefinitionId, _percentage);
    }

    /**
     *  @notice only owner can enable or disable staking definition
     *  @param _stakingDefinitionId staking definitionId
     */
    function enableStakingDefinition(uint8 _stakingDefinitionId) external onlyOwner {
        require(_stakingDefinitionId < totalStakingDefinitions, "_stakingDefinitionId not exist");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        stakingDefinition.enabled = true;
        
        emit StakingDefinitionEnabled(_stakingDefinitionId);
    }

    /**
     *  @notice only owner can disable staking definition
     *  @param _stakingDefinitionId staking definitionId
     */
    function disableStakingDefinition(uint8 _stakingDefinitionId) external onlyOwner {
        require(_stakingDefinitionId < totalStakingDefinitions, "_stakingDefinitionId not exist");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        stakingDefinition.enabled = false;
        
        emit StakingDefinitionDisabled(_stakingDefinitionId);
    }

    /**
     *  @notice only owner can change current name 
     *  @param _stakingDefinitionId id of staking definition
     *  @param _name name of the staking contract
     */
    function setName(uint8 _stakingDefinitionId, string calldata _name) external onlyOwner {
        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");

        stakingDefinition.name = _name;
    }

    /**
     *  @notice only owner can change current withdraw fee for stakers
     *  @param _stakingDefinitionId staking definition id
     *  @param _poolMultiplier reward multiplier for staking definition.   
     */
    function setPoolMultiplier(uint8 _stakingDefinitionId, uint32 _poolMultiplier) external onlyOwner {
        require(_poolMultiplier >= BASIS_POINT_RATE_CONVERTER, "_poolMultiplier too low");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");

        stakingDefinition.poolMultiplier = _poolMultiplier;
        
        emit PoolMultiplierChanged(_stakingDefinitionId, _poolMultiplier);
    }

    /**
     *  @notice only owner can change current name 
     *  @param _treasury treasury where withdraw fee will go
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(address(_treasury) != address(0), "treasury address is 0");

        treasury = _treasury;
    }

    /**
     *  @notice to set new interest rates for staking definition
     *  @param _stakingDefinitionId id of staking definition
     *  @param _rate New effective interest rate
     */
    function setRate(uint8 _stakingDefinitionId, uint16 _rate) external onlyOwner {
        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");
        require(_rate <= BASIS_POINT_RATE_CONVERTER, "rate too big");

        stakingDefinition.rate = _rate;

        emit RateChanged(_rate);
    }

    /**
     *  @notice to set new interest rates for staking definition
     *  @param _stakingDefinitionId id of staking definition
     *  @param _lockDuration New locak duration for new deposits which will be created
     *  @dev lockduration is in seconds. 2^32 - 1, max duration, which is ~106years in seconds.
     */
    function setLockDuration(uint8 _stakingDefinitionId, uint32 _lockDuration) external onlyOwner {
        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");

        stakingDefinition.lockDuration = _lockDuration;

        emit LockDurationChanged(_lockDuration);
    }

    /**
     *  @param _isStopped flag to pause/unpause stake
     *  @dev if isStopped is is set to true contracts stake actions will be stopped
     */
    function setIsStopped(bool _isStopped) external onlyOwner {
        isStopped = _isStopped;

        emit IsStoppedChanged(_isStopped, block.timestamp);
    }

    /**
     *  @param _prematureWithdrawEnabled pre mature withdraw enabled flag
     *  @dev if prematureWithdrawEnabled user will be able to withdraw amount before maturity is reached
     */
    function setPrematureWithdrawEnabled(bool _prematureWithdrawEnabled) external onlyOwner {
        prematureWithdrawEnabled = _prematureWithdrawEnabled;

        emit PrematureWithdrawFlagUpdated(_prematureWithdrawEnabled, block.timestamp);
    }

    /**
     *  @param amount Amount to be staked
     *  @param _stakingDefinitionId id of staking definition
     *  @dev to stake 'amount' value of tokens
     *  once the user has given allowance to the staking contract user can call this function.
     */
    function stake(uint8 _stakingDefinitionId, uint256 amount) external nonReentrant hasAllowance(_msgSender(), amount) {
        require(amount > 0, "amount is zero");
        require(!isStopped, "staking is stopped");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");
        require(stakingDefinition.enabled, "staking def not enabled");

        address from = _msgSender();

        Deposit storage userDeposit = deposits[from][_stakingDefinitionId];
        bool isThereActiveStaking = userDeposit.status == DEPOSIT_STATUS_STAKING;

        if(isThereActiveStaking) {
            require(userDeposit.endTime > block.timestamp, "maturity expired. please withdraw");
        }

        uint256 newAmount;
        if (isThereActiveStaking) {
            uint256 currentReward = _calculateInterest(userDeposit, block.timestamp);
            newAmount = amount + deposits[from][_stakingDefinitionId].depositAmount + currentReward;
            stakedBalance = stakedBalance + amount + currentReward;
        } else {
            newAmount = amount;
            totalActiveStakings += 1;
            stakingDefinition.numberOfActiveStakings += 1;
            stakedBalance = stakedBalance + amount;
        }

        userDeposit.stakingDefinitionId = _stakingDefinitionId;
        userDeposit.status = DEPOSIT_STATUS_STAKING;
        userDeposit.rate = stakingDefinition.rate;
        userDeposit.withdrawFeePercentage = stakingDefinition.withdrawFeePercentage;
        userDeposit.depositTime = uint64(block.timestamp);
        userDeposit.endTime = uint64(block.timestamp + stakingDefinition.lockDuration);
        userDeposit.depositAmount = newAmount;
        userDeposit.rewardClaimedTime = 0; // reset any reward claimed time from before as this is new staking

        tokenAddress.safeTransferFrom(from, address(this), amount);

        emit Staked(from, _stakingDefinitionId, userDeposit.endTime, amount);
    }

    /**
     * @notice user who is staking can withdraw their deposit. 
     * @dev based on user state, if there is premature withdrawal fee will be calculated and if there are rewards, 
     * it will be added to amount sent to user
     * @param _stakingDefinitionId id of staking definition 
     */
    function withdraw(uint8 _stakingDefinitionId) nonReentrant external withdrawCheck(_stakingDefinitionId, _msgSender()) {
        address from = _msgSender();

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        Deposit storage userDeposit = deposits[from][_stakingDefinitionId];

        if(block.timestamp <= userDeposit.endTime) {
            require(prematureWithdrawEnabled, "premature withdraw not enabled");
        }

        uint256 endTime = min(block.timestamp, userDeposit.endTime);
        uint256 reward = _calculateInterest(userDeposit, endTime);

        require(rewardBalance >= reward, "rewardBalance is too low");

        uint256 penalty = calculateWithdrawFee(_stakingDefinitionId, from);

        uint256 amount = userDeposit.depositAmount;
        uint256 amountAfterPenalty = amount - penalty;

        require(stakedBalance >= amount, "stakedBalance less than depositAmount");

        stakedBalance = stakedBalance - amount;
        rewardBalance = rewardBalance - reward;

        userDeposit.status = DEPOSIT_STATUS_STAKING_WITHDRAWN;
        stakingDefinition.numberOfActiveStakings -= 1;
        totalActiveStakings -= 1;

        // send user his deposit
        tokenAddress.safeTransfer(from, amountAfterPenalty + reward);
        if (penalty > 0) {
            // send any penalty to treasury wallet
            tokenAddress.safeTransfer(treasury, penalty);
        }

        emit PaidOut(from, amountAfterPenalty, reward);
    }

    /**
     * @notice withdraw without reward if no reard balance
    */
    function emergencyWithdrawWithoutReward(uint8 _stakingDefinitionId) nonReentrant withdrawCheck(_stakingDefinitionId, _msgSender()) external {
        address from = _msgSender();

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        Deposit storage userDeposit = deposits[from][_stakingDefinitionId];

        if(block.timestamp <= userDeposit.endTime) {
            require(prematureWithdrawEnabled, "premature withdraw not enabled");
        }

        uint256 penalty = calculateWithdrawFee(_stakingDefinitionId, from);

        uint256 amount = userDeposit.depositAmount;
        uint256 amountAfterPenalty = amount - penalty;

        require(stakedBalance >= amount, "stakedBalance less than depositAmount");

        stakedBalance = stakedBalance - amount;

        userDeposit.status = DEPOSIT_STATUS_STAKING_WITHDRAWN;
        stakingDefinition.numberOfActiveStakings -= 1;
        totalActiveStakings -= 1;

        // send user his deposit
        tokenAddress.safeTransfer(from, amountAfterPenalty);
        if (penalty > 0) {
            // send any penalty to treasury wallet
            tokenAddress.safeTransfer(treasury, penalty);
        }

        emit PaidOut(from, amountAfterPenalty, 0);    
    }

    /**
     *  @param _stakingDefinitionId id of staking definition
     *  @dev it will restake initial deposited amount plus reward earnd at that time
     */
    function claimAndStake(uint8 _stakingDefinitionId) external nonReentrant {
        require(!isStopped, "staking is stopped");

        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");
        require(stakingDefinition.enabled, "staking def not enabled");

        address from = _msgSender();

        Deposit storage userDeposit = deposits[from][_stakingDefinitionId];
        require(userDeposit.status == DEPOSIT_STATUS_STAKING, "there is not active staking");
        
        uint256 currentReward = _calculateInterest(userDeposit,  min(block.timestamp, userDeposit.endTime));

        require(currentReward > 0, "current reward = 0");
        require(rewardBalance >= currentReward, "rewardBalance < currentReward");
        
        stakedBalance = stakedBalance + currentReward;
        rewardBalance = rewardBalance - currentReward;

        uint256 newStakeAmount = userDeposit.depositAmount + currentReward;

        userDeposit.stakingDefinitionId = _stakingDefinitionId;
        userDeposit.status = DEPOSIT_STATUS_STAKING;
        userDeposit.rate = stakingDefinition.rate;
        userDeposit.withdrawFeePercentage = stakingDefinition.withdrawFeePercentage;
        userDeposit.depositTime = uint64(block.timestamp);
        userDeposit.endTime = uint64(block.timestamp + stakingDefinition.lockDuration);
        userDeposit.depositAmount = newStakeAmount;
        userDeposit.rewardClaimedTime = 0; // reset any reward claimed time from before as this is new staking

        emit Staked(from, _stakingDefinitionId, userDeposit.endTime, newStakeAmount);
    }

     /**
     * @notice user who is staking can calim reward accumulated 
     * @dev based on user state if there are rewards, it will be sent to user
     * @param _stakingDefinitionId id of staking definition 
     */
    function claimReward(uint8 _stakingDefinitionId) nonReentrant external withdrawCheck(_stakingDefinitionId, _msgSender()) {
        address from = _msgSender();

        Deposit storage userDeposit = deposits[from][_stakingDefinitionId];

        uint256 endTime = min(block.timestamp, userDeposit.endTime);
        uint256 reward = _calculateInterest(userDeposit, endTime);

        require(reward > 0, "reward is 0");
        require(rewardBalance >= reward, "rewardBalance is too low");

        rewardBalance = rewardBalance - reward;
        userDeposit.rewardClaimedTime = uint64(block.timestamp);
 
        // send user his reward
        tokenAddress.safeTransfer(from, reward);

        emit RewardCollected(from, reward);
    }

    /**
     * @param _stakingDefinitionId id of staking definition
     * @param _userAddress user address
     * @dev returns user deposit struct. 
     * User status can be:
     * DEPOSIT_STATUS_NOT_STAKING = 0; DEPOSIT_STATUS_STAKING = 1; DEPOSIT_STATUS_STAKING_WITHDRAWN = 2;
     * 0 is if there is no current staking, 1 is if there is active deposit and 2 is if tehre is paidout deposit.
     */
    function getUserDeposit(uint8 _stakingDefinitionId, address _userAddress) external view returns (Deposit memory userDeposit) {
        userDeposit = deposits[_userAddress][_stakingDefinitionId];
    }

    /**
     *  @param _stakingDefinitionId id of staking definition
     *  @param _userAddress user address
     *  @dev return flag if user is having active staking deposit
     */
    function doesUserHaveActiveStake(uint8 _stakingDefinitionId, address _userAddress) public view returns (bool) {
        Deposit memory userDeposit = deposits[_userAddress][_stakingDefinitionId];

        return userDeposit.status == DEPOSIT_STATUS_STAKING;
    }

    /**
     * @dev get user staking definition for byUniqueId
     * @param _stakingDefinitionId id of staking definition 
    */ 
    function getStakingDefinition(uint8 _stakingDefinitionId) public view returns (StakingDefinition memory) {
        StakingDefinition memory stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "SD: staking def not exist");

        return stakingDefinition;
    }

    /**
        @dev get contract token state
    */ 
    function getContractState() public view returns (uint256 recordedStakingBalance, uint256 recordedRewardBalance, uint256 actualTokenBalance) {
        recordedStakingBalance = stakedBalance;
        recordedRewardBalance = rewardBalance;
        actualTokenBalance = tokenAddress.balanceOf(address(this));
    }

    /**
     * @notice Calcule withdraw penalty for user if deposit is withdrawn now
     * @param _stakingDefinitionId id of staking definition 
     * @param user which is staking. If it is no staking fee is 0
     */
    function calculateWithdrawFee(uint8 _stakingDefinitionId, address user) public view returns (uint256 withdrawFee) {
        StakingDefinition memory stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        Deposit memory userDeposit = deposits[user][_stakingDefinitionId];
        if (block.timestamp > userDeposit.endTime) {
            return 0;
        }
        WithdrawFeeState memory withdrawFeeState = withdrawFeePercentageState(stakingDefinition.uniqueIdentifier, user);

        withdrawFee = (userDeposit.depositAmount * withdrawFeeState.withdrawFeeUsed) / BASIS_POINT_RATE_CONVERTER;
    }

    /**
     * @dev Calcule withdraw fee state. We will get details what fee is used for sent user and staking definition
     *  at the moment and all other values, like globalFee, deposit recored fee.
     * @param _stakingDefinitionId id of staking definition 
     * @param user which is staking.
     */
    function withdrawFeePercentageState(uint8 _stakingDefinitionId, address user) public view returns (WithdrawFeeState memory withdrawFeeState) {
        StakingDefinition memory stakingDefinition = stakingDefinitions[_stakingDefinitionId];
        require(stakingDefinition.exists, "stakingDefinition not exist");

        Deposit memory userDeposit = deposits[user][_stakingDefinitionId];
        uint32 withdrawFeePercentage = stakingDefinition.globalWithdrawFeePercentageEnabled ? stakingDefinition.globalWithdrawFeePercentage : userDeposit.withdrawFeePercentage;

        return WithdrawFeeState({
            stakingDefinitionId: stakingDefinition.uniqueIdentifier,
            globalFee: stakingDefinition.globalWithdrawFeePercentage,
            globalFeeEnabled: stakingDefinition.globalWithdrawFeePercentageEnabled,
            depositRecordedFee: userDeposit.withdrawFeePercentage,
            depositStatus: userDeposit.status,
            withdrawFeeUsed: withdrawFeePercentage
        });        
    }

    /**
     *  @param rewardAmount rewards to be added to the staking contract
     *  @dev to add rewards to the staking contract
     *  once the allowance is given to this contract for 'rewardAmount' by the user
     */
    function addReward(uint256 rewardAmount) external nonReentrant hasAllowance(_msgSender(), rewardAmount) {
        require(rewardAmount > 0, "rewardAmount is zero");

        rewardBalance = rewardBalance + rewardAmount;

        tokenAddress.safeTransferFrom(_msgSender(), address(this), rewardAmount);

        emit RewardsAdded(rewardAmount, block.timestamp);
    }

    /**
     * @notice rescue any token accidentally sent to this contract
     */
    function emergencyWithdrawToken(IERC20 token) external onlyOwner {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    /** 
     * @param _stakingDefinitionId id of staking definition 
     * @param user User wallet address
     * @return totalRewards Rewards from staking if user waits for maturity/end date
     * @return currentRewards Rewards from staking if user decide to withdraw right now
     */
    function calculateRewards(uint8 _stakingDefinitionId, address user) external view returns (uint256 totalRewards, uint256 currentRewards) {
        Deposit memory userDeposit = deposits[user][_stakingDefinitionId];

        totalRewards = _calculateInterest(userDeposit, userDeposit.endTime);
        currentRewards = _calculateInterest(userDeposit, min(block.timestamp, userDeposit.endTime));
    }

    /** 
     * @param _stakingDefinitionId id of staking definition 
     * @param depositAmount Deposit amount
     * @return estimatedRewards Estimated rewards for provided staking definition
     */
    function estimateRewards(uint8 _stakingDefinitionId, uint256 depositAmount) external view returns (uint256 estimatedRewards) {
        StakingDefinition storage stakingDefinition = stakingDefinitions[_stakingDefinitionId]; 
        require(stakingDefinition.exists, "staking def not exist");
        require(stakingDefinition.enabled, "staking def not enabled");

        uint256 totalRewardCalculationDividend = depositAmount * stakingDefinition.rate * stakingDefinition.lockDuration;
        uint256 totalRewardCalculationDivisor = YEAR_IN_SECONDS * BASIS_POINT_RATE_CONVERTER;
        estimatedRewards = totalRewardCalculationDividend / totalRewardCalculationDivisor;
    }

    /**
     * @notice As uniswap sync() methodforce rewardBalance to include any token balance added accidentally
     */
    function sync() external onlyOwner nonReentrant {
        uint256 actualTokenBalance = tokenAddress.balanceOf(address(this));
        require(actualTokenBalance >= stakedBalance + rewardBalance, "invalid balance state for sync");

        rewardBalance = actualTokenBalance - stakedBalance;
    }

    function _calculateInterest(Deposit memory deposit, uint256 endTime) private pure returns (uint256 interest) {
        if (!(deposit.status == DEPOSIT_STATUS_STAKING)) return 0;
        if (endTime <= deposit.depositTime) return 0;
        if (deposit.rewardClaimedTime >= endTime) return 0;

        uint256 timePassed = endTime - max(deposit.depositTime, deposit.rewardClaimedTime);

        uint256 totalRewardCalculationDividend = deposit.depositAmount * deposit.rate * timePassed;
        uint256 totalRewardCalculationDivisor = YEAR_IN_SECONDS * BASIS_POINT_RATE_CONVERTER;
        interest = totalRewardCalculationDividend / totalRewardCalculationDivisor;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
