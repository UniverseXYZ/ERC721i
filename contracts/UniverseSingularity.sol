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
import "./DynamicRoyalties.sol";
import "./IUniverseSingularity.sol";
import "./ERC721I.sol";

contract UniverseSingularity is ERC165, ERC721 {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  ERC721I erc721i;
  DynamicRoyalties royalties;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    erc721i = new ERC721I(address(this));
    royalties = new DynamicRoyalties(address(this));
  }

  bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;
  bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
    return interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE || interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 || super.supportsInterface(interfaceId);
  }

  event TokenMinted(
    uint256 tokenId,
    string tokenURI,
    address receiver,
    uint256 time
  );

  modifier onlyDAO() {
    require(msg.sender == erc721i.getDAOAddress(), "Wrong address");
    _;
  }

  function transferDAOownership(address payable _daoAddress) public onlyDAO {
    erc721i.setDAOAddress(_daoAddress);
  }

  function mint(
    uint256 _currentVersion,
    string[][] memory _assets, // ordered lists: [[main assets], [backup assets], [asset titles], [asset descriptions], [additional assets], [text context]]
    string[][] memory _metadataValues,
    string memory _licenseURI,
    DynamicRoyalties.Fee[] memory _fees,
    uint256 _editions
  ) public returns (uint256) {
    
    require(_assets.length == 9, 'Invalid parameters');

    erc721i.mint(_currentVersion, _assets, _metadataValues, _licenseURI, _editions);

    for (uint256 i = 0; i < _editions; i++) {
      uint256 newTokenId = erc721i.getTokenCounter();
      royalties._registerFees(newTokenId, _fees);
      console.log('REGISTERING');
      console.log(newTokenId);
      _mint(msg.sender, newTokenId);
      emit TokenMinted(newTokenId, _assets[0][0], msg.sender, block.timestamp);
      if (i != (_editions - 1)) erc721i.tokenCounterIncrement();
    }
  }

  function getTokenCreator(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId), "Nonexistent token");
    return erc721i.getTokenData(tokenId).tokenCreator;
  }

  function addAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.addAsset(tokenId, assetData);
  }

  function bulkAddAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.bulkAddAsset(tokenId, assetData);
  }

  function addSecondaryAsset(uint256 tokenId, string[] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.addSecondaryAsset(tokenId, assetData);
  }

  function bulkAddSecondaryAsset(uint256 tokenId, string[][] memory assetData) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.bulkAddSecondaryAsset(tokenId, assetData);
  }

  function changeVersion(uint256 tokenId, uint256 version) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.changeVersion(tokenId, version);
  }

  function getCurrentVersion(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "Nonexistent token");
    return erc721i.getCurrentVersion(tokenId);
  }

  function updateMetadata(uint256 tokenId, uint256 propertyIndex, string memory value) public {
    require(_exists(tokenId), "Nonexistent token");
    erc721i.updateMetadata(tokenId, propertyIndex, value);
  }

  function licenseURI(uint256 tokenId) public view returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
    return erc721i.licenseURI(tokenId);
  }

  function updateTorrentMagnet(uint256 tokenId, uint256 assetIndex, string memory uri) public { 
    require(_exists(tokenId), "Nonexistent token");
    erc721i.updateTorrentMagnet(tokenId, assetIndex, uri);
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "Nonexistent token");
    return erc721i.tokenURI(tokenId);
  }

  function getFeeRecipients(uint256 tokenId) public view returns (address payable[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return royalties.getFeeRecipients(tokenId);
  }

  function getFeeBps(uint256 tokenId) public view returns (uint[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return royalties.getFeeBps(tokenId);
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount){
    require(_exists(tokenId), "Nonexistent token");
    return royalties.royaltyInfo(tokenId, value);
  }

  // Failsafe withdraw if any ETH is sent to contract
  function withdraw(address _to, uint amount) public onlyDAO {
    payable(_to).call{value:amount, gas:200000}("");
  }

  // Failsafe withdraw if any ERC20 is sent to contract
  function withdrawERC20(uint256 amount, address tokenAddress) public onlyDAO {
    
    IERC20 token = IERC20(tokenAddress);
    uint256 erc20balance = token.balanceOf(address(this));
    require(amount <= erc20balance, "balance is low");
    token.transfer(erc721i.getDAOAddress(), amount);
  }
}