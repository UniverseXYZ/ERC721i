// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import 'base64-sol/base64.sol';

/* TODO:
 * Owner protection for writable functions
 * Factory for creator control
 * Change name to ERC721I
 */

contract ERC721ICore {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  address contractAddress;
  address daoAddress;
  bool daoInitialized;

  mapping (uint256 => TokenData) tokenData;
  mapping (uint256 => uint256) editions; // Declares multiple editions for an NFT
  mapping (uint256 => uint256) editionedPointers; // Points to metadata of NFT editions

  Counters.Counter _tokenIdCounter;

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
    string[] assets; // Each asset in array is a version
    string[] assetBackups; // Each backup upload can be toggled as main display asset (e.g. IPFS / ARWEAVE)
    string[] assetTitles; // Title of each core asset (optional)
    string[] assetDescriptions; // Description of each core asset (optional)
    string[] assetTorrentMagnet; // Torrent magnet link (optional)
    uint256 totalVersionCount; // Total number of existing states
    uint256 currentVersion; // Current existing state
    string[] additionalAssets; // Additional assets provided by minter
    string[] additionalAssetsContext; // Short text context per asset
    string iFrameAsset;
  }

  constructor(address _contractAddress) {
    contractAddress = _contractAddress;
  }

  modifier onlyContract() {
    require(msg.sender == contractAddress, "Wrong address");
    _;
  }

  modifier onlyDAO() {
    require(msg.sender == daoAddress, "Wrong address");
    _;
  }

  function getDAOAddress() public view returns (address) {
    return daoAddress;
  }

  function setDAOAddress(address payable _daoAddress) public onlyDAO() {
    daoAddress = _daoAddress;
    daoInitialized = true;
  }

  function getTokenCounter() public view returns (uint256) {
    return _tokenIdCounter.current();
  }

  function tokenCounterIncrement() public onlyContract() {
    _tokenIdCounter.increment();
  }

  function getTokenData(uint256 _tokenId) public view returns (TokenData memory) {
    return tokenData[_tokenId];
  }

  function mint(
    uint256 _currentVersion,
    string[][] memory _assets, // ordered lists: [0: [main assets], 1: [backup assets], 2: [asset titles], 3: [asset descriptions], 4: [additional assets], 5: [text context], 6: [token name, desc], 7: [iFrame asset (optional)]]
    string[][] memory _metadataValues,
    string memory _licenseURI,
    uint256 _editions
  ) external {
    require(
      _assets[1].length == _assets[2].length &&
      _assets[2].length == _assets[3].length &&
      _assets[3].length == _assets[4].length &&
      _assets[4].length == _assets[5].length,
      "Invalid assets provided"
    );
    require(_currentVersion <= _assets[1].length, "Default version out of bounds");

    _tokenIdCounter.increment();
    uint256 newTokenId = _tokenIdCounter.current();
    editions[newTokenId] = _editions;

    Metadata memory metadata;
    require (_metadataValues[0].length == _metadataValues[1].length, "Invalid metadata provided");

    uint256 propertyCount = _metadataValues[0].length;
    bool[] memory modifiables = new bool[](_metadataValues.length);
    for (uint256 i = 0; i < propertyCount; i++) {
      modifiables[i] = (keccak256(abi.encodePacked((_metadataValues[2][i]))) == keccak256(abi.encodePacked(('1')))); // 1 is modifiable, 0 is permanent
    }

    metadata = Metadata({
      tokenName: _assets[0][0],
      tokenDescription: _assets[0][1],
      name: (_metadataValues[1].length > 0) ? _metadataValues[1] : new string[](0),
      value: (_metadataValues[2].length > 0) ? _metadataValues[2] : new string[](0),
      modifiable: modifiables,
      propertyCount: propertyCount
    });

    string memory _iFrameAsset = (_assets[8].length == 1) ? _assets[8][0] : "";
    tokenData[newTokenId] = TokenData({
      tokenCreator: msg.sender,
      metadata: metadata,
      licenseURI: _licenseURI,
      assets: _assets[1],
      assetBackups: _assets[2],
      assetTitles: _assets[3],
      assetDescriptions: _assets[4],
      assetTorrentMagnet: _assets[5],
      additionalAssets: (_assets[6].length > 0) ? _assets[6] : new string[](0),
      additionalAssetsContext: (_assets[7].length > 0) ? _assets[7] : new string[](0),
      iFrameAsset: _iFrameAsset,
      totalVersionCount: _assets[1].length,
      currentVersion: _currentVersion
    });

    for (uint256 i = 0; i < _editions; i++) {
      editionedPointers[newTokenId + i] = newTokenId;
    }
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    return tokenData[tokenId].tokenCreator;
  }

  function addAsset(uint256 tokenId, string[] memory assetData) public {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, 'Only creator of token can add new asset version');
    tokenData[tokenIdentifier].assets.push(assetData[0]);
    tokenData[tokenIdentifier].assetBackups.push(assetData[1]);
    tokenData[tokenIdentifier].assetTitles.push(assetData[2]);
    tokenData[tokenIdentifier].assetDescriptions.push(assetData[3]);
    tokenData[tokenIdentifier].assetTorrentMagnet.push(assetData[4]);
    tokenData[tokenIdentifier].totalVersionCount++;
  }

  function bulkAddAsset(uint256 tokenId, string[][] memory assetData) external {
    for (uint i = 0; i < assetData.length; i++) {
      addAsset(tokenId, assetData[i]);
    }
  }

  function addSecondaryAsset(uint256 tokenId, string[] memory assetData) public {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, 'Only creator of token can add new asset version');
    tokenData[tokenIdentifier].additionalAssets.push(assetData[0]);
    tokenData[tokenIdentifier].additionalAssetsContext.push(assetData[1]);
  }

  function bulkAddSecondaryAsset(uint256 tokenId, string[][] memory assetData) external {
    for (uint i = 0; i < assetData.length; i++) {
      addSecondaryAsset(tokenId, assetData[i]);
    }
  }

  function changeVersion(uint256 tokenId, uint256 version) public {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, 'Only creator can change asset version');
    require(version <= tokenData[tokenIdentifier].totalVersionCount, 'Out of version bounds');
    require(version >= 1, 'Out of version bounds');
    tokenData[tokenIdentifier].currentVersion = version;
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    return tokenData[tokenIdentifier].currentVersion;
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) external {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    require(tokenData[tokenIdentifier].metadata.modifiable[propertyIndex - 1], 'Field not editable');
    require(propertyIndex <= tokenData[tokenIdentifier].metadata.propertyCount, 'Out of version bounds');
    require(propertyIndex >= 1, 'Out of version bounds');
    tokenData[tokenIdentifier].metadata.value[propertyIndex - 1] = value;
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    return tokenData[tokenIdentifier].licenseURI;
  }

  function updateTorrentMagnet(uint256 tokenId, uint256 assetIndex, string memory uri) external {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
    require(getTokenCreator(tokenIdentifier) == msg.sender, 'Only creator can update');
    require(assetIndex <= tokenData[tokenIdentifier].totalVersionCount, 'Out of version bounds');
    require(assetIndex >= 1, 'Out of version bounds');
    tokenData[tokenIdentifier].assetTorrentMagnet[assetIndex - 1] = uri;
  }

  function tokenURI(uint256 tokenId) public view returns (string memory) {
    uint256 tokenIdentifier = (editionedPointers[tokenId] > 0) ? editionedPointers[tokenId] : tokenId;
      string memory encodedMetadata = '';
      for (uint i = 0; i < tokenData[tokenIdentifier].metadata.propertyCount; i++) {
        encodedMetadata = string(abi.encodePacked(
          encodedMetadata,
          '{"trait_type":"',
          tokenData[tokenIdentifier].metadata.name[i],
          '", "value":"',
          tokenData[tokenIdentifier].metadata.value[i],
          '", "permanent":"',
          tokenData[tokenIdentifier].metadata.modifiable[i] ? 'false' : 'true',
          '"}',
          i == tokenData[tokenIdentifier].metadata.propertyCount - 1 ? '' : ',')
        );
      }

      string memory assetsList = '';
      for (uint i = 0; i < tokenData[tokenIdentifier].assets.length; i++) {
        assetsList = string(abi.encodePacked(
          assetsList,
          '{"name":"',
          tokenData[tokenIdentifier].assetTitles[i],
          '", "description":"',
          tokenData[tokenIdentifier].assetDescriptions[i],
          '", "primary_asset":"',
          tokenData[tokenIdentifier].assets[i],
          '", "backup_asset":"',
          tokenData[tokenIdentifier].assetBackups[i],
          '", "torrent":"',
          tokenData[tokenIdentifier].assetTorrentMagnet[i],
          '", "default":"',
          i == tokenData[tokenIdentifier].currentVersion - 1 ? 'true' : 'false',
          '"}',
          i == tokenData[tokenIdentifier].assets.length - 1 ? '' : ',')
        );
      }

      string memory additionalAssetsList = '';
      for (uint i = 0; i < tokenData[tokenIdentifier].additionalAssets.length; i++) {
        additionalAssetsList = string(abi.encodePacked(
          additionalAssetsList,
          '{"context":"',
          tokenData[tokenIdentifier].additionalAssetsContext[i],
          '", "asset":"',
          tokenData[tokenIdentifier].additionalAssets[i],
          '"}',
          i == tokenData[tokenIdentifier].additionalAssets.length - 1 ? '' : ',')
        );
      }

      string memory animationAsset = "";
      if (keccak256(abi.encodePacked(tokenData[tokenIdentifier].iFrameAsset)) != keccak256(abi.encodePacked(""))) {
        animationAsset = string(abi.encodePacked(', "animation_url": "', tokenData[tokenIdentifier].iFrameAsset, '"'));
      }

      string memory encoded = string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                tokenData[tokenIdentifier].metadata.tokenName,
                '", "description":"',
                tokenData[tokenIdentifier].metadata.tokenDescription,
                '", "image": "',
                tokenData[tokenIdentifier].assets[tokenData[tokenIdentifier].currentVersion - 1],
                '", "license": "',
                tokenData[tokenIdentifier].licenseURI,
                '", "attributes": [',
                encodedMetadata,
                ']',
                ', "assets": [',
                assetsList,
                ']',
                ', "additional_assets": [',
                additionalAssetsList,
                ']',
                animationAsset,
                '}'
              )
            )
          )
        )
      );

      return encoded;
  }

  function withdraw(address _to, uint amount) public onlyDAO {
    payable(_to).call{value:amount, gas:200000}("");
  }
}