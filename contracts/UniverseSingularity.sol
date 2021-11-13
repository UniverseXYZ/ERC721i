// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "./LibStorage.sol";

contract UniverseSingularity is ERC165, ERC721 {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;
  bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
    return interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE || interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 || super.supportsInterface(interfaceId);
  }

  modifier onlyDAO() {
    LibStorage.Storage storage ds = LibStorage.libStorage();
    require(msg.sender == ds.daoAddress, "Wrong address");
    _;
  }

  function transferDAOownership(address payable _daoAddress) public onlyDAO {
    LibStorage.Storage storage ds = LibStorage.libStorage();
    ds.daoAddress = _daoAddress;
    ds.daoInitialized = true;
  }

  function mint(
    string memory _tokenURI,
    string[] memory _additionalAssets,
    string memory _licenseURI,
    LibStorage.Fee[] memory _fees
  ) public returns (uint256) {
    LibStorage.Storage storage ds = LibStorage.libStorage();

    LibStorage.mint(_tokenURI, _additionalAssets, _licenseURI, _fees);

    uint256 newTokenId = ds._tokenIdCounter.current();
    _mint(msg.sender, newTokenId);
  }

  /* tokenData:
  *  string memory _tokenURI,
  *  string memory _tokenName,
  *  string memory _tokenDescription,
  */
  function mintOnChain(
    string[] memory _tokenData,
    string[] memory _additionalAssets,
    string[][] memory _metadataValues,
    string memory _licenseURI,
    LibStorage.Fee[] memory _fees
  ) public returns (uint256) {
    LibStorage.Storage storage ds = LibStorage.libStorage();

    LibStorage.mintOnChain(_tokenData, _additionalAssets, _metadataValues, _licenseURI, _fees);

    uint256 newTokenId = ds._tokenIdCounter.current();
    _mint(msg.sender, newTokenId);
  }

  function getTokenCreator(uint256 tokenID) public view returns (address) {
    return LibStorage.libStorage().tokenData[tokenID].tokenCreator;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return LibStorage.tokenURI(tokenId);
  }

  function getFeeRecipients(uint256 tokenId) public view returns (address payable[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.getFeeRecipients(tokenId);
  }

  function getFeeBps(uint256 tokenId) public view returns (uint[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.getFeeBps(tokenId);
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount){
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.royaltyInfo(tokenId, value);
  }
}