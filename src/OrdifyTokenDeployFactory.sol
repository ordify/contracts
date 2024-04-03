// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "@openzeppelin/contracts/utils/Create2.sol";
import {OrdifyToken} from "./OrdifyToken.sol";

/**
 * @title OrdifyTokenDeployFactory - factory to deploy OrdifyToken with CREATE2 opcode, 
 * which wil ensure same adress on different chains if needed.
 */
contract OrdifyTokenDeployFactory {
    address public latestTokenAddress;
    mapping(bytes32 => address) public deployedTokens;

    modifier checkTokenNotDeployed(bytes32 _salt) {
        require(deployedTokens[_salt] == address(0), "Token already deployed for this salt");
        _;
    }

    function deployToken(bytes32 _salt, address _lzEndpoint, uint256 _baseChainId, string memory _uuid)
        external 
        checkTokenNotDeployed(_salt) 
        returns (address) 
    {
        latestTokenAddress = Create2.deploy(
            0,
            _salt,
            abi.encodePacked(type(OrdifyToken).creationCode, abi.encode(_lzEndpoint, _baseChainId, _uuid))
        );

        deployedTokens[_salt] = latestTokenAddress;

        OrdifyToken deployedToken = OrdifyToken(latestTokenAddress);
        deployedToken.transferOwnership(msg.sender);

        uint256 currentBalance = deployedToken.balanceOf(address(this));
        if(currentBalance > 0) {
            deployedToken.transfer(msg.sender, currentBalance);
        }
        
        return latestTokenAddress;
    }

    function computeTokenAddress(bytes32 _salt, address _lzEndpoint, uint256 _baseChainId, string memory _uuid) 
        public 
        view 
        returns (address) 
    {
        return Create2.computeAddress(
            _salt,
            keccak256(abi.encodePacked(type(OrdifyToken).creationCode, abi.encode(_lzEndpoint, _baseChainId, _uuid)))
        );
    }
}