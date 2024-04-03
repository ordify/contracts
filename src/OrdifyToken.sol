// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract OrdifyToken is OFT, ERC20Capped {
    uint256 public constant MAX_SUPPLY = 100_000_000 ether; // 100M
    string public uuid;

    constructor(address _lzEndpoint, uint256 _baseChainId, string memory _uuid) OFT("Ordify", "ORFY", _lzEndpoint, _msgSender()) ERC20Capped(MAX_SUPPLY) Ownable() {
        uuid = _uuid;
        // mint will happen only on base ORDIFY chain
        if(block.chainid == _baseChainId) {
            ERC20._mint(_msgSender(), MAX_SUPPLY);
        }
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    function uuidResolver() view external returns (string memory) {
        return uuid;
    }
}