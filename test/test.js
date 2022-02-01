const { expect } = require("chai");
const { utils } = require('ethers');
const metadata = require('./metadata.json');

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("UniverseSingularity", async function() {
  const collectionName = 'Universe Singularity Tokens';
  const collectionSymbol = 'XYZTOKEN';

  let now = Math.trunc(new Date().getTime() / 1000);
  let newDate = Math.trunc(new Date().getTime() / 1000);
  const hour = 3600;
  const day = hour * 24;
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
  
  await describe("BASIC TOKEN TESTS", async function() {
    const feeTop = 5000;
    const feeBottom = 1000;
    const end1 = now + day * 4;
    const end2 = now + day * 11;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 1, feeTop, feeBottom, now, end1],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 1, feeBottom, feeTop, now, end2]
    ];
    it("should mint one", async function() {
      const tokenData = metadata.basic;
      await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions);
      tokenIdCounter++;
    });

    it("should return tokenURI", async function() {
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      // console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.basic.assets[0][0])
    });

    it("should change in royalty", async function() {
      await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 2]);
      await ethers.provider.send('evm_mine');
      const data = await deployInstance.getFeeBps(tokenIdCounter);
      expect(data[0].toNumber()).to.equal(feeTop - (feeTop - feeBottom) * (2/4));
      expect(data[1].toNumber()).to.equal(Math.ceil(feeBottom + (feeTop - feeBottom) * (2/11)));
    });
  });

  await describe("ANIMATION_URL TOKEN TESTS", async function() {
    const feeTop = 5000;
    const feeBottom = 1000;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 0, feeTop, 0, 0, 0],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 0, feeBottom, 0, 0, 0]
    ]

    it("should mint one", async function() {
      const tokenData = metadata.animation;
      await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions);
      tokenIdCounter++;
      const data = await deployInstance.tokenURI(2);
      const tokenJSON = base64toJSON(data);
      // console.log(tokenJSON);
    });

    it("should change in royalty", async function() {
      await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 10]);
      await ethers.provider.send('evm_mine');
      const data = await deployInstance.getFeeBps(tokenIdCounter);
      expect(data[0].toNumber()).to.equal(feeTop);
      expect(data[1].toNumber()).to.equal(feeBottom);
    });
  })

  await describe("ONCHAIN TOKEN TESTS", async function() {
    const feeTop = 500;
    const feeBottom = 100;
    const end1 = now + day * 20;
    const end2 = now + day * 50;
    let version = 8;
    it("should mint one", async function() {
      const fees = [
        ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 2, feeTop, feeBottom, now, end1],
        ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 2, feeBottom, feeTop, now, end2]
      ];
      const tokenData = metadata.large;
      await deployInstance.mint(version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions);
    });
  
    it("should return tokenURI", async function() {
      tokenIdCounter++;
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      // console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[0][0])
    });

    it("should mint 50 editions", async function() {
      tokenIdCounter += 49;
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      // console.log(tokenJSON);
      expect(tokenJSON.name).to.equal(metadata.large.assets[0][0])
    });

    it("should return licenseURI", async function() {
      const data = await deployInstance.licenseURI(tokenIdCounter);
      expect(data).to.equal(metadata.large.licenseURI)
    });

    it("should return set current version", async function() {
      const data = await deployInstance.getCurrentVersion(tokenIdCounter);
      expect(data).to.equal(version)
    });

    it("should change version", async function() {
      let changedVersion = 3;
      await deployInstance.changeVersion(tokenIdCounter - 20, changedVersion);
      let data = await deployInstance.getCurrentVersion(tokenIdCounter - 15);
      expect(data).to.equal(changedVersion);
      data = await deployInstance.tokenURI(tokenIdCounter - 11);
      const tokenJSON = base64toJSON(data);
      expect(tokenJSON.image).to.equal(metadata.large.assets[1][2])
    });

    it("should set torrent magnet link", async function() {
      const assetVersion = 3;
      const magnetLink = 'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c';
      await deployInstance.updateTorrentMagnet(tokenIdCounter, assetVersion, magnetLink);
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      // console.log('test', tokenJSON);
      expect(tokenJSON.assets[assetVersion - 1].torrent).to.equal(magnetLink)
      await expect(deployInstance.updateTorrentMagnet(tokenIdCounter, 11, magnetLink)).to.be.reverted;
      await expect(deployInstance.updateTorrentMagnet(tokenIdCounter, 0, magnetLink)).to.be.reverted;
    });

    it("should set new metadata", async function() {
      const propertyIndex = 3;
      const value = 'Red';
      await deployInstance.updateMetadata(tokenIdCounter, propertyIndex, value);
      const data = await deployInstance.tokenURI(tokenIdCounter);
      const tokenJSON = base64toJSON(data);
      expect(tokenJSON.attributes[propertyIndex - 1].value).to.equal(value);
      await expect(deployInstance.updateMetadata(tokenIdCounter, 0, value)).to.be.reverted;
      await expect(deployInstance.updateMetadata(tokenIdCounter, 4, value)).to.be.reverted;
    });

    it("should add asset", async function() {
      const assetData = [
        'https://arweave.net/newAsset',
        'https://arweave.net/newAssetBackup',
        'New Asset Title',
        'New Asset Description',
        'magnet:?xt=urn:btih:yo'
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
          'Bulk Asset Description',
          'magnet:?xt=urn:btih:yo'
        ],
        [
          'https://arweave.net/bulkAsset2',
          'https://arweave.net/bulkAssetBackup2',
          'Bulk Asset Title 2',
          'Bulk Asset Description 2',
          'magnet:?xt=urn:btih:yo'
        ]
      ]

      await deployInstance.bulkAddAsset(tokenIdCounter, bulkAssetData);
      data = await deployInstance.tokenURI(tokenIdCounter - 49);
      tokenJSON = base64toJSON(data);
      lastAsset = tokenJSON.assets[tokenJSON.assets.length - 2];
      expect(lastAsset.name).to.equal('Bulk Asset Title');
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

    it("should not change in royalty", async function() {
      await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 15]);
      await ethers.provider.send('evm_mine');
      let data = await deployInstance.getFeeBps(tokenIdCounter);
      expect(data[0].toNumber()).to.equal(feeTop);
      expect(data[1].toNumber()).to.equal(feeBottom);
    });

    it("should change first royalty", async function() {
      await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 30]);
      await ethers.provider.send('evm_mine');
      data = await deployInstance.getFeeBps(tokenIdCounter);
      expect(data[0].toNumber()).to.equal(feeBottom);
      expect(data[1].toNumber()).to.equal(feeBottom);
    });

    it("should change last royalty", async function() {
      await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 60]);
      await ethers.provider.send('evm_mine');
      data = await deployInstance.getFeeBps(tokenIdCounter);
      expect(data[0].toNumber()).to.equal(feeBottom);
      expect(data[1].toNumber()).to.equal(feeTop);
    });

    // version = 50;
    // it("should return out of bounds version", async function() {
    //   const tokenData = metadata.animation;
    //   expect(await deployInstance.mint(tokenData.isOnChain, version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, tokenData.fees)).to.be.reverted;
    // });
  })
});
