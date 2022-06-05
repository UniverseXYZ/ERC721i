const hre = require("hardhat");
const metadata = require("../test/metadata.json");

async function main() {
  const baseURL =
    "https://bbse5l2rfr7lzaxo5jnrry5ajjmgknnjznd3xh53anahq2vhdxdq.arweave.net/CGROr1EsfryC7upbGOOgSlhlNanLR7ufuwNAeGqnHcc";

  const ERC721iCore = await hre.ethers.getContractFactory("ERC721iCore");
  const libraryInstance = await ERC721iCore.deploy();
  await libraryInstance.deployed();

  console.log("Library deployed to:", libraryInstance.address);

  const ERC721i = await ethers.getContractFactory("ERC721i", {
    libraries: {
      ERC721iCore: libraryInstance.address,
    },
  });

  erc721iInstance = await ERC721i.deploy();
  await erc721iInstance.deployed();

  console.log("Singularity deployed to:", erc721iInstance.address);

  const CreatorProxy = await ethers.getContractFactory("ILLEST");
  proxyInstance = await CreatorProxy.deploy(erc721iInstance.address, baseURL);
  await proxyInstance.deployed();
  deployInstance = erc721iInstance.attach(proxyInstance.address);

  console.log("Creator contract deployed", proxyInstance.address);

  await new Promise((resolve) => setTimeout(resolve, 50000));

  try {
    await hre.run("verify:verify", {
      address: libraryInstance.address,
    });
  } catch (e) {
    console.log("got error", e);
  }

  console.log("Library verified");

  try {
    await hre.run("verify:verify", {
      address: erc721iInstance.address,
    });
  } catch (e) {
    console.log("got error", e);
  }

  console.log("ERC721i verified");

  try {
    await hre.run("verify:verify", {
      address: proxyInstance.address,
      constructorArguments: [erc721iInstance.address, baseURL],
      contract: "contracts/CreatorSample.sol:ILLEST",
    });
  } catch (e) {
    console.log("got error", e);
  }

  console.log("Creator contract verified");

  const tokenData = metadata.basic;
  await deployInstance.mint(
    tokenData.name,
    tokenData.description,
    tokenData.assetHash,
    tokenData.metadata,
    tokenData.licenseURI,
    tokenData.externalURL,
    tokenData.fees,
    tokenData.editions,
    tokenData.editionName,
    "0x4B49652fBf286b3DA10E44442c38134d841159eF"
  );

  console.log("Token Minted!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });