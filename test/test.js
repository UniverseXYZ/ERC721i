const { expect } = require("chai");
const { waffle } = require('hardhat');
const metadata = require('./metadata.json');
const { loadFixture } = waffle;

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("UniverseSingularity", function() {
  const randomWallet = ethers.Wallet.createRandom().address;

  const collectionName = 'Universe Singularity Tokens';
  const collectionSymbol = 'XYZTOKEN';

  let now = Math.trunc(new Date().getTime() / 1000);
  const hour = 3600;
  const day = hour * 24;

  async function deployContracts() {
    const blankFees = [];
    const ERC721iCore = await hre.ethers.getContractFactory("ERC721iCore");
    const libraryInstance = await ERC721iCore.deploy();
    await libraryInstance.deployed();

    const UniverseSingularity = await ethers.getContractFactory("ERC721i", {
      libraries: {
        ERC721iCore: libraryInstance.address
      },
    });

    singularityInstance = await UniverseSingularity.deploy();
    await singularityInstance.deployed();

    const UniverseSingularityProxy = await ethers.getContractFactory("ERC721iCreator");
    proxyInstance = await UniverseSingularityProxy.deploy(singularityInstance.address, collectionName, collectionSymbol);
    await proxyInstance.deployed();
    deployInstance = singularityInstance.attach(proxyInstance.address)

    const proxyInstance2 = await UniverseSingularityProxy.deploy(singularityInstance.address, collectionName, collectionSymbol);
    await proxyInstance2.deployed();
    deployInstance2 = singularityInstance.attach(proxyInstance2.address);

    return { deployInstance, deployInstance2, blankFees };
  };

  it("mint basic token", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.basic;
    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, deployInstance.address);

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.name).to.equal(metadata.basic.assets[0][0])
  });

  it("animation token to a different wallet", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    expect(await deployInstance.ownerOf(1)).to.equal(randomWallet);

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.animation_url).to.equal(tokenData.assets[8][0])
  });

  it("should mint editioned NFTs", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.name).to.equal(`${ metadata.large.assets[0][0] } #${ 1 }/${ metadata.large.editions }`)

    const data2 = base64toJSON(await deployInstance.tokenURI(37));
    expect(data2.name).to.equal(`${ metadata.large.assets[0][0] } #${ 37 }/${ metadata.large.editions }`)

    const data3 = base64toJSON(await deployInstance.tokenURI(63));
    expect(data3.name).to.equal(`${ metadata.large.assets[0][0] } #${ 13 }/${ metadata.large.editions }`)
  });

  it("mint with version and update version", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const version = 8;
    const changedVersion = 3;

    await deployInstance.mint(version, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    expect(await deployInstance.getCurrentVersion(1)).to.equal(version);

    await deployInstance.changeVersion(20, changedVersion);
    expect(await deployInstance.getCurrentVersion(15)).to.equal(changedVersion);

    const data3 = base64toJSON(await deployInstance.tokenURI(11));
    expect(data3.image).to.equal(metadata.large.assets[1][2])
  });


  it("should set torrent magnet link", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const assetVersion = 3;
    const magnetLink = 'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c';

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    await deployInstance.updateTorrentMagnet(1, assetVersion, magnetLink);
    await expect(deployInstance.updateTorrentMagnet(1, 11, magnetLink)).to.be.reverted;
    await expect(deployInstance.updateTorrentMagnet(1, 0, magnetLink)).to.be.reverted;

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.assets[assetVersion - 1].torrent).to.equal(magnetLink);
  });

  it("should set new metadata", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const propertyIndex = 3;
    const value = 'Red';

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    await deployInstance.updateMetadata(1, propertyIndex, value);
    await expect(deployInstance.updateMetadata(1, 0, value)).to.be.reverted;
    await expect(deployInstance.updateMetadata(1, 4, value)).to.be.reverted;

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.attributes[propertyIndex - 1].value).to.equal(value);
  });

  it("should add new assets and in bulk", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const assetData = [
      'https://arweave.net/newAsset',
      'https://arweave.net/newAssetBackup',
      'New Asset Title',
      'New Asset Description',
      'magnet:?xt=urn:btih:yo'
    ]

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

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    await deployInstance.addAsset(1, assetData);

    let data = base64toJSON(await deployInstance.tokenURI(5));
    expect(data.assets[data.assets.length - 1].name).to.equal('New Asset Title')

    await deployInstance.bulkAddAsset(38, bulkAssetData);
    data = base64toJSON(await deployInstance.tokenURI(50));
    expect(data.assets[data.assets.length - 2].name).to.equal('Bulk Asset Title');
    expect(data.assets[data.assets.length - 1].description).to.equal('Bulk Asset Description 2');
  });


  it("should add secondary asset", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const assetData = [
      'https://arweave.net/secondaryAssetNew',
      'New Secondary Asset'
    ]

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


    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    await deployInstance.addSecondaryAsset(1, assetData);
    let data = base64toJSON(await deployInstance.tokenURI(7));
    expect(data.additional_assets[data.additional_assets.length - 1].asset).to.equal('https://arweave.net/secondaryAssetNew')

    await deployInstance.bulkAddSecondaryAsset(1, bulkAssetData);
    data = base64toJSON(await deployInstance.tokenURI(49));
    expect(data.additional_assets[data.additional_assets.length - 2].asset).to.equal('https://arweave.net/bulkSecondaryAssetNew')
    expect(data.additional_assets[data.additional_assets.length - 1].context).to.equal('New Bulk Secondary Asset 2');
  });


  it("return license URI", async function() {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, blankFees, tokenData.editions, tokenData.editionName, randomWallet);
    expect(await deployInstance.licenseURI(1)).to.equal(metadata.large.licenseURI);
  });

  it("token with no royalty change", async function() {
    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;
    const feeTop = 5000;
    const feeBottom = 1000;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 0, feeTop, 0, 0, 0],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 0, feeBottom, 0, 0, 0]
    ]

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions, tokenData.editionName, randomWallet);

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 10]);
    await ethers.provider.send('evm_mine');

    const data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeTop);
    expect(data[1].toNumber()).to.equal(feeBottom);
  });

  it("linear royalty", async function() {
    const feeTop = 5000;
    const feeBottom = 1000;
    const end1 = now + day * 4;
    const end2 = now + day * 11;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 1, feeTop, feeBottom, now, end1],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 1, feeBottom, feeTop, now, end2]
    ];
  
    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.basic;
    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions, tokenData.editionName, deployInstance.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 2]);
    await ethers.provider.send('evm_mine');
    const data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeTop - (feeTop - feeBottom) * (2/4));
    expect(data[1].toNumber()).to.equal(Math.ceil(feeBottom + (feeTop - feeBottom) * (2/11)));

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 18]);
    await ethers.provider.send('evm_mine');
    const data2 = await deployInstance.getFeeBps(1);
    expect(data2[0].toNumber()).to.equal(feeBottom);
    expect(data2[1].toNumber()).to.equal(feeTop);
  });

  it("hard change royalty", async function() {
    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.large;

    const feeTop = 500;
    const feeBottom = 100;
    const end1 = now + day * 20;
    const end2 = now + day * 50;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 2, feeTop, feeBottom, now, end1],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 2, feeBottom, feeTop, now, end2]
    ];

    await deployInstance.mint(1, tokenData.assets, tokenData.metadata, tokenData.licenseURI, fees, tokenData.editions, tokenData.editionName, randomWallet);

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 15]);
    await ethers.provider.send('evm_mine');
    let data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeTop);
    expect(data[1].toNumber()).to.equal(feeBottom);

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 30]);
    await ethers.provider.send('evm_mine');
    data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeBottom);
    expect(data[1].toNumber()).to.equal(feeBottom);

    await ethers.provider.send('evm_setNextBlockTimestamp', [now + day * 60]);
    await ethers.provider.send('evm_mine');
    data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeBottom);
    expect(data[1].toNumber()).to.equal(feeTop);
  });
});
