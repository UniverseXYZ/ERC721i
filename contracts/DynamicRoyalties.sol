// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract DynamicRoyalties {
  mapping (uint256 => Fee[]) fees;
  mapping (uint256 => uint256) editionedPointers; // Points to metadata of NFT editions
  address contractAddress;

  event SecondarySaleFees(
    uint256 tokenId,
    address[] recipients,
    uint[] bps
  );

  struct Fee {
    address payable recipient;
    uint256 decayType; // 0: no decay, 1: linear, 2: timestamp change / expiration
    uint256 value;
    uint256 endValue;
    uint256 startTime;
    uint256 endTime;
  }

  constructor(address _contractAddress) {
    contractAddress = _contractAddress;
  }

  modifier onlyContract() {
    require(msg.sender == contractAddress, "Wrong address");
    _;
  }

  function _registerFees(uint256 _tokenId, Fee[] memory _fees, uint256 _editions) public onlyContract() returns (bool) {
    require(_fees.length <= 10, "No more than 5 recipients");

    for (uint256 i = 0; i < _editions; i++) {
      editionedPointers[_tokenId + i] = _tokenId;
    }

    address[] memory recipients = new address[](_fees.length);
    uint256[] memory bps = new uint256[](_fees.length);
    uint256 sum = 0;
    for (uint256 i = 0; i < _fees.length; i++) {
      require(_fees[i].recipient != address(0x0), "Recipient should be present");
      require(_fees[i].value != 0, "Fee value should be positive");
      sum += _fees[i].value;
      fees[_tokenId].push(_fees[i]);
      recipients[i] = _fees[i].recipient;
      bps[i] = _fees[i].value;
    }
    require(sum <= 10000, "Fee should be less than 100%");
    if (_fees.length > 0) {
      emit SecondarySaleFees(_tokenId, recipients, bps);
    }
  }

  function getFeeRecipients(uint256 id) public view returns (address payable[] memory) {
    uint256 tokenIdentifier = (editionedPointers[id] > 0) ? editionedPointers[id] : id;
    Fee[] memory _fees = fees[tokenIdentifier];
    address payable[] memory result = new address payable[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].recipient;
    }
    return result;
  }

  function getFeeBps(uint256 id) public view returns (uint[] memory) {
    uint256 tokenIdentifier = (editionedPointers[id] > 0) ? editionedPointers[id] : id;
    Fee[] memory _fees = fees[tokenIdentifier];
    uint[] memory result = new uint[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      if (_fees[i].decayType == 0) {
        result[i] = _fees[i].value;
      } else if (_fees[i].decayType == 1) {
        if (block.timestamp > _fees[i].endTime) {
          result[i] = _fees[i].endValue;
        } else if (block.timestamp < _fees[i].startTime) {
          result[i] = _fees[i].value;
        } else {
          if (_fees[i].endValue > _fees[i].value) {
            result[i] = _fees[i].endValue - ((_fees[i].endValue -  _fees[i].value) * (_fees[i].endTime - block.timestamp) / (_fees[i].endTime - _fees[i].startTime));
          } else {
            result[i] = _fees[i].endValue + (( _fees[i].value - _fees[i].endValue) * (_fees[i].endTime - block.timestamp) / (_fees[i].endTime - _fees[i].startTime));
          }
        }
      } else if (_fees[i].decayType == 2) {
        result[i] = block.timestamp > _fees[i].endTime ? _fees[i].endValue : _fees[i].value;
      }
    }
    return result;
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount) {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    address payable[] memory rec = getFeeRecipients(tokenIdentifier);
    require(rec.length <= 1, "More than 1 royalty recipient");

    if (rec.length == 0) return (address(this), 0);
    return (rec[0], getFeeBps(tokenIdentifier)[0] * value / 10000);
  }
}