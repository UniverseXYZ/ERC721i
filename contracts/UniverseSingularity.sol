// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "./IUniverseSingularity.sol";
import "./LibStorage.sol";

contract UniverseSingularity is ERC165, ERC721 {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    LibStorage.Storage storage ds = LibStorage.libStorage();
    ds.singularityAddress = address(this);
    ds.daoAddress = msg.sender;
  }

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
    bool _isOnChain,
    uint256 _currentVersion,
    string[][] memory _assets, // ordered lists: [[main assets], [backup assets], [asset titles], [asset descriptions], [additional assets], [text context]]
    string[][] memory _metadataValues,
    string memory _licenseURI,
    LibStorage.Fee[] memory _fees,
    uint256 _editions
  ) public returns (uint256) {
    LibStorage.Storage storage ds = LibStorage.libStorage();
    require(_assets.length == 8, 'Invalid parameters');

    LibStorage.mint(_isOnChain, _currentVersion, _assets, _metadataValues, _licenseURI, _fees, _editions);

    for (uint256 i = 0; i < _editions; i++) {
      uint256 newTokenId = ds._tokenIdCounter.current();
      _mint(msg.sender, newTokenId);
      if (i != (_editions - 1)) ds._tokenIdCounter.increment();
    }
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.libStorage().tokenData[tokenId].tokenCreator;
  }

  function addAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.addAsset(tokenId, assetData);
  }

  function bulkAddAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.bulkAddAsset(tokenId, assetData);
  }

  function addSecondaryAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.addSecondaryAsset(tokenId, assetData);
  }

  function bulkAddSecondaryAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.bulkAddSecondaryAsset(tokenId, assetData);
  }

  function changeVersion(uint256 tokenId, uint256 version) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.changeVersion(tokenId, version);
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.getCurrentVersion(tokenId);
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) public {
    require(_exists(tokenId), "Nonexistent token");
    LibStorage.updateMetadata(tokenId, propertyIndex, value);
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
    return LibStorage.licenseURI(tokenId);
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
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

  // Failsafe withdraw if any ETH is sent to contract
  function withdraw(address _to, uint amount) public onlyDAO {
    payable(_to).call{value:amount, gas:200000}("");
  }

  // Failsafe withdraw if any ERC20 is sent to contract
  function withdrawERC20(uint256 amount, address tokenAddress) public onlyDAO {
    LibStorage.Storage storage ds = LibStorage.libStorage();
    IERC20 token = IERC20(tokenAddress);
    uint256 erc20balance = token.balanceOf(address(this));
    require(amount <= erc20balance, "balance is low");
    token.transfer(ds.daoAddress, amount);
  }
}