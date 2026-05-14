// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SifakaSignalCommitmentV1} from "../src/SifakaSignalCommitmentV1.sol";

contract SifakaSignalCommitmentV1Test is Test {
    SifakaSignalCommitmentV1 internal c;
    address internal operator = address(0xA11CE);
    address internal stranger = address(0xB0B);

    event BatchCommitted(
        uint256 indexed batchId,
        uint256 batchStartTime,
        uint256 batchEndTime,
        bytes32[] hashes
    );

    function setUp() public {
        c = new SifakaSignalCommitmentV1(operator);
    }

    // ── construction ──────────────────────────────────────────────────

    function test_constructor_setsOperator() public view {
        assertEq(c.operator(), operator);
        assertEq(c.batchCount(), 0);
    }

    function test_constructor_revertsOnZeroOperator() public {
        vm.expectRevert(SifakaSignalCommitmentV1.NotOperator.selector);
        new SifakaSignalCommitmentV1(address(0));
    }

    // ── access control ────────────────────────────────────────────────

    function test_commit_revertsForNonOperator() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("dummy");

        vm.prank(stranger);
        vm.expectRevert(SifakaSignalCommitmentV1.NotOperator.selector);
        c.commit(100, 200, hashes);
    }

    // ── input validation ──────────────────────────────────────────────

    function test_commit_revertsOnEmptyBatch() public {
        bytes32[] memory empty = new bytes32[](0);
        vm.prank(operator);
        vm.expectRevert(SifakaSignalCommitmentV1.EmptyBatch.selector);
        c.commit(100, 200, empty);
    }

    function test_commit_revertsOnInvertedTimeRange() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("dummy");
        vm.prank(operator);
        vm.expectRevert(SifakaSignalCommitmentV1.TimeRangeInverted.selector);
        c.commit(200, 100, hashes);
    }

    function test_commit_acceptsEqualStartEnd() public {
        // single-signal batch where start == end is valid
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("dummy");
        vm.prank(operator);
        c.commit(150, 150, hashes);
        assertEq(c.batchCount(), 1);
    }

    // ── happy path ────────────────────────────────────────────────────

    function test_commit_emitsEventWithCorrectPayload() public {
        bytes32[] memory hashes = new bytes32[](3);
        hashes[0] = keccak256("signal-1");
        hashes[1] = keccak256("signal-2");
        hashes[2] = keccak256("signal-3");

        vm.prank(operator);
        vm.expectEmit(true, false, false, true);
        emit BatchCommitted(0, 1700000000, 1700003600, hashes);
        uint256 returnedId = c.commit(1700000000, 1700003600, hashes);

        assertEq(returnedId, 0);
        assertEq(c.batchCount(), 1);
    }

    function test_commit_batchIdIncrementsMonotonically() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("x");

        vm.startPrank(operator);
        assertEq(c.commit(1, 2, hashes), 0);
        assertEq(c.commit(3, 4, hashes), 1);
        assertEq(c.commit(5, 6, hashes), 2);
        vm.stopPrank();

        assertEq(c.batchCount(), 3);
    }

    // ── fuzz: batch sizes ─────────────────────────────────────────────

    function testFuzz_commit_acceptsAnyHashCount(uint8 n) public {
        vm.assume(n > 0 && n <= 100); // reasonable batch ceiling for gas
        bytes32[] memory hashes = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            hashes[i] = keccak256(abi.encodePacked("signal", i));
        }
        vm.prank(operator);
        uint256 id = c.commit(1700000000, 1700003600, hashes);
        assertEq(id, 0);
        assertEq(c.batchCount(), 1);
    }

    // ── gas snapshot for budget tracking ──────────────────────────────

    function test_gas_singleHashBatch() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("signal-1");
        vm.prank(operator);
        uint256 g0 = gasleft();
        c.commit(1700000000, 1700000060, hashes);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_single_hash_batch", used);
        // Sanity ceiling — must remain << 100k for our cost model
        assertLt(used, 60_000);
    }

    function test_gas_tenHashBatch() public {
        bytes32[] memory hashes = new bytes32[](10);
        for (uint256 i = 0; i < 10; i++) {
            hashes[i] = keccak256(abi.encodePacked("signal", i));
        }
        vm.prank(operator);
        uint256 g0 = gasleft();
        c.commit(1700000000, 1700003600, hashes);
        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_ten_hash_batch", used);
        assertLt(used, 100_000);
    }
}
