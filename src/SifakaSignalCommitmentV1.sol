// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  Sifaka Signal Commitment V1
/// @notice Append-only commitment log for prediction-market trading signals.
///         A trusted operator EOA submits batches of SHA-256 hashes; each hash
///         binds to one signal record whose plaintext is revealed off-chain
///         after a 30-day delay. Verifiers can later replay sha256(plaintext)
///         and assert it appears in a BatchCommitted event from this contract.
/// @dev    No on-chain reveal. Storage is intentionally minimal — events carry
///         all data and remain queryable forever in the Polygon log index.
contract SifakaSignalCommitmentV1 {
    /// @notice The single address authorized to call commit(). Immutable so
    ///         verifiers can hard-code a trust assumption: "if this contract
    ///         emitted the event, this operator signed it." If the operator
    ///         needs to rotate, deploy a new instance — old commitments stay
    ///         valid forever in this contract's log.
    address public immutable operator;

    /// @notice Monotonic batch counter, starts at 0 and increments per commit.
    uint256 public batchCount;

    /// @notice Emitted on every successful commit. Indexed batchId enables
    ///         efficient log queries by batch number; the time fields and
    ///         hash array are non-indexed (cheaper, full payload in data).
    event BatchCommitted(
        uint256 indexed batchId,
        uint256 batchStartTime,
        uint256 batchEndTime,
        bytes32[] hashes
    );

    error NotOperator();
    error EmptyBatch();
    error TimeRangeInverted();

    constructor(address _operator) {
        if (_operator == address(0)) revert NotOperator();
        operator = _operator;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /// @notice Submit a batch of signal commitments.
    /// @param  batchStartTime Unix timestamp of the earliest signal in batch.
    /// @param  batchEndTime   Unix timestamp of the latest signal in batch.
    /// @param  hashes         SHA-256 digests of canonical signal records.
    /// @return batchId        Sequential id assigned to this batch.
    function commit(
        uint256 batchStartTime,
        uint256 batchEndTime,
        bytes32[] calldata hashes
    ) external onlyOperator returns (uint256 batchId) {
        if (hashes.length == 0) revert EmptyBatch();
        if (batchEndTime < batchStartTime) revert TimeRangeInverted();

        batchId = batchCount;
        unchecked {
            batchCount = batchId + 1;
        }
        emit BatchCommitted(batchId, batchStartTime, batchEndTime, hashes);
    }
}
