// SPDX-License-Identifier: MIT
pragma solidity     0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Staking, Deposit, StakingDefinition} from "./Staking.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct Tier {
    string name;
    uint256 amountNeeded;
    uint16 weight;
    bool initialized;
}

struct TierSetup {
    string name;
    uint256 amountNeeded;
    uint16 weight;
}

struct UserTokensToReceive {
    address user;
    uint256 tokens;
    uint256 contributedStable;
}

struct UserDeposit {
    uint8 stakingDefinitionId;
    uint8 status; // [DEPOSIT_STATUS_NOT_STAKING, DEPOSIT_STATUS_STAKING, DEPOSIT_STATUS_STAKING_WITHDRAWN]
    uint32 rate;
    uint32 stakingPoolMultiplier;
    string stakingName;
    uint32 stakingRate;
    uint32 withdrawFeePercentage;
    uint64 depositTime;
    uint64 endTime;
    uint64 rewardClaimedTime;
    uint256 depositAmount;
}


interface ILaunchpad {
    function getUserContribution(address) external view returns (uint256, uint256);

    function hasParticipated(address) external view returns (bool);
}

/**
 * @dev This contract is used from some scripts and UI, it is not used from other contracts on chain and can be deployed new one at any time if needed.
 * It is Helper contract with some utilities.
*/
contract Helper is Ownable {
    using SafeERC20 for IERC20;

    Staking public stakingContract;
    Tier[] public tiers;
    mapping(string => Tier) public tiersMap;

    /**
     * @dev Tiers should be ordered asc by amountNeeded
     * @param _stakingContract staking contract deployed
     * @param _tiers Array of all staking tiers
     */
    constructor(Staking _stakingContract, TierSetup[] memory _tiers) Ownable() {
        stakingContract = _stakingContract;

        Tier memory noneTier = Tier("NONE", 0, 0, true);
        tiers.push(noneTier);
        tiersMap["NONE"] = noneTier;

        Tier memory prevTier = tiers[0];
        for (uint256 i = 0; i < _tiers.length; i++) {
            require(prevTier.amountNeeded < _tiers[i].amountNeeded, "Tiers must be oredered amount needed");
            require(prevTier.weight < _tiers[i].weight, "Tiers must be oredered by weight");

            Tier memory existing = tiersMap[_tiers[i].name];
            require(!existing.initialized, "tier exist");

            Tier memory tier = Tier({
                name: _tiers[i].name,
                amountNeeded: _tiers[i].amountNeeded,
                weight: _tiers[i].weight,
                initialized: true
            });
            tiers.push(tier);
            tiersMap[_tiers[i].name] = tier;

            prevTier = tier;
        }
    }

    /**
     * @notice Returns all definied staking definitions. Max size is 30 as defined in staking contract
     */
    function getStakingDefinitions() external view returns (StakingDefinition[] memory) {
        StakingDefinition[] memory stakingDefinitions = new StakingDefinition[](stakingContract.totalStakingDefinitions());

        for (uint8 stakingDefinitionId = 0; stakingDefinitionId < stakingContract.totalStakingDefinitions(); stakingDefinitionId++) {
            StakingDefinition memory stakingDefinition = stakingContract.getStakingDefinition(stakingDefinitionId);
            stakingDefinitions[stakingDefinitionId] = stakingDefinition;
        }

        return stakingDefinitions;
    }

    /**
     * @notice Returns array of all possible tiers including "NONE"
     */
    function getTiersData() external view returns (Tier[] memory) {
        return tiers;
    }

    /**
     * @notice Aggregates data from all staking contracts to determine user tier
     * @param user  Address of the staker
     */
    function getUserStakingData(address user) public view returns (string memory, uint256, uint256, UserDeposit[] memory) {
        uint256 totalAmount;
        uint256 totalAmountWithMultiplier;
        string memory tierName;
        
        uint totalStakingDefinitions = stakingContract.totalStakingDefinitions();
        UserDeposit[] memory userDeposits = new UserDeposit[](totalStakingDefinitions);
        for (uint8 stakingDefinitionId = 0; stakingDefinitionId < totalStakingDefinitions; stakingDefinitionId++) {
            StakingDefinition memory _stakingDefinition = stakingContract.getStakingDefinition(stakingDefinitionId);
            Deposit memory userDeposit = stakingContract.getUserDeposit(stakingDefinitionId, user);

            userDeposits[stakingDefinitionId] = UserDeposit({
                stakingDefinitionId: stakingDefinitionId,
                status: userDeposit.status,
                rate: userDeposit.rate,
                stakingPoolMultiplier: _stakingDefinition.poolMultiplier,
                stakingName: _stakingDefinition.name,
                stakingRate: _stakingDefinition.rate,
                withdrawFeePercentage: userDeposit.withdrawFeePercentage,
                depositTime: userDeposit.depositTime,
                endTime: userDeposit.endTime,
                rewardClaimedTime: userDeposit.rewardClaimedTime,
                depositAmount: userDeposit.depositAmount
            });

            if(userDeposit.status == stakingContract.DEPOSIT_STATUS_STAKING()) {
                totalAmount += userDeposit.depositAmount;
                totalAmountWithMultiplier += (userDeposit.depositAmount * _stakingDefinition.poolMultiplier) / stakingContract.BASIS_POINT_RATE_CONVERTER();
            }
        }
        
        for (uint256 j = tiers.length - 1; j >= 0; j--) {
            if (totalAmountWithMultiplier >= tiers[j].amountNeeded) {
                tierName = tiers[j].name;
                break;
            }
        }

        return (tierName, totalAmount, totalAmountWithMultiplier, userDeposits);
    }

    // @dev used for snapshot before IDO
    function getUsersWeights(address[] calldata users) external view returns (uint16[] memory userWeights, uint256 blockNumber) {
        userWeights = new uint16[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            (string memory tier, , , ) = getUserStakingData(users[i]);
            userWeights[i] = tiersMap[tier].weight;
        }

        return (userWeights, block.number);
    }

    // @dev get user tokens to receive
    function getUserTokensToReceive(address[] calldata users, ILaunchpad launchpad) external view returns (UserTokensToReceive[] memory usersTokensToReceive) {
        usersTokensToReceive = new UserTokensToReceive[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            (uint256 contributedStable, uint256 tokensToReceive) = launchpad.getUserContribution(users[i]);
            usersTokensToReceive[i] = UserTokensToReceive(
                users[i],
                tokensToReceive,
                contributedStable
            );
        }

        return usersTokensToReceive;
    }

        // @notice rescue any token accidentally sent to this contract
        function emergencyWithdrawToken(IERC20 token) external onlyOwner {
            token.safeTransfer(msg.sender, token.balanceOf(address(this)));
        }
}
