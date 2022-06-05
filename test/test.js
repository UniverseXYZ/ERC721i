const { expect } = require("chai");
const { waffle } = require('hardhat');
const metadata = require('./metadata.json');
const { loadFixture } = waffle;

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

const now = Math.trunc(new Date().getTime() / 1000);
const hour = 3600;
const day = hour * 24;

describe("UniverseSingularity", function() {
  const randomWallet = ethers.Wallet.createRandom().address;
  const baseURL =
    "https://bbse5l2rfr7lzaxo5jnrry5ajjmgknnjznd3xh53anahq2vhdxdq.arweave.net/CGROr1EsfryC7upbGOOgSlhlNanLR7ufuwNAeGqnHcc";

  async function deployContracts() {
    const blankFees = [];
    const ERC721iCore = await hre.ethers.getContractFactory("ERC721iCore");
    const libraryInstance = await ERC721iCore.deploy();
    await libraryInstance.deployed();

    const UniverseSingularity = await ethers.getContractFactory("ERC721i", {
      libraries: {
        ERC721iCore: libraryInstance.address,
      },
    });

    singularityInstance = await UniverseSingularity.deploy();
    await singularityInstance.deployed();

    const UniverseSingularityProxy = await ethers.getContractFactory("ILLEST");
    proxyInstance = await UniverseSingularityProxy.deploy(
      singularityInstance.address,
      baseURL
    );
    await proxyInstance.deployed();
    deployInstance = singularityInstance.attach(proxyInstance.address);

    return { deployInstance, blankFees };
  }

  it("mint basic token", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.basic;
    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      deployInstance.address
    );

    console.log(await deployInstance.tokenURI(1));
    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.name).to.equal(metadata.basic.assets[0][0]);
  });

  it("animation token to a different wallet", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    expect(await deployInstance.ownerOf(1)).to.equal(randomWallet);

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.animation_url).to.equal(
      `${baseURL}/?metadata=${tokenData.assetHash}`
    );
  });

  it("mint editioned NFTs", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.name).to.equal(
      `${metadata.large.assets[0][0]} #${1}/${metadata.large.editions}`
    );

    const data2 = base64toJSON(await deployInstance.tokenURI(37));
    expect(data2.name).to.equal(
      `${metadata.large.assets[0][0]} #${37}/${metadata.large.editions}`
    );

    const data3 = base64toJSON(await deployInstance.tokenURI(63));
    expect(data3.name).to.equal(
      `${metadata.large.assets[0][0]} #${13}/${metadata.large.editions}`
    );
  });

  it("set torrent magnet link", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const assetVersion = 3;
    const magnetLink =
      "magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c";

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    await deployInstance.updateTorrentMagnet(1, assetVersion, magnetLink);
    await expect(deployInstance.updateTorrentMagnet(1, 11, magnetLink)).to.be
      .reverted;
    await expect(deployInstance.updateTorrentMagnet(1, 0, magnetLink)).to.be
      .reverted;

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.assets[assetVersion - 1].torrent).to.equal(magnetLink);
  });

  it("set new metadata", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;
    const propertyIndex = 3;
    const value = "Red";

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    await deployInstance.updateMetadata(1, propertyIndex, value);
    await expect(deployInstance.updateMetadata(1, 0, value)).to.be.reverted;
    await expect(deployInstance.updateMetadata(1, 4, value)).to.be.reverted;

    const data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.attributes[propertyIndex - 1].value).to.equal(value);
  });

  it("add new assets and change version", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.large;

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );

    const newArweaveHash = "newArweaveHash";
    await deployInstance.addNewVersion(5, newArweaveHash);

    let data = base64toJSON(await deployInstance.tokenURI(5));
    expect(data.animation_url).to.equal(
      `${baseURL}/?metadata=${newArweaveHash}`
    );

    const changedVersion = 1;
    expect(await deployInstance.getCurrentVersion(5)).to.equal(2);
    await deployInstance.changeVersion(5, changedVersion);
    expect(await deployInstance.getCurrentVersion(5)).to.equal(changedVersion);
  });

  it("return license URI", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    expect(await deployInstance.licenseURI(1)).to.equal(
      metadata.large.licenseURI
    );
  });

  it("update and return external URL", async function () {
    const { deployInstance, blankFees } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      blankFees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );
    let data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.external_url).to.equal(metadata.large.externalURL);

    await deployInstance.updateExternalURL(1, "https://pepe.xyz");
    data = base64toJSON(await deployInstance.tokenURI(1));
    expect(data.external_url).to.equal("https://pepe.xyz");
  });

  it("token with no royalty change", async function () {
    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.animation;
    const feeTop = 5000;
    const feeBottom = 1000;
    const fees = [
      ["0x4B49652fBf286b3DA10E44442c38134d841159eF", 0, feeTop, 0, 0, 0],
      ["0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283", 0, feeBottom, 0, 0, 0],
    ];

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      fees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 10]);
    await ethers.provider.send("evm_mine");

    const data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeTop);
    expect(data[1].toNumber()).to.equal(feeBottom);
  });

  it("linear royalty", async function () {
    const feeTop = 5000;
    const feeBottom = 1000;
    const end1 = now + day * 4;
    const end2 = now + day * 11;
    const fees = [
      [
        "0x4B49652fBf286b3DA10E44442c38134d841159eF",
        1,
        feeTop,
        feeBottom,
        now,
        end1,
      ],
      [
        "0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283",
        1,
        feeBottom,
        feeTop,
        now,
        end2,
      ],
    ];

    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.basic;
    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      fees,
      tokenData.editions,
      tokenData.editionName,
      deployInstance.address
    );

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 2]);
    await ethers.provider.send("evm_mine");
    const data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(
      feeTop - (feeTop - feeBottom) * (2 / 4)
    );
    expect(data[1].toNumber()).to.equal(
      Math.ceil(feeBottom + (feeTop - feeBottom) * (2 / 11))
    );

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 18]);
    await ethers.provider.send("evm_mine");
    const data2 = await deployInstance.getFeeBps(1);
    expect(data2[0].toNumber()).to.equal(feeBottom);
    expect(data2[1].toNumber()).to.equal(feeTop);
  });

  it("hard change royalty", async function () {
    const { deployInstance } = await loadFixture(deployContracts);
    const tokenData = metadata.large;

    const feeTop = 500;
    const feeBottom = 100;
    const end1 = now + day * 20;
    const end2 = now + day * 50;
    const fees = [
      [
        "0x4B49652fBf286b3DA10E44442c38134d841159eF",
        2,
        feeTop,
        feeBottom,
        now,
        end1,
      ],
      [
        "0xeEE5Eb24E7A0EA53B75a1b9aD72e7D20562f4283",
        2,
        feeBottom,
        feeTop,
        now,
        end2,
      ],
    ];

    await deployInstance.mint(
      tokenData.name,
      tokenData.description,
      tokenData.assetHash,
      tokenData.metadata,
      tokenData.licenseURI,
      tokenData.externalURL,
      fees,
      tokenData.editions,
      tokenData.editionName,
      randomWallet
    );

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 15]);
    await ethers.provider.send("evm_mine");
    let data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeTop);
    expect(data[1].toNumber()).to.equal(feeBottom);

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 30]);
    await ethers.provider.send("evm_mine");
    data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeBottom);
    expect(data[1].toNumber()).to.equal(feeBottom);

    await ethers.provider.send("evm_setNextBlockTimestamp", [now + day * 60]);
    await ethers.provider.send("evm_mine");
    data = await deployInstance.getFeeBps(1);
    expect(data[0].toNumber()).to.equal(feeBottom);
    expect(data[1].toNumber()).to.equal(feeTop);
  });
});
