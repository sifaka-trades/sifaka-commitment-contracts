#!/usr/bin/env bash
# Deploy SifakaSignalCommitmentV1 to Polygon Amoy testnet.
#
# Reads the operator PK interactively (not from history). The same EOA
# is used as deployer AND operator — simpler key management, and the
# operator already needs MATIC for ongoing commits.
#
# Prerequisites:
#   - cast wallet new completed; operator address known.
#   - Address funded via faucet.polygon.technology (Amoy network).
#   - Foundry installed (forge, cast in PATH).

set -euo pipefail

OPERATOR_ADDR="${OPERATOR_ADDR:-0xB51292564A56098c067F6a4BC17c8a920977E6a4}"
RPC_URL="${RPC_URL:-https://rpc-amoy.polygon.technology}"

echo "Deploying SifakaSignalCommitmentV1 to Polygon Amoy"
echo "  Operator address (will be hardcoded into contract): $OPERATOR_ADDR"
echo "  RPC: $RPC_URL"
echo ""

# Read PK without echoing to terminal or shell history.
read -rs -p "Operator private key (hidden): " DEPLOYER_PK
echo ""
export DEPLOYER_PK
export OPERATOR_ADDR

# Sanity-check balance before deploy
echo "Checking balance..."
cast balance "$OPERATOR_ADDR" --rpc-url "$RPC_URL" --ether

# Optional GAS_PRICE_GWEI override — Amoy testnet's RPC sometimes
# returns wildly inflated prices (saw 250-300 gwei vs expected ~30).
# Setting GAS_PRICE_GWEI=50 forces a more reasonable price; tx may
# wait a block or two longer but actually broadcasts.
GAS_FLAG=""
if [ -n "${GAS_PRICE_GWEI:-}" ]; then
  GAS_WEI=$(( GAS_PRICE_GWEI * 1000000000 ))
  GAS_FLAG="--with-gas-price $GAS_WEI"
  echo "Forcing gas price: ${GAS_PRICE_GWEI} gwei"
fi

forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_PK" \
  --broadcast \
  $GAS_FLAG

# Wipe the secret from this shell's env
unset DEPLOYER_PK

echo ""
echo "✓ Deploy complete. Contract address printed above."
echo "  Next: tell Claude the address; he'll wire it into pm_agent + verifier repo."
