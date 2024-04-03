// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Staking, StakingDefinitionCreate} from "../../src/Staking.sol";
import { OrdifyToken} from "../../src/OrdifyToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";

contract StableToken is ERC20 {
    constructor() ERC20("USDT", "USDT") {
          _mint(0x00a329c0648769A73afAc7F9381E08FB43dBEA72, 100_000_000e18);
          _mint(msg.sender, 100_000_000e18);
    }
}

/**
 * @title StakingEchidnaTestScript
 * @dev Used for save transctions to json file which will be trasformed to etheno based json using rust lib `foundry2echidna`
 */
contract StakingEchidnaTestScript is Script {
    address echidnaUser1 = address(0x10000);
    address echidnaUser2 = address(0x20000);
    address echidnaUser3 = address(0x30000);
    address echidnaUser4 = address(0x40000);
    address echidnaUser5 = address(0x50000);
    address echidnaUser6 = address(0x60000);
    address echidnaUser7 = address(0x70000);
    address echidnaUser8 = address(0x80000);
    address echidnaUser9 = address(0x90000);
    address echidnaUser10 = address(0x11000);

    Staking internal staking;
    string internal stakingContractName = "Test staking";
    uint32 internal rate = 200;
    uint32 internal lockDuration = 30 days; // 30 days = 30 * 24 = 720
    address internal treasury = address(0x44000);

    address echidnaContractAddress = 0x00a329c0648769A73afAc7F9381E08FB43dBEA72;

    function run() external {
        // this is private key from GANACHE in our case, 
        // but it can be any that has balance on netowrk wher eyou executing it.
        vm.startBroadcast(0x4f9a86461179d14783afa16b8398ac04d6bfb1283d33b9b88470a5d13217fdde);

        EndpointV2 lzEndpoint = new EndpointV2(888, 0x7842623d71D694268a76E9eFE23BceAE5F72B460);
        // Ganche chainid = 1337
        OrdifyToken ordifyToken = new OrdifyToken(address(lzEndpoint), 1337, "uuid-1");
        ordifyToken.transfer(echidnaContractAddress, 96_000_000e18);

        // Create an instance of the smart contract (doing that will deploy the contract when the script runs)
        StakingDefinitionCreate[] memory _stakingDefinitions = new StakingDefinitionCreate[](5);
        StakingDefinitionCreate memory _firstDefinition = StakingDefinitionCreate({
            rate: uint32(800),
            withdrawFeePercentage: uint32(1000),
            lockDuration: uint32(30 days),
            name: "30 days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _secondDefinition = StakingDefinitionCreate({
            rate: uint32(3000),
            withdrawFeePercentage: uint32(2000),
            lockDuration: uint32(60 days),
            name: "60 days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _thirdDefinition = StakingDefinitionCreate({
            rate: uint32(4000),
            withdrawFeePercentage: uint32(3000),
            lockDuration: uint32(90 days),
            name: "90 days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _fourthDefinition = StakingDefinitionCreate({
            rate: uint32(5000),
            withdrawFeePercentage: uint32(4000),
            lockDuration: uint32(180 days),
            name: "180 days",
            poolMultiplier: uint32(10_000)
        });
        StakingDefinitionCreate memory _fifthDefinition = StakingDefinitionCreate({
            rate: uint32(8000),
            withdrawFeePercentage: uint32(5000),
            lockDuration: uint32(365 days),
            name: "365 days",
            poolMultiplier: uint32(10_000)
        });
        _stakingDefinitions[0] = _firstDefinition;
        _stakingDefinitions[1] = _secondDefinition;
        _stakingDefinitions[2] = _thirdDefinition;
        _stakingDefinitions[3] = _fourthDefinition;
        _stakingDefinitions[4] = _fifthDefinition;
        
        staking = new Staking(
            _stakingDefinitions,
            address(ordifyToken),
            treasury,
            false
        );

        ordifyToken.transfer(echidnaUser1, 200_000e18);
        ordifyToken.transfer(echidnaUser2, 300_000e18);
        ordifyToken.transfer(echidnaUser3, 400_000e18);
        ordifyToken.transfer(echidnaUser4, 200_000e18);
        ordifyToken.transfer(echidnaUser5, 300_000e18);
        ordifyToken.transfer(echidnaUser6, 400_000e18);
        ordifyToken.transfer(echidnaUser7, 200_000e18);
        ordifyToken.transfer(echidnaUser8, 300_000e18);
        ordifyToken.transfer(echidnaUser9, 400_000e18);
        ordifyToken.transfer(echidnaUser10, 400_000e18);

        staking.transferOwnership(echidnaContractAddress);
        
        vm.stopBroadcast();
    }
}