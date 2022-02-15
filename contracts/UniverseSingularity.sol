// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Product by universe.xyz

pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ERC721I.sol";

contract UniverseSingularity is Ownable {
    address[] public deployedContracts;
    address public lastDeployedContractAddress;

    event LogUniverseERC721ContractDeployed(
        string tokenName,
        string tokenSymbol,
        address contractAddress,
        address owner,
        uint256 time
    );

    constructor() {}

    function deployUniverseERC721(string memory tokenName, string memory tokenSymbol)
        external
        returns (address universeERC721Contract)
    {
        ERC721I deployedContract = new ERC721I(tokenName, tokenSymbol);

        // deployedContract.transferOwnership(msg.sender);
        address deployedContractAddress = address(deployedContract);
        deployedContracts.push(deployedContractAddress);
        lastDeployedContractAddress = deployedContractAddress;

        emit LogUniverseERC721ContractDeployed(
            tokenName,
            tokenSymbol,
            deployedContractAddress,
            msg.sender,
            block.timestamp
        );

        return deployedContractAddress;
    }

    function getDeployedContractsCount() external view returns (uint256 count) {
        return deployedContracts.length;
    }
}