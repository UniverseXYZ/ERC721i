// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC721Consumable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/IERC721i.sol";
import "./ERC721iCore.sol";

contract ERC721i is ERC165, ERC721Consumable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  function initialize(string memory name, string memory symbol) public initializer {
    __ERC721_init(name, symbol);
    ERC721iCore.Storage storage ds = ERC721iCore.ERC721iStorage();
    ds.singularityAddress = address(this);
    ds.daoAddress = payable(msg.sender);
  }

  bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;
  bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, ERC721Consumable) returns (bool) {
    return interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE || interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 || super.supportsInterface(interfaceId);
  }

  modifier onlyDAO() {
    ERC721iCore.Storage storage ds = ERC721iCore.ERC721iStorage();
    require(msg.sender == ds.daoAddress, "Wrong address");
    _;
  }

  function transferDAOownership(address payable _daoAddress) public onlyDAO {
    ERC721iCore.Storage storage ds = ERC721iCore.ERC721iStorage();
    ds.daoAddress = _daoAddress;
    ds.daoInitialized = true;
  }

  function mint(
    uint256 _currentVersion,
    string[][] memory _assets,
    string[][] memory _metadataValues,
    string memory _licenseURI,
    string memory _externalURL,
    ERC721iCore.Fee[] memory _fees,
    uint256 _editions,
    bool _editioned,
    address _mintTo
  ) public {
    ERC721iCore.Storage storage ds = ERC721iCore.ERC721iStorage();
    require(_assets.length == 9, 'Invalid parameters');

    ERC721iCore.mint(_currentVersion, _assets, _metadataValues, _licenseURI, _externalURL, _fees, _editions, _editioned);

    address to = address(_mintTo) == address(0) ? msg.sender : _mintTo;
    for (uint256 i = 0; i < _editions; i++) {
      uint256 newTokenId = ds._tokenIdCounter.current();
      _mint(to, newTokenId);
      if (i != (_editions - 1)) ds._tokenIdCounter.increment();
    }
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.ERC721iStorage().tokenData[tokenId].tokenCreator;
  }

  function addAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.addAsset(tokenId, assetData);
  }

  function bulkAddAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.bulkAddAsset(tokenId, assetData);
  }

  function addSecondaryAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.addSecondaryAsset(tokenId, assetData);
  }

  function bulkAddSecondaryAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.bulkAddSecondaryAsset(tokenId, assetData);
  }

  function changeVersion(uint256 tokenId, uint256 version) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.changeVersion(tokenId, version);
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.getCurrentVersion(tokenId);
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.updateMetadata(tokenId, propertyIndex, value);
  }

  function updateExternalURL(uint256 tokenId, string memory url) public {
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.updateExternalURL(tokenId, url);
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.licenseURI(tokenId);
  }

  function updateTorrentMagnet(uint256 tokenId, uint256 assetIndex, string memory uri) public { 
    require(_exists(tokenId), "Nonexistent token");
    ERC721iCore.updateTorrentMagnet(tokenId, assetIndex, uri);
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.tokenURI(tokenId);
  }

  function getFeeRecipients(uint256 tokenId) public view returns (address payable[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.getFeeRecipients(tokenId);
  }

  function getFeeBps(uint256 tokenId) public view returns (uint[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.getFeeBps(tokenId);
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount){
    require(_exists(tokenId), "Nonexistent token");
    return ERC721iCore.royaltyInfo(tokenId, value);
  }

  // Failsafe withdraw if any ETH is sent to contract
  function withdraw(address _to, uint amount) public onlyDAO {
    (bool success, ) = payable(_to).call{value:amount, gas:200000}("");
    require(success, "Withdraw failed");
  }

  // Failsafe withdraw if any ERC20 is sent to contract
  function withdrawERC20(uint256 amount, address tokenAddress) public onlyDAO {
    ERC721iCore.Storage storage ds = ERC721iCore.ERC721iStorage();
    IERC20 token = IERC20(tokenAddress);
    uint256 erc20balance = token.balanceOf(address(this));
    require(amount <= erc20balance, "balance is low");
    token.transfer(ds.daoAddress, amount);
  }
}