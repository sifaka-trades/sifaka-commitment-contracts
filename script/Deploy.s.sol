// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SifakaSignalCommitmentV1} from "../src/SifakaSignalCommitmentV1.sol";

/// @notice Deploy SifakaSignalCommitmentV1.
/// @dev    Usage:
///         forge script script/Deploy.s.sol:Deploy \
///           --rpc-url $POLYGON_RPC_URL \
///           --private-key $DEPLOYER_PK \
///           --broadcast --verify
///
///         Required env vars:
///           DEPLOYER_PK   — funded EOA that pays deploy gas (~0.05 MATIC)
///           OPERATOR_ADDR — the EOA authorized to call commit() going forward
///                           (NOT the deployer; deployer is throwaway)
contract Deploy is Script {
    function run() external {
        address operator = vm.envAddress("OPERATOR_ADDR");
        require(operator != address(0), "OPERATOR_ADDR unset");

        vm.startBroadcast();
        SifakaSignalCommitmentV1 c = new SifakaSignalCommitmentV1(operator);
        vm.stopBroadcast();

        console.log("SifakaSignalCommitmentV1 deployed at:", address(c));
        console.log("Operator (only address allowed to commit):", operator);
        console.log("");
        console.log("Next steps:");
        console.log("  1. Verify on Polygonscan: forge verify-contract ...");
        console.log("  2. Update pm_agent settings: PM_AGENT_COMMITMENT_CONTRACT=", address(c));
        console.log("  3. Fund operator with ~5 MATIC for ~6 months of commits");
    }
}
