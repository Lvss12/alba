const { ethers } = require("hardhat");
require("dotenv").config();

function mustGetEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}. See .env.example`);
  return v;
}

function signDigest(wallet, digestHex) {
  // Sign the digest directly (NO Ethereum message prefix)
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
  console.log("ALBA:", albaAddress);

  const alba = await ethers.getContractAt("ALBA", albaAddress);

  // 1) Lock funds (each side deposits)
  const depP = ethers.utils.parseEther("0.5");
  const depV = ethers.utils.parseEther("0.5");

  console.log("Locking funds...");
  await (await prover.sendTransaction({ to: albaAddress, value: depP })).wait();
  await (await verifier.sendTransaction({ to: albaAddress, value: depV })).wait();

  // 2) Open channel (seq = 0)
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

  console.log("Opening channel...");
  const txOpen = await alba
    .connect(prover)
    .openChannel(balP0, balV0, rKey0, openSigP, openSigV);
  const rcOpen = await txOpen.wait();
  const evOpen = rcOpen.events?.find((e) => e.event === "channelOpened");
  console.log("channelOpened:", evOpen?.args?.balP?.toString(), evOpen?.args?.balV?.toString());

  // 3) Update channel (seq = 1)
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

  console.log("Updating channel...");
  const txUpd = await alba
    .connect(verifier)
    .updateChannel(seq1, balP1, balV1, rKey1, updSigP, updSigV);
  const rcUpd = await txUpd.wait();
  const evUpd = rcUpd.events?.find((e) => e.event === "channelUpdated");
  console.log(
    "channelUpdated:",
    evUpd?.args?.seqNumber?.toString(),
    evUpd?.args?.balP?.toString(),
    evUpd?.args?.balV?.toString()
  );

  // 4) Close channel
  const stateHash = ethers.utils.sha256(
    ethers.utils.solidityPack(["uint256", "uint256", "uint256", "bytes32"], [seq1, balP1, balV1, rKey1])
  );
  const closeDigest = ethers.utils.sha256(
    ethers.utils.solidityPack(["address", "bytes32", "string"], [albaAddress, stateHash, "closeChannel"])
  );
  const closeSigP = signDigest(prover, closeDigest);
  const closeSigV = signDigest(verifier, closeDigest);

  const balPBefore = await provider.getBalance(prover.address);
  const balVBefore = await provider.getBalance(verifier.address);
  const balContractBefore = await provider.getBalance(albaAddress);

  console.log("Closing channel...");
  const txClose = await alba
    .connect(prover)
    .closeChannel(seq1, balP1, balV1, rKey1, closeSigP, closeSigV);
  const rcClose = await txClose.wait();
  const evClose = rcClose.events?.find((e) => e.event === "channelClosed");
  console.log(
    "channelClosed:",
    evClose?.args?.seqNumber?.toString(),
    evClose?.args?.balP?.toString(),
    evClose?.args?.balV?.toString()
  );

  const balPAfter = await provider.getBalance(prover.address);
  const balVAfter = await provider.getBalance(verifier.address);
  const balContractAfter = await provider.getBalance(albaAddress);

  console.log("Balances (before → after)");
  console.log("  prover:", balPBefore.toString(), "→", balPAfter.toString());
  console.log("  verifier:", balVBefore.toString(), "→", balVAfter.toString());
  console.log("  contract:", balContractBefore.toString(), "→", balContractAfter.toString());

  const channel = await alba.channel();
  console.log("channel.isOpen:", channel.isOpen);
  console.log("channel.seqNumber:", channel.seqNumber.toString());
  console.log("fundsSettled:", await alba.fundsSettled());

  console.log("SUCCESS if:");
  console.log("- channelClosed event printed");
  console.log("- contract balance decreased to ~0");
  console.log("- channel.isOpen == false and fundsSettled == true");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

