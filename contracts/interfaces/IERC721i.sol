// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity 0.8.11;

import "../ERC721iCore.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title Creators can mint robust NFTs that have multiple assets, on-chain metadata, and dynamic royalties
/// @notice This interface should be implemented by the UniverseSingularity contract
/// @dev This interface should be implemented by the UniverseSingularity contract
interface IERC721i is IERC721Enumerable {

  /// @notice Transfers contract ownership to DAO / different address
  /// @param _daoAddress The new address
  function transferDAOownership(address payable _daoAddress) external;

  /// @notice Creates a new collection / drop (first collection is created via constructor)
  /// @param _currentVersion Index (starting from 1) of default asset to show
  /// @param _assets Asset data [[main assets], [backup assets], [asset titles], [asset descriptions], [additional assets], [text context]]
  /// @param _metadataValues Property values
  /// @param _licenseURI License URI of NFT
  /// @param _fees Royalty parameters [[address, variable type, start BPS, end BPS, start blocktime, end blocktime]]
  /// above variable types: 0 - no decay, 1 - linear, 2 - timestamp change / expiration
  /// @param _editions Number of identical NFTs to mint
  function mint(
    uint256 _currentVersion,
    string[][] memory _assets,
    string[][] memory _metadataValues,
    string memory _licenseURI,
    string memory _externalURL,
    ERC721iCore.Fee[] memory _fees,
    uint256 _editions
  ) external returns (uint256);

  /// @notice Returns creator address of NFT
  /// @param tokenId NFT token ID 
  function getTokenCreator(uint256 tokenId) external view returns (address);

  /// @notice Allows creator of NFT to add an asset
  /// @param tokenId NFT token ID
  /// @param assetData Asset data [main asset, backup asset, asset title, asset description]
  function addAsset(uint256 tokenId, string[] memory assetData) external;

  /// @notice Allows creator of NFT to add multiple assets
  /// @param tokenId NFT token ID
  /// @param assetData Asset data [[main asset, backup asset, asset title, asset description], ...]
  function bulkAddAsset(uint256 tokenId, string[][] memory assetData) external;

  /// @notice Allows creator of NFT to add another secondary asset
  /// @param tokenId NFT token ID
  /// @param assetData Asset data [asset, asset context]
  function addSecondaryAsset(uint256 tokenId, string[] memory assetData) external;

  /// @notice Allows creator of NFT to add multiple secondary assets
  /// @param tokenId NFT token ID
  /// @param assetData Asset data [[asset, asset context], ...]
  function bulkAddSecondaryAsset(uint256 tokenId, string[][] memory assetData) external;

  /// @notice Allows creator or owner of NFT to change default displaying asset
  /// @param tokenId NFT token ID
  /// @param version Index of asset (starting at 1)
  function changeVersion(uint256 tokenId, uint256 version) external;

  /// @notice Returns index of currently displaying default asset
  /// @param tokenId NFT token ID
  function getCurrentVersion(uint256 tokenId) external view returns (uint256);

  /// @notice Allows creator to update metadata property if marked as changeable
  /// @param tokenId NFT token ID
  /// @param propertyIndex Index of metadata property
  /// @param value New value of metadata property
  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) external;

  /// @notice Allows creator to update metadata property if marked as changeable
  /// @param tokenId NFT token ID
  /// @param url New value of external url
  function updateExternalURL(uint256 tokenId, string memory url) external;

  /// @notice Returns URI of license of NFT
  /// @param tokenId NFT token ID
  function licenseURI(uint256 tokenId) external view returns (string memory);

  /// @notice Allows creator or owner of NFT to set a torrent magnet link
  /// @param tokenId NFT token ID
  /// @param assetIndex Index of asset (starting at 1)
  /// @param uri Torrent magnet link
  function updateTorrentMagnet(uint256 tokenId, uint256 assetIndex, string memory uri) external;

  /// @notice (If on-chain) Returns base64 encoded JSON of full metadata (else) returns URI
  /// @param tokenId NFT token ID
  function tokenURI(uint256 tokenId) external view returns (string memory);

  /// @notice Returns addresses of secondary sale fees (Rarible Royalties Standard)
  /// @param tokenId NFT/Token ID number
  function getFeeRecipients(uint256 tokenId) external view returns (address payable[] memory);

  /// @notice Returns basis point values of secondary sale fees (Rarible Royalties Standard) and is dynamic
  /// @param tokenId NFT/Token ID number
  function getFeeBps(uint256 tokenId) external view returns (uint[] memory);

  /// @notice Returns address and value of secondary sale fee (EIP-2981 royalties standard) and is dynamic
  /// @param tokenId NFT/Token ID number
  /// @param value ETH/ERC20 value to calculate from
  function royaltyInfo(uint256 tokenId, uint256 value) external view returns (address recipient, uint256 amount);
}