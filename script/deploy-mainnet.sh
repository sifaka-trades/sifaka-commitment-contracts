#!/usr/bin/env bash
# Deploy SifakaSignalCommitmentV1 to Polygon MAINNET (chain 137).
#
# This is the production deploy. The contract is immutable once live —
# the operator address baked in at construction is permanent. Triple-
# check OPERATOR_ADDR before broadcasting.
#
# Reads the operator PK interactively (never echoed, never in history).
# Same EOA is deployer AND operator — it already needs POL for ongoing
# commits, so one wallet keeps key management simple.
#
# Prerequisites:
#   - Operator EOA funded with POL on Polygon mainnet (~5 POL is plenty:
#     deploy ~0.09 POL + thousands of commits).
#   - Foundry installed (forge, cast in PATH).
#   - You have run deploy-amoy.sh first and validated the testnet flow.

set -euo pipefail

OPERATOR_ADDR="${OPERATOR_ADDR:-0xB51292564A56098c067F6a4BC17c8a920977E6a4}"
# Public Polygon mainnet RPC. polygon-rpc.com started returning
# 401 "tenant disabled" 2026-05-22 — switched default to publicnode
# (verified working same day). Fallbacks if this one also fails:
#   RPC_URL=https://polygon.llamarpc.com ./script/deploy-mainnet.sh
#   RPC_URL=https://rpc.ankr.com/polygon ./script/deploy-mainnet.sh
# For production reliability, set RPC_URL to your own Alchemy/Infura key.
RPC_URL="${RPC_URL:-https://polygon-bor-rpc.publicnode.com}"

echo "=========================================="
echo "  ⚠️  POLYGON MAINNET DEPLOY (real chain)"
echo "=========================================="
echo "  Operator (hardcoded into contract, PERMANENT): $OPERATOR_ADDR"
echo "  RPC: $RPC_URL"
echo ""
echo "  This is immutable. If OPERATOR_ADDR is wrong, the only fix is"
echo "  redeploying a fresh contract. Confirm the address above is the"
echo "  Sifaka commitment operator EOA, then continue."
echo ""
read -rp "Type 'mainnet' to confirm: " _confirm
if [ "$_confirm" != "mainnet" ]; then
  echo "Aborted."
  exit 1
fi

# Read PK without echoing to terminal or shell history.
read -rs -p "Operator private key (hidden): " DEPLOYER_PK
echo ""
export DEPLOYER_PK
export OPERATOR_ADDR

# Sanity-check balance before deploy
echo "Checking balance..."
cast balance "$OPERATOR_ADDR" --rpc-url "$RPC_URL" --ether

# Optional GAS_PRICE_GWEI override — Polygon mainnet gas spikes
# (saw 270-280 gwei on 2026-05-22 vs typical 30-50). The RPC's
# suggested price is used by default; override only if a tx stalls.
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
echo "✓ Mainnet deploy complete. Contract address printed above."
echo "  Next: tell Claude the mainnet address. He will:"
echo "    1. fly secrets set --stage PM_AGENT_COMMITMENT_NETWORK=polygon-mainnet"
echo "    2. fly secrets set --stage PM_AGENT_COMMITMENT_CONTRACT=<addr>"
echo "    3. update verify.py DEFAULT_CONTRACT + DEFAULT_RPC"
echo "    4. update verifier README + chronax.ai docs"
echo "  Then a single deploy applies schema-v2 recorder + the new secrets."
