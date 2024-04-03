// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Helper, Tier, TierSetup} from "../../src/Helper.sol";
import {Staking, StakingDefinitionCreate} from "../../src/Staking.sol";
import "../Token.sol";

abstract contract HelperBaseTest is Test {
    // contracts
    Helper internal helper;

    IERC20 internal token;
    address internal treasury = 0x8C9bdbf68e52226448367c00948333Dda7d9bA20;

    address internal nonOwner = 0x1111111111111111111111111111111111111111;
    address internal staker = 0x2222222222222222222222222222222222222222;

    function setUp() public virtual {
        token = new Token("Test token", "Test", 1e9, 18);

        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](5);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint16(6),
            withdrawFeePercentage: uint8(10),
            lockDuration: uint32(7 days),
            name: "7days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: uint16(13),
            withdrawFeePercentage: uint8(20),
            lockDuration: uint32(14 days),
            name: "14days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _thirdDefinition = StakingDefinitionCreate({
            rate: uint16(30),
            withdrawFeePercentage: uint8(30),
            lockDuration: uint32(30 days),
            name: "30days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _fourthDefinition = StakingDefinitionCreate({
            rate: uint16(65),
            withdrawFeePercentage: uint8(40),
            lockDuration: uint32(60 days),
            name: "60days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _fifthDefinition = StakingDefinitionCreate({
            rate: uint16(80),
            withdrawFeePercentage: uint8(50),
            lockDuration: uint32(90 days),
            name: "90days",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        _stakingDefinitions[2] = _thirdDefinition;
        _stakingDefinitions[3] = _fourthDefinition;
        _stakingDefinitions[4] = _fifthDefinition;
        
        Staking staking = new Staking(
            _stakingDefinitions,
            address(token),
            treasury,
            true
        );

        TierSetup[] memory tiers = new TierSetup[](8);
        tiers[0] = TierSetup({name: "SNAKE", amountNeeded: 200e18, weight: 1});
        tiers[1] = TierSetup({name: "SCORPION", amountNeeded: 1000e18, weight: 2});
        tiers[2] = TierSetup({name: "BEAR", amountNeeded: 2_500e18, weight: 6});
        tiers[3] = TierSetup({name: "EAGLE", amountNeeded: 5_000e18, weight: 13});
        tiers[4] = TierSetup({name: "BULL", amountNeeded: 10_000e18, weight: 30});
        tiers[5] = TierSetup({name: "LION", amountNeeded: 20_000e18, weight: 65});
        tiers[6] = TierSetup({name: "DRAGON", amountNeeded: 40_000e18, weight: 140});
        tiers[7] = TierSetup({name: "JUGGERNAUT", amountNeeded: 80_000e18, weight: 305});

        helper = new Helper(staking, tiers);
        token.transfer(staker, 100_000e18);
    }
}
