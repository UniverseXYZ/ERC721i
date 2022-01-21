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

  let tokenIdCounter = 0;

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
      tokenIdCounter++;
    });

    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(tokenIdCounter);
      expect(data).to.equal(metadata.basic.assets[0][0])
    });

    it("should decrease in royalty", async function() {
      // await ethers.provider.send('evm_setNextBlockTimestamp', [saleStartTime2]);
      // await ethers.provider.send('evm_mine');
      const data = await deployInstance.getFeeBps(tokenIdCounter);
    });
  });

  describe("ANIMATION_URL TOKEN TESTS", async function() {
    it("should mint one", async function() {
      const tokenData = metadata.animation;
      await deployInstance.mint(tokenData.isOnChain, 1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees, tokenData.editions);
      tokenIdCounter++;
      const data = await deployInstance.tokenURI(2);
      const tokenJSON = base64toJSON(data);
      console.log(tokenJSON);
    });
  })

  describe("ONCHAIN TOKEN TESTS", async function() {
    let version = 8;
    it("should mint one", async function() {
      const tokenData = metadata.large;
      await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees, tokenData.editions);
    });
  
    it("should return tokenURI", async function() {
      tokenIdCounter++;
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[6][0])
    });

    it("should mint 50 editions", async function() {
      tokenIdCounter += 49;
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[6][0])
    });

    it("should return licenseURI", async function() {
      const data = await deployInstance.licenseURI(tokenIdCounter);
      expect(data).to.equal(metadata.large.licenseURI)
    });

    it("should return set current version", async function() {
      const data = await deployInstance.getCurrentVersion(tokenIdCounter);
      expect(data).to.equal(version)
    });

    it("should add asset", async function() {
      const assetData = [
        'https://arweave.net/newAsset',
        'https://arweave.net/newAssetBackup',
        'New Asset Title',
        'New Asset Description'
      ]
      await deployInstance.addAsset(tokenIdCounter, assetData);
      let data = await deployInstance.tokenURI(tokenIdCounter - 5);
      let tokenJSON = base64toJSON(data);
      let lastAsset = tokenJSON.assets[tokenJSON.assets.length - 1];
      expect(lastAsset.name).to.equal('New Asset Title')

      const bulkAssetData = [
        [
          'https://arweave.net/bulkAsset',
          'https://arweave.net/bulkAssetBackup',
          'Bulk Asset Title',
          'Bulk Asset Description'
        ],
        [
          'https://arweave.net/bulkAsset2',
          'https://arweave.net/bulkAssetBackup2',
          'Bulk Asset Title 2',
          'Bulk Asset Description 2'
        ]
      ]

      await deployInstance.bulkAddAsset(tokenIdCounter, bulkAssetData);
      data = await deployInstance.tokenURI(tokenIdCounter - 49);
      tokenJSON = base64toJSON(data);
      lastAsset = tokenJSON.assets[tokenJSON.assets.length - 2];
      expect(lastAsset.name).to.equal('Bulk Asset Title')
      lastAsset = tokenJSON.assets[tokenJSON.assets.length - 1];
      expect(lastAsset.description).to.equal('Bulk Asset Description 2');
    });

    it("should add secondary asset", async function() {
      const assetData = [
        'https://arweave.net/secondaryAssetNew',
        'New Secondary Asset'
      ]
      await deployInstance.addSecondaryAsset(tokenIdCounter, assetData);
      let data = await deployInstance.tokenURI(tokenIdCounter - 7);
      let tokenJSON = base64toJSON(data);
      let lastAsset = tokenJSON.additional_assets[tokenJSON.additional_assets.length - 1];
      expect(lastAsset.asset).to.equal('https://arweave.net/secondaryAssetNew')

      const bulkAssetData = [
        [
          'https://arweave.net/bulkSecondaryAssetNew',
          'New Bulk Secondary Asset'
        ],
        [
          'https://arweave.net/bulkSecondaryAsset2',
          'New Bulk Secondary Asset 2'
        ]
      ]

      await deployInstance.bulkAddSecondaryAsset(tokenIdCounter, bulkAssetData);
      data = await deployInstance.tokenURI(tokenIdCounter - 49);
      tokenJSON = base64toJSON(data);
      lastAsset = tokenJSON.additional_assets[tokenJSON.additional_assets.length - 2];
      expect(lastAsset.asset).to.equal('https://arweave.net/bulkSecondaryAssetNew')
      lastAsset = tokenJSON.additional_assets[tokenJSON.additional_assets.length - 1];
      expect(lastAsset.context).to.equal('New Bulk Secondary Asset 2');
    });

    // version = 50;
    // it("should return out of bounds version", async function() {
    //   const tokenData = metadata.animation;
    //   expect(await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees)).to.be.reverted;
    // });
  })
});
