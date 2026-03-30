const { ethers } = require("hardhat");

// Prover / verifier addresses provided by user
const PROVER_ADDRESS = "0x356fBe16CEc1a43c61A44C57f084E8FF2eed52Aa";
const VERIFIER_ADDRESS = "0x69E65045c41B25b065DF38370C2372070E8F560E";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const OpenFacet = await ethers.getContractFactory("ALBAOpenFacet");
  const openFacet = await OpenFacet.deploy();
  await openFacet.deployed();
  console.log("ALBAOpenFacet deployed to:", openFacet.address);

  const UpdateFacet = await ethers.getContractFactory("ALBAUpdateFacet");
  const updateFacet = await UpdateFacet.deploy();
  await updateFacet.deployed();
  console.log("ALBAUpdateFacet deployed to:", updateFacet.address);

  const CloseFacet = await ethers.getContractFactory("ALBACloseFacet");
  const closeFacet = await CloseFacet.deploy();
  await closeFacet.deployed();
  console.log("ALBACloseFacet deployed to:", closeFacet.address);

  const ALBA = await ethers.getContractFactory("ALBASplitV2");
  const alba = await ALBA.deploy(
    PROVER_ADDRESS,
    VERIFIER_ADDRESS,
    openFacet.address,
    updateFacet.address,
    closeFacet.address
  );
  await alba.deployed();

  console.log("ALBASplitV2 deployed to:", alba.address);
  console.log("prover:", PROVER_ADDRESS);
  console.log("verifier:", VERIFIER_ADDRESS);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
