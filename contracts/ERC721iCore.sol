// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./HelperFunctions.sol";
import "base64-sol/base64.sol";
import "hardhat/console.sol";

library ERC721iCore {
  using SafeMath for uint256;

  bytes32 constant STORAGE_POSITION = keccak256("com.universe.singularity.storage");

  struct Fee {
    address payable recipient;
    uint256 decayType; // 0: no decay, 1: linear, 2: timestamp change / expiration
    uint256 value;
    uint256 endValue;
    uint256 startTime;
    uint256 endTime;
  }

  struct Metadata {
    string tokenName;
    string tokenDescription;
    string[] name; // Trait or attribute property field name
    string[] value; // Trait or attribute property value
    bool[] modifiable; // Can owner modify the value of field
    uint256 propertyCount; // Tracker of total attributes
  }

  struct TokenData {
    address tokenCreator; // User who minted
    Metadata metadata;
    string licenseURI; // Usage rights for token
    string externalURL;
    string[] assetHashes;
    bool editioned;
    uint256 currentVersion;
    uint256 totalVersionCount;
  }

  struct Storage {
    address singularityAddress;
    address payable daoAddress;
    bool daoInitialized;
    string baseURL;
    mapping (uint256 => Fee[]) fees;
    mapping (uint256 => TokenData) tokenData;
    mapping (uint256 => uint256) editions; // Declares multiple editions for an NFT
    mapping (uint256 => uint256) editionedPointers; // Points to metadata of NFT editions

    uint256 _tokenIdCounter;
  }

  function ERC721iStorage() internal pure returns (Storage storage ds) {
    bytes32 position = STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  event SecondarySaleFees(
    uint256 tokenId,
    address[] recipients,
    uint[] bps
  );

  event TokenMinted(
    uint256 tokenId,
    string tokenURI,
    address receiver,
    uint256 time
  );

  modifier onlyDAO() {
    require(msg.sender == ERC721iStorage().daoAddress, "Wrong address");
    _;
  }

  function mint(
    string memory _name,
    string memory _description,
    string memory _assetHash,
    string[][] memory _metadataValues,
    string memory _licenseURI,
    string memory _externalURL,
    Fee[] memory _fees,
    uint256 _editions,
    bool _editioned
  ) external {
    Storage storage ds = ERC721iStorage();

    ds._tokenIdCounter = ds._tokenIdCounter.add(1);
    ds.editions[ds._tokenIdCounter] = _editions;

    Metadata memory metadata;
    require (_metadataValues[0].length == _metadataValues[1].length, "Invalid metadata");

    uint256 propertyCount = _metadataValues[0].length;
    bool[] memory modifiables = new bool[](_metadataValues.length);
    for (uint256 i = 0; i < propertyCount; i++) {
      modifiables[i] = (keccak256(abi.encodePacked(_metadataValues[2][i])) == keccak256(abi.encodePacked("1"))); // 1 is modifiable, 0 is permanent
    }

    metadata = Metadata({
      tokenName: _name,
      tokenDescription: _description,
      name: (_metadataValues[0].length > 0) ? _metadataValues[0] : new string[](0),
      value: (_metadataValues[1].length > 0) ? _metadataValues[1] : new string[](0),
      modifiable: modifiables,
      propertyCount: propertyCount
    });

    string[] memory assetHash = new string[](1);
    assetHash[0] = _assetHash;
    ds.tokenData[ds._tokenIdCounter] = TokenData({
      tokenCreator: msg.sender,
      metadata: metadata,
      licenseURI: _licenseURI,
      externalURL: _externalURL,
      editioned: _editioned,
      assetHashes: assetHash,
      currentVersion: 1,
      totalVersionCount: 1
    });

    for (uint256 i = 0; i < _editions; i++) {
      emit TokenMinted(ds._tokenIdCounter + i, "Mint!", msg.sender, block.timestamp);
      ds.editionedPointers[ds._tokenIdCounter + i] = ds._tokenIdCounter;
    }

    _registerFees(ds._tokenIdCounter, _fees);
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    Storage storage ds = ERC721iStorage();
    return ds.tokenData[tokenId].tokenCreator;
  }

  function addNewVersion(uint256 tokenId, string memory assetHash) public {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, "Only creator can modify");
    ds.tokenData[tokenIdentifier].assetHashes.push(assetHash);
    ds.tokenData[tokenIdentifier].totalVersionCount++;
    ds.tokenData[tokenIdentifier].currentVersion = ds.tokenData[tokenIdentifier].totalVersionCount;
  }

  function changeVersion(uint256 tokenId, uint256 version) external {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, "Only creator can modify");
    require(version <= ds.tokenData[tokenIdentifier].totalVersionCount, "Out of version bounds");
    require(version >= 1, "Out of version bounds");
    ds.tokenData[tokenIdentifier].currentVersion = version;
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    return ds.tokenData[tokenIdentifier].currentVersion;
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) external {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, "Only creator can modify");
    require(ds.tokenData[tokenIdentifier].metadata.modifiable[propertyIndex - 1], "Field not editable");
    require(propertyIndex <= ds.tokenData[tokenIdentifier].metadata.propertyCount, "Out of version bounds");
    require(propertyIndex >= 1, "Out of version bounds");
    ds.tokenData[tokenIdentifier].metadata.value[propertyIndex - 1] = value;
  }

  function updateExternalURL(uint256 tokenId, string memory url) external {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, "Only creator can modify");
    ds.tokenData[tokenIdentifier].externalURL = url;
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    return ds.tokenData[tokenIdentifier].licenseURI;
  }

  function tokenURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;

    string memory encodedMetadata = "";
    for (uint i = 0; i < ds.tokenData[tokenIdentifier].metadata.propertyCount; i++) {
      encodedMetadata = string(abi.encodePacked(
        encodedMetadata,
        '{"trait_type":"',
        ds.tokenData[tokenIdentifier].metadata.name[i],
        '", "value":"',
        ds.tokenData[tokenIdentifier].metadata.value[i],
        '", "permanent":"',
        ds.tokenData[tokenIdentifier].metadata.modifiable[i] ? "false" : "true",
        '"}',
        i == ds.tokenData[tokenIdentifier].metadata.propertyCount - 1 ? "" : ",")
      );
    }

    uint256 edition = tokenId - tokenIdentifier;

    string memory tokenName = ds.tokenData[tokenIdentifier].metadata.tokenName;
    tokenName = string(abi.encodePacked(
        tokenName,
        ds.tokenData[tokenIdentifier].editioned ? " #" : "",
        ds.tokenData[tokenIdentifier].editioned ? HelperFunctions.uint2str(edition + 1) : "",
        ds.tokenData[tokenIdentifier].editioned ? "/" : "",
        ds.tokenData[tokenIdentifier].editioned ? HelperFunctions.uint2str(ds.editions[tokenIdentifier]) : ""
      )
    );

    string memory encoded = string(
      abi.encodePacked(
        "data:application/json;base64,",
        Base64.encode(
          bytes(
            abi.encodePacked(
              '{"name":"',
              tokenName,
              '", "description":"',
              ds.tokenData[tokenIdentifier].metadata.tokenDescription,
              '", "image": "',
              "https://openseauserdata.com/files/49280058c3289613d2735376f1d70faa.mp4",
              '", "animation_url": "',
              ds.baseURL,
              "/?metadata=",
              ds.tokenData[tokenIdentifier].assetHashes[ds.tokenData[tokenIdentifier].currentVersion - 1],
              '", "license": "',
              ds.tokenData[tokenIdentifier].licenseURI,
              '", "external_url": "',
              ds.tokenData[tokenIdentifier].externalURL,
              '", "attributes": [',
              encodedMetadata,
              "]",
              ', "assets": ["',
              ds.tokenData[tokenIdentifier].assetHashes[0],
              '"]',
              "}"
            )
          )
        )
      )
    );

    return encoded;
  }

  function _registerFees(uint256 _tokenId, Fee[] memory _fees) internal {
    Storage storage ds = ERC721iStorage();
    require(_fees.length <= 10, "No more than 5 recipients");

    address[] memory recipients = new address[](_fees.length);
    uint256[] memory bps = new uint256[](_fees.length);
    uint256 sum = 0;
    for (uint256 i = 0; i < _fees.length; i++) {
      require(_fees[i].recipient != address(0x0), "Recipient should be present");
      require(_fees[i].value != 0, "Fee value should be positive");
      sum += _fees[i].value;
      ds.fees[_tokenId].push(_fees[i]);
      recipients[i] = _fees[i].recipient;
      bps[i] = _fees[i].value;
    }
    require(sum <= 10000, "Fee should be less than 100%");
    if (_fees.length > 0) {
      emit SecondarySaleFees(_tokenId, recipients, bps);
    }
  }

  function getFeeRecipients(uint256 id) public view returns (address payable[] memory) {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[id] > 0) ? ds.editionedPointers[id] : id;
    Fee[] memory _fees = ds.fees[tokenIdentifier];
    address payable[] memory result = new address payable[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].recipient;
    }
    return result;
  }

  function getFeeBps(uint256 id) public view returns (uint[] memory) {
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[id] > 0) ? ds.editionedPointers[id] : id;
    Fee[] memory _fees = ds.fees[tokenIdentifier];
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
    Storage storage ds = ERC721iStorage();
    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;
    address payable[] memory rec = getFeeRecipients(tokenIdentifier);
    require(rec.length <= 1, "More than 1 royalty recipient");

    if (rec.length == 0) return (address(this), 0);
    return (rec[0], getFeeBps(tokenIdentifier)[0] * value / 10000);
  }

  function withdraw(address _to, uint amount) public onlyDAO {
    (bool success, ) = payable(_to).call{value:amount, gas:200000}("");
    require(success, "Withdraw failed");
  }
}