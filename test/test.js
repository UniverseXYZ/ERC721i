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
      await deployInstance.mint(tokenData.isOnChain, 1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees, tokenData.editions);
    });

    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(1);
      expect(data).to.equal(metadata.basic.assets[0][0])
    });

    it("should decrease in royalty", async function() {
      // await ethers.provider.send('evm_setNextBlockTimestamp', [saleStartTime2]);
      // await ethers.provider.send('evm_mine');
      const data = await deployInstance.getFeeBps(1);
      console.log(data);
      console.log(data[1].toNumber());
    });
  });

  describe("ONCHAIN TOKEN TESTS", async function() {
    let version = 8;
    it("should mint one", async function() {
      const tokenData = metadata.large;
      await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees, tokenData.editions);
    });
  
    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(2);
      const tokenJSON = base64toJSON(data);
      console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[6][0])
    });

    it("should return licenseURI", async function() {
      const data = await deployInstance.licenseURI(2);
      expect(data).to.equal(metadata.large.licenseURI)
    });

    it("should return set current version", async function() {
      const data = await deployInstance.getCurrentVersion(2);
      expect(data).to.equal(version)
    });

    // version = 50;
    // it("should return out of bounds version", async function() {
    //   const tokenData = metadata.animation;
    //   expect(await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees)).to.be.reverted;
    // });
  })

  describe("ANIMATION_URL TOKEN TESTS", async function() {
    it("should mint one", async function() {
      const tokenData = metadata.animation;
      await deployInstance.mint(tokenData.isOnChain, 1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees, tokenData.editions);
    });
  })
});
