const hre = require("hardhat");
const metadata = require("../test/metadata.json");

async function main() {
  const ERC721iCore = await hre.ethers.getContractFactory("ERC721iCore");
  const libraryInstance = await ERC721iCore.deploy();
  await libraryInstance.deployed();

  console.log("Library deployed to:", libraryInstance.address);

  const UniverseSingularity = await ethers.getContractFactory("ERC721i", {
    libraries: {
      ERC721iCore: libraryInstance.address,
    },
  });

  singularityInstance = await UniverseSingularity.deploy();
  await singularityInstance.deployed();

  console.log("Singularity deployed to:", singularityInstance.address);

  // const UniverseSingularityProxy = await ethers.getContractFactory(
  //   "ERC721iCreator"
  // );

  // const collectionName = "Universe Singularity Tokens";
  // const collectionSymbol = "XYZTOKEN";
  // const deployArgs = [
  //   singularityInstance.address,
  //   collectionName,
  //   collectionSymbol,
  // ];

  // proxyInstance = await UniverseSingularityProxy.deploy(...deployArgs);
  // await proxyInstance.deployed();

  // console.log("Contract 1 deployed to:", proxyInstance.address);

  // const collectionName2 = "My Personal Collection";
  // const collectionSymbol2 = "ILLESTRATER";
  // const deployArgs2 = [
  //   singularityInstance.address,
  //   collectionName2,
  //   collectionSymbol2,
  // ];
  // const proxyInstance2 = await UniverseSingularityProxy.deploy(...deployArgs2);
  // await proxyInstance2.deployed();

  // console.log("Contract 2 deployed to:", proxyInstance2.address);

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
      address: singularityInstance.address,
    });
  } catch (e) {
    console.log("got error", e);
  }

  console.log("Singularity verified");

  const tokenData = metadata.large;
  const version = 1;
  const blankFees = [];
  await singularityInstance.mint(
    version,
    tokenData.assets,
    tokenData.metadata,
    tokenData.licenseURI,
    tokenData.externalURL,
    blankFees,
    1, // editions
    tokenData.editionName,
    "0x4B49652fBf286b3DA10E44442c38134d841159eF"
  );

  console.log("Token minted");

  // try {
  //   await hre.run("verify:verify", {
  //     address: proxyInstance2.address,
  //     constructorArguments: deployArgs2,
  //     contract: "contracts/ERC721iCreator.sol:ERC721iCreator",
  //   });
  // } catch (e) {
  //   console.log("got error", e);
  // }

  // console.log("Creator proxy contract verified");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });