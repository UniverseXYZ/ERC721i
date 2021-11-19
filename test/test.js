const { expect } = require("chai");
const { utils } = require('ethers');
const metadata = require('./metadata.json');

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("UniverseSingularity", async function() {
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
  
  describe("BASIC TOKEN TESTS", async function() {
    it("should mint one", async function() {
      const tokenData = metadata.basic;
      await deployInstance.mint(tokenData.isOnChain, 1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees);
    });

    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(1);
      expect(data).to.equal(metadata.basic.assets[0][0])
    });
  });

  describe("ONCHAIN TOKEN TESTS", async function() {
    const version = 8;
    it("should mint one", async function() {
      const tokenData = metadata.large;
      await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees);
    });
  
    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(2);
      const tokenJSON = base64toJSON(data);
      console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[5][0])
    });

    it("should return licenseURI", async function() {
      const data = await deployInstance.licenseURI(2);
      expect(data).to.equal(metadata.large.licenseURI)
    });

    it("should return set current version", async function() {
      const data = await deployInstance.getCurrentVersion(2);
      expect(data).to.equal(version)
    });
  })
});
