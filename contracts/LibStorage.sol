// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Thought innovation by Monstercat
// Product by universe.xyz

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import 'base64-sol/base64.sol';

library LibStorage {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  bytes32 constant STORAGE_POSITION = keccak256("com.universe.singularity.storage");

  struct Fee {
    address payable recipient;
    uint256 value;
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
    bool isOnChain; // Flags for onchain token data
    Metadata metadata;
    string licenseURI; // Usage rights for token
    string[] assets; // Each asset in array is a version
    uint256 totalVersionCount; // Total number of existing states
    uint256 currentVersion; // Current existing state
    string[] additionalAssets; // Additional assets provided by minter
  }

  struct Storage { 
    address payable daoAddress;
    bool daoInitialized;
    mapping (uint256 => Fee[]) fees;
    mapping (uint256 => TokenData) tokenData;

    Counters.Counter _tokenIdCounter;
  }

  function libStorage() internal pure returns (Storage storage ds) {
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
    require(msg.sender == libStorage().daoAddress, "Wrong address");
    _;
  }

  function mint(
    string memory _tokenURI,
    string[] memory _additionalAssets,
    string memory _licenseURI,
    Fee[] memory fees
  ) external returns (uint256) {
    Storage storage ds = libStorage();

    ds._tokenIdCounter.increment();
    uint256 newTokenId = ds._tokenIdCounter.current();

    string[] memory _assets = new string[](1);
    _assets[0] = _tokenURI;
    ds.tokenData[newTokenId] = TokenData({
      tokenCreator: msg.sender,
      isOnChain: false,
      metadata: Metadata({
        tokenName: '',
        tokenDescription: '',
        name: new string[](0),
        value: new string[](0),
        modifiable: new bool[](0),
        propertyCount: 0
      }),
      licenseURI: _licenseURI,
      assets: _assets,
      totalVersionCount: 1,
      currentVersion: 1,
      additionalAssets: _additionalAssets
    });

    _registerFees(newTokenId, fees);

    emit TokenMinted(newTokenId, _tokenURI, msg.sender, block.timestamp);
  }

  function mintOnChain(
    string[] memory _tokenData,
    string[] memory _additionalAssets,
    string[][] memory _metadataValues,
    string memory _licenseURI,
    Fee[] memory fees
  ) external returns (uint256) {
    Storage storage ds = libStorage();

    ds._tokenIdCounter.increment();
    uint256 newTokenId = ds._tokenIdCounter.current();

    string[] memory propertyNames = new string[](_metadataValues.length);
    string[] memory propertyValues = new string[](_metadataValues.length);
    bool[] memory modifiables = new bool[](_metadataValues.length);
    for (uint256 i = 0; i < _metadataValues.length; i++) {
      propertyNames[i] = _metadataValues[i][0];
      propertyValues[i] = _metadataValues[i][1];
      modifiables[i] = (keccak256(abi.encodePacked((_metadataValues[i][2]))) == keccak256(abi.encodePacked(('1')))); // 1 is modifiable, 0 is permanent
    }

    Metadata memory _metadata = Metadata({
      tokenName: _tokenData[1],
      tokenDescription: _tokenData[2],
      name: propertyNames,
      value: propertyValues,
      modifiable: modifiables,
      propertyCount: _metadataValues.length
    });

    string[] memory _assets = new string[](1);
    _assets[0] = _tokenData[0];
    ds.tokenData[newTokenId] = TokenData({
      tokenCreator: msg.sender,
      isOnChain: true,
      metadata: _metadata,
      licenseURI: _licenseURI,
      assets: _assets,
      totalVersionCount: 1,
      currentVersion: 1,
      additionalAssets: _additionalAssets
    });

    _registerFees(newTokenId, fees);

    emit TokenMinted(newTokenId, _tokenData[0], msg.sender, block.timestamp);
  }

  function getTokenCreator(uint256 tokenID) public view returns (address) {
    Storage storage ds = libStorage();
    return ds.tokenData[tokenID].tokenCreator;
  }

  function tokenURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = libStorage();
    if (!ds.tokenData[tokenId].isOnChain) {
      return ds.tokenData[tokenId].assets[ds.tokenData[tokenId].currentVersion];
    } else {
      string memory encodedMetadata = '';
      for (uint i = 0; i < ds.tokenData[tokenId].metadata.propertyCount; i++) {
        encodedMetadata = string(abi.encodePacked(
          encodedMetadata,
          '{"trait_type":"',
          ds.tokenData[tokenId].metadata.name[i],
          '", "value":"',
          ds.tokenData[tokenId].metadata.value[i],
          '"}',
          i == ds.tokenData[tokenId].metadata.propertyCount - 1 ? '' : ',')
        );
      }

      string memory encoded = string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                ds.tokenData[tokenId].metadata.tokenName,
                '", "description":"',
                ds.tokenData[tokenId].metadata.tokenDescription,
                '", "image": "',
                ds.tokenData[tokenId].assets[ds.tokenData[tokenId].currentVersion],
                '", "license": "',
                ds.tokenData[tokenId].licenseURI,
                '", "attributes": [',
                encodedMetadata,
                '] }'
              )
            )
          )
        )
      );

      return encoded;
    }
  }

  function _registerFees(uint256 _tokenId, Fee[] memory _fees) internal returns (bool) {
    Storage storage ds = libStorage();
    require(_fees.length <= 5, "No more than 5 recipients");
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
    Storage storage ds = libStorage();
    Fee[] memory _fees = ds.fees[id];
    address payable[] memory result = new address payable[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].recipient;
    }
    return result;
  }

  function getFeeBps(uint256 id) public view returns (uint[] memory) {
    Storage storage ds = libStorage();
    Fee[] memory _fees = ds.fees[id];
    uint[] memory result = new uint[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].value;
    }
    return result;
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount){
    address payable[] memory rec = getFeeRecipients(tokenId);
    require(rec.length <= 1, "More than 1 royalty recipient");

    if (rec.length == 0) return (address(this), 0);
    return (rec[0], getFeeBps(tokenId)[0] * value / 10000);
  }
}