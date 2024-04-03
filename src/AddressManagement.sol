// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Address Management
 * @dev place to store user addresses on other chains for distribution of tokens deployed on those chains
 */
contract AddressManagement is Ownable {
    string[] public supportedChains;
    mapping(string => bool) public doesChainExist;
    mapping(address => mapping(uint256 => string)) public userAddresses;

    event AddressAdded(address indexed user, uint256  chainIndex);

    constructor() Ownable() {
        // default supported chains
        supportedChains.push("SOLANA");
        supportedChains.push("SUI");
        supportedChains.push("APTOS");

        for (uint i = 0; i < supportedChains.length; i++) {
            doesChainExist[supportedChains[i]] = true;
        }
    }

    function submitAddress(uint256 index, string memory _address) external {
        require(index < supportedChains.length, "chain not supported");

        address sender = _msgSender();
        userAddresses[sender][index] = _address;

        emit AddressAdded(sender, index);
    }

    function addChain(string memory chain) external onlyOwner {
        require(!doesChainExist[chain], "chain already exist");

        doesChainExist[chain] = true;
        supportedChains.push(chain);
    }

    function getNumberOfChains() external view returns (uint256) {
        return supportedChains.length;
    }
}
