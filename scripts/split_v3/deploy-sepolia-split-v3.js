const { ethers } = require("hardhat");

const PROVER_ADDRESS = "0x356fBe16CEc1a43c61A44C57f084E8FF2eed52Aa";
const VERIFIER_ADDRESS = "0x69E65045c41B25b065DF38370C2372070E8F560E";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const OpenFacet = await ethers.getContractFactory("ALBAOpenFacetV3");
  const openFacet = await OpenFacet.deploy();
  await openFacet.deployed();

  const Split = await ethers.getContractFactory("ALBASplitV3");
  const split = await Split.deploy(PROVER_ADDRESS, VERIFIER_ADDRESS, openFacet.address);
  await split.deployed();

  console.log("ALBAOpenFacetV3:", openFacet.address);
  console.log("ALBASplitV3:", split.address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
