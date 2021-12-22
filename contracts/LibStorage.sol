// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "hardhat/console.sol";
import 'base64-sol/base64.sol';

/* TODO:
 * Animation URI (fix tokenURI)
 * Bulk add assets post-mint (?)
 * Owner protection for writable functions
 * Factory for creator control
 * Multiple token IDs pointing to same metadata saving gas costs (DONE)
 * Time-decreasing royalties
 */

library LibStorage {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  bytes32 constant STORAGE_POSITION = keccak256("com.universe.singularity.storage");

  struct Fee {
    address payable recipient;
    uint256 value;
    uint256 decayType; // 0: no decay, 1: linear, 2: timestamp reduction / expiration
    uint256 endValue;
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
    bool isOnChain; // Flag for onchain token data
    Metadata metadata;
    string licenseURI; // Usage rights for token
    string[] assets; // Each asset in array is a version
    string[] assetBackups; // Each backup upload can be toggled as main display asset (e.g. IPFS / ARWEAVE)
    string[] assetTitles; // Title of each core asset (optional)
    string[] assetDescriptions; // Description of each core asset (optional)
    uint256 totalVersionCount; // Total number of existing states
    uint256 currentVersion; // Current existing state
    string[] additionalAssets; // Additional assets provided by minter
    string[] additionalAssetsContext; // Short text context per asset
    string iframeAsset;
  }

  struct Storage {
    address singularityAddress;
    address payable daoAddress;
    bool daoInitialized;
    mapping (uint256 => Fee[]) fees;
    mapping (uint256 => TokenData) tokenData;
    mapping (uint256 => uint256) editions; // Declares multiple editions for an NFT
    mapping (uint256 => uint256) editionedPointers; // Points to metadata of NFT editions

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
    bool _isOnChain,
    uint256 _currentVersion,
    string[][] memory _assets, // ordered lists: [0: [main assets], 1: [backup assets], 2: [asset titles], 3: [asset descriptions], 4: [additional assets], 5: [text context], 6: [token name, desc], 7: [iFrame asset (optional)]]
    string[][] memory _metadataValues,
    string memory _licenseURI,
    Fee[] memory _fees,
    uint256 _editions
  ) external returns (uint256) {
    require(_assets[0].length == _assets[1].length && _assets[1].length == _assets[2].length && _assets[2].length == _assets[3].length && _assets[4].length == _assets[5].length, "Invalid assets provided");
    require(_currentVersion <= _assets[0].length, "Default version out of bounds");
    Storage storage ds = libStorage();

    ds._tokenIdCounter.increment();
    uint256 newTokenId = ds._tokenIdCounter.current();
    ds.editions[newTokenId] = _editions;

    Metadata memory metadata;
    if (_isOnChain) {
      require (_metadataValues[0].length == _metadataValues[1].length, "Invalid metadata provided");

      uint256 propertyCount = _metadataValues[0].length;
      bool[] memory modifiables = new bool[](_metadataValues.length);
      for (uint256 i = 0; i < propertyCount; i++) {
        modifiables[i] = (keccak256(abi.encodePacked((_metadataValues[2][i]))) == keccak256(abi.encodePacked(('1')))); // 1 is modifiable, 0 is permanent
      }

      metadata = Metadata({
        tokenName: _assets[6][0],
        tokenDescription: _assets[6][1],
        name: (_metadataValues[0].length > 0) ? _metadataValues[0] : new string[](0),
        value: (_metadataValues[1].length > 0) ? _metadataValues[1] : new string[](0),
        modifiable: modifiables,
        propertyCount: propertyCount
      });
    } else {
      metadata = Metadata({
        tokenName: '',
        tokenDescription: '',
        name: new string[](0),
        value: new string[](0),
        modifiable: new bool[](0),
        propertyCount: 0
      });
    }

    string memory _iframeAsset = (_assets[7].length == 1) ? _assets[7][0] : "";
    ds.tokenData[newTokenId] = TokenData({
      tokenCreator: msg.sender,
      isOnChain: _isOnChain,
      metadata: metadata,
      licenseURI: _licenseURI,
      assets: _assets[0],
      assetBackups: _assets[1],
      assetTitles: _assets[2],
      assetDescriptions: _assets[3],
      additionalAssets: _assets[4],
      additionalAssetsContext: _assets[5],
      iframeAsset: _iframeAsset,
      totalVersionCount: _assets[0].length,
      currentVersion: _currentVersion
    });

    for (uint256 i = 1; i < _editions; i++) {
      ds.editionedPointers[newTokenId + i] = newTokenId;
      _registerFees(newTokenId + i, _fees);
      emit TokenMinted(newTokenId + i, _assets[0][0], msg.sender, block.timestamp);
    }
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    Storage storage ds = libStorage();
    return ds.tokenData[tokenId].tokenCreator;
  }

  function updateAsset(uint256 tokenId, string memory asset) external {
    Storage storage ds = libStorage();
    require(getTokenCreator(tokenId) == msg.sender, 'Only creator of token can add new asset version');
    ds.tokenData[tokenId].assets[ds.tokenData[tokenId].assets.length] = asset;
    ds.tokenData[tokenId].totalVersionCount++;
    ds.tokenData[tokenId].currentVersion = ds.tokenData[tokenId].totalVersionCount;
  }

  function changeVersion(uint256 tokenId, uint256 version) external {
    Storage storage ds = libStorage();
    ERC721 singularity = ERC721(ds.singularityAddress);
    require(singularity.ownerOf(tokenId) == msg.sender || getTokenCreator(tokenId) == msg.sender, 'Only creator and owner can change asset');
    require(version <= ds.tokenData[tokenId].totalVersionCount, 'Out of version bounds');
    require(version >= 1, 'Out of version bounds');
    ds.tokenData[tokenId].currentVersion = version;
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    Storage storage ds = libStorage();
    return ds.tokenData[tokenId].currentVersion;
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) external {
    Storage storage ds = libStorage();
    require(ds.tokenData[tokenId].metadata.modifiable[propertyIndex], 'Field not editable');
    ds.tokenData[tokenId].metadata.value[propertyIndex] = value;
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = libStorage();
    return ds.tokenData[tokenId].licenseURI;
  }

  function tokenURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = libStorage();

    uint256 tokenIdentifier = (ds.editionedPointers[tokenId] > 0) ? ds.editionedPointers[tokenId] : tokenId;

    if (!ds.tokenData[tokenIdentifier].isOnChain) {
      return ds.tokenData[tokenIdentifier].assets[ds.tokenData[tokenIdentifier].currentVersion - 1];
    } else {
      string memory encodedMetadata = '';
      for (uint i = 0; i < ds.tokenData[tokenIdentifier].metadata.propertyCount; i++) {
        encodedMetadata = string(abi.encodePacked(
          encodedMetadata,
          '{"trait_type":"',
          ds.tokenData[tokenIdentifier].metadata.name[i],
          '", "value":"',
          ds.tokenData[tokenIdentifier].metadata.value[i],
          '"}',
          i == ds.tokenData[tokenIdentifier].metadata.propertyCount - 1 ? '' : ',')
        );
      }

      string memory encoded = string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                ds.tokenData[tokenIdentifier].metadata.tokenName,
                '", "description":"',
                ds.tokenData[tokenIdentifier].metadata.tokenDescription,
                '", "image": "',
                ds.tokenData[tokenIdentifier].assets[ds.tokenData[tokenIdentifier].currentVersion - 1],
                '", "license": "',
                ds.tokenData[tokenIdentifier].licenseURI,
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

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount) {
    address payable[] memory rec = getFeeRecipients(tokenId);
    require(rec.length <= 1, "More than 1 royalty recipient");

    if (rec.length == 0) return (address(this), 0);
    return (rec[0], getFeeBps(tokenId)[0] * value / 10000);
  }

  function withdraw(address _to, uint amount) public onlyDAO {
    payable(_to).call{value:amount, gas:200000}("");
  }
}