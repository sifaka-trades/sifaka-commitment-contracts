# Sifaka Commitment Contracts

On-chain commitment registry for Sifaka prediction-market signals. Solidity, Foundry-based.

## Overview

`SifakaSignalCommitmentV1` is an append-only event log on Polygon. A trusted operator EOA submits batches of SHA-256 hashes; each hash binds to one Sifaka signal. Plaintext is revealed off-chain after a 30-day delay so anyone can independently verify "Sifaka committed to this exact decision at this exact time."

Key properties:
- **Immutable operator** — set at construction, no rotation. To rotate, deploy a new instance; old commitments stay valid forever.
- **Events only, no storage writes** — gas-efficient (~32-37k gas per batch). Polygon log index is the source of truth.
- **No on-chain reveal** — plaintext + nonce live off-chain (REST API + IPFS bundle). On-chain is just the cryptographic anchor.

## Build & test

```bash
forge build
forge test -vv
```

All 11 tests pass. Gas snapshots:
- 1-hash batch: ~32k gas
- 10-hash batch: ~37k gas
- At Polygon ~30 gwei × $0.6/MATIC: ~$0.0007 per batch

## Deploy

Testnet (Polygon Amoy):
```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_AMOY_RPC \
  --private-key $DEPLOYER_PK \
  --broadcast --verify \
  --etherscan-api-key $POLYGONSCAN_API_KEY
```

Mainnet (Polygon):
```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $POLYGON_RPC \
  --private-key $DEPLOYER_PK \
  --broadcast --verify \
  --etherscan-api-key $POLYGONSCAN_API_KEY
```

Required env vars: `DEPLOYER_PK` (one-time deploy gas, ~0.05 MATIC), `OPERATOR_ADDR` (the EOA that will sign all commits going forward — keep this key in 1Password).

## Verifying a commitment off-chain

See companion repo `sifaka-commitment-verifier` (Python) for the public verifier. Given a `signal_id`, it:

1. GETs the plaintext + nonce + claimed hash from Sifaka's REST API
2. Recomputes `sha256(canonical_json + nonce)` and asserts it equals the claimed hash
3. Queries Polygon logs for the `BatchCommitted` event and asserts the hash appears in the event payload
4. Asserts the `batchEndTime` is consistent with the claimed `push_timestamp`
5. Optionally fetches the daily IPFS bundle and asserts the plaintext is present

## Audit & immutability

This contract is intentionally minimal (~30 lines). Self-audited; happy to fund external audit if requested by enterprise customers.

The operator address is **immutable**. There is no admin function, no upgrade pattern, no kill switch. Verifiers can hard-code "if event came from this address with this operator, Sifaka committed to it" as a permanent trust anchor.
