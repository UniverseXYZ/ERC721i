const hre = require("hardhat");

async function main() {
  const collectionName = 'Universe Singularity Tokens';
  const collectionSymbol = 'XYZTOKEN';

  let deployInstance;

  const ERC721I = await ethers.getContractFactory("ERC721I");

  deployInstance = await ERC721I.deploy(
    collectionName,
    collectionSymbol,
  );
  await deployInstance.deployed();

  console.log('ERC721I deployed: ', deployInstance.address)

  await new Promise(resolve => setTimeout(resolve, 50000));

  try {
    await hre.run("verify:verify", {
      address: deployInstance.address,
      constructorArguments: [collectionName, collectionSymbol],
    });
  } catch (e) {
    console.log('got error', e);
  }

  console.log('ERC721I verified');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });