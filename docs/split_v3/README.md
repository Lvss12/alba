# Split V3 (Merge-friendly)

This variant is intentionally additive-only to avoid merge conflicts:
- No edits to legacy `contracts/ALBA.sol`
- No edits to legacy Sepolia scripts
- No edits to root README

Files live under:
- `contracts/split_v3/*`
- `scripts/split_v3/*`
- `docs/split_v3/*`

Use this as a safe landing zone before promoting changes into main paths.

## Running notes (important)

If your terminal shows `Need to install hardhat@3.x`, you are not using this repo's local Hardhat binary.
Use one of these instead:

- `npx --no-install hardhat run scripts/split_v3/deploy-sepolia-split-v3.js --network sepolia`
- `npm run hardhat -- run scripts/split_v3/deploy-sepolia-split-v3.js --network sepolia`

For this repository (`hardhat@2.x`), Node 18 can run but may show warnings. Node 20 LTS is recommended for consistency.
