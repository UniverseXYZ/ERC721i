//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "./interfaces/IERC721Consumable.sol";

abstract contract ERC721Consumable is IERC721Consumable, ERC721AUpgradeable {

    // Mapping from token ID to consumer address
    mapping (uint256 => address) _tokenConsumers;
    
    /**
     * @dev See {IERC721Consumable-consumerOf}
     */
    function consumerOf(uint256 _tokenId) view external returns (address) {
        require(_exists(_tokenId), "ERC721Consumable: consumer query for nonexistent token");
        return _tokenConsumers[_tokenId];
    }

    /**
     * @dev See {IERC721Consumable-changeConsumer}
     */
    function changeConsumer(address _consumer, uint256 _tokenId) external {
        address owner = this.ownerOf(_tokenId);
        require(msg.sender == owner || msg.sender == getApproved(_tokenId) ||
            isApprovedForAll(owner, msg.sender),
            "ERC721Consumable: changeConsumer caller is not owner nor approved");
        _changeConsumer(owner, _consumer, _tokenId);
    }

    /**
     * @dev Changes the consumer
     * Requirement: `tokenId` must exist
     */
    function _changeConsumer(address _owner, address _consumer, uint256 _tokenId) internal {
        _tokenConsumers[_tokenId] = _consumer;
        emit ConsumerChanged(_owner, _consumer, _tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AUpgradeable) returns (bool) {
        return interfaceId == type(IERC721Consumable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfers(address _from, address _to, uint256 _tokenId, uint256 _quantity) internal virtual override (ERC721AUpgradeable) {
        super._beforeTokenTransfers(_from, _to, _tokenId, _quantity);

        _changeConsumer(_from, address(0), _tokenId);
    }

}