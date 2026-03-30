const { ethers } = require("hardhat");

// Prover / verifier addresses provided by user
const PROVER_ADDRESS = "0x356fBe16CEc1a43c61A44C57f084E8FF2eed52Aa";
const VERIFIER_ADDRESS = "0x69E65045c41B25b065DF38370C2372070E8F560E";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const ChannelFacet = await ethers.getContractFactory("ALBAChannelFacet");
  const channelFacet = await ChannelFacet.deploy();
  await channelFacet.deployed();
  console.log("ALBAChannelFacet deployed to:", channelFacet.address);

  const ALBA = await ethers.getContractFactory("ALBASplit");
  const alba = await ALBA.deploy(PROVER_ADDRESS, VERIFIER_ADDRESS, channelFacet.address);
  await alba.deployed();

  console.log("ALBASplit deployed to:", alba.address);
  console.log("prover:", PROVER_ADDRESS);
  console.log("verifier:", VERIFIER_ADDRESS);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
