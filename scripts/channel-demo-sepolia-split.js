const { ethers } = require("hardhat");
require("dotenv").config();

function mustGetEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}. See .env.example`);
  return v;
}

function signDigest(wallet, digestHex) {
  const sig = wallet._signingKey().signDigest(digestHex);
  return ethers.utils.joinSignature(sig);
}

async function main() {
  const provider = ethers.provider;

  const proverPk = mustGetEnv("PROVER_PRIVATE_KEY");
  const verifierPk = mustGetEnv("VERIFIER_PRIVATE_KEY");
  const albaAddress = mustGetEnv("ALBA_ADDRESS");

  const prover = new ethers.Wallet(proverPk, provider);
  const verifier = new ethers.Wallet(verifierPk, provider);

  console.log("Prover:", prover.address);
  console.log("Verifier:", verifier.address);
  console.log("ALBASplitV2:", albaAddress);

  const alba = await ethers.getContractAt("ALBASplitV2", albaAddress);

  const depP = ethers.utils.parseEther("0.5");
  const depV = ethers.utils.parseEther("0.5");
  await (await prover.sendTransaction({ to: albaAddress, value: depP })).wait();
  await (await verifier.sendTransaction({ to: albaAddress, value: depV })).wait();

  const balP0 = ethers.utils.parseEther("0.6");
  const balV0 = ethers.utils.parseEther("0.4");
  const rKey0 = ethers.utils.hexZeroPad("0x01", 32);

  const openDigest = ethers.utils.sha256(
    ethers.utils.solidityPack(
      ["address", "uint256", "uint256", "uint256", "bytes32", "string"],
      [albaAddress, 0, balP0, balV0, rKey0, "openChannel"]
    )
  );
  const openSigP = signDigest(prover, openDigest);
  const openSigV = signDigest(verifier, openDigest);
  await (await alba.connect(prover).openChannel(balP0, balV0, rKey0, openSigP, openSigV)).wait();

  const seq1 = 1;
  const balP1 = ethers.utils.parseEther("0.55");
  const balV1 = ethers.utils.parseEther("0.45");
  const rKey1 = ethers.utils.hexZeroPad("0x02", 32);

  const updDigest = ethers.utils.sha256(
    ethers.utils.solidityPack(
      ["address", "uint256", "uint256", "uint256", "bytes32", "string"],
      [albaAddress, seq1, balP1, balV1, rKey1, "updateChannel"]
    )
  );
  const updSigP = signDigest(prover, updDigest);
  const updSigV = signDigest(verifier, updDigest);
  await (await alba.connect(verifier).updateChannel(seq1, balP1, balV1, rKey1, updSigP, updSigV)).wait();

  const stateHash = ethers.utils.sha256(
    ethers.utils.solidityPack(["uint256", "uint256", "uint256", "bytes32"], [seq1, balP1, balV1, rKey1])
  );
  const closeDigest = ethers.utils.sha256(
    ethers.utils.solidityPack(["address", "bytes32", "string"], [albaAddress, stateHash, "closeChannel"])
  );
  const closeSigP = signDigest(prover, closeDigest);
  const closeSigV = signDigest(verifier, closeDigest);

  await (await alba.connect(prover).closeChannel(seq1, balP1, balV1, rKey1, closeSigP, closeSigV)).wait();

  const channel = await alba.channel();
  console.log("channel.isOpen:", channel.isOpen);
  console.log("fundsSettled:", await alba.fundsSettled());
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
