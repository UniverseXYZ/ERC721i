const { expect } = require("chai");
const { utils } = require('ethers');
const metadata = require('./metadata.json');

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("UniverseSingularity Test", async function() {
  const collectionName = 'Universe Singularity Tokens';
  const collectionSymbol = 'XYZTOKEN';

  const randomWallet1 = ethers.Wallet.createRandom();
  const randomWallet2 = ethers.Wallet.createRandom();
  const feeSplit1 = 1000;
  const feeSplit2 = 500;

  let deployInstance;

  before(async () => {
    const LibStorage = await hre.ethers.getContractFactory("LibStorage");
    const libraryInstance = await LibStorage.deploy();
    await libraryInstance.deployed();

    const UniverseSingularity = await ethers.getContractFactory("UniverseSingularity", {
      libraries: {
        LibStorage: libraryInstance.address
      },
    });

    deployInstance = await UniverseSingularity.deploy(
      collectionName,
      collectionSymbol,
    );
    await deployInstance.deployed();
  });

  it("should mint one basic token", async function() {
    const tokenData = metadata.basic;
    await deployInstance.mint(tokenData.isOnChain, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees);
  });

  it("should return basic tokenURI", async function() {
    const data = await deployInstance.tokenURI(1);
    console.log(data);
  });

  it("should mint one onchain token", async function() {
    const tokenData = metadata.onchain;
    await deployInstance.mint(tokenData.isOnChain, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees);
  });

  it("should return onchain tokenURI", async function() {
    const data = await deployInstance.tokenURI(2);
    const tokenJSON = base64toJSON(data);
    console.log(tokenJSON);
  });
});
