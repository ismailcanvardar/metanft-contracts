// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @title Multicall
 * @dev Contract for batch execution of multiple calls to other contracts.
 */
contract Multicall {
    /**
     * @dev Struct representing a call to a target contract.
     */
    struct Call {
        address target;
        bytes callData;
    }

    /**
     * @dev Struct representing the result of a call.
     */
    struct Result {
        bool success;
        bytes returnData;
    }

    /**
     * @dev Execute multiple calls to different contracts.
     * @param calls An array of Call structs representing the target contracts and call data.
     * @return blockNumber The current block number.
     * @return returnData An array of bytes containing the return data of each call.
     */
    function aggregate(
        Call[] memory calls
    ) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }

    /**
     * @dev Execute multiple calls to different contracts and retrieve block information.
     * @param calls An array of Call structs representing the target contracts and call data.
     * @return blockNumber The current block number.
     * @return blockHash The hash of the current block.
     * @return returnData An array of Result structs representing the result of each call.
     */
    function blockAndAggregate(
        Call[] memory calls
    )
        public
        returns (
            uint256 blockNumber,
            bytes32 blockHash,
            Result[] memory returnData
        )
    {
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(
            true,
            calls
        );
    }

    /**
     * @dev Get the hash of a specific block.
     * @param blockNumber The block number.
     * @return blockHash The hash of the specified block.
     */
    function getBlockHash(
        uint256 blockNumber
    ) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    /**
     * @dev Get the current block number.
     * @return blockNumber The current block number.
     */
    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    /**
     * @dev Get the coinbase address of the current block.
     * @return coinbase The coinbase address.
     */
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    /**
     * @dev Get the difficulty of the current block.
     * @return difficulty The block difficulty.
     */
    function getCurrentBlockDifficulty()
        public
        view
        returns (uint256 difficulty)
    {
        difficulty = block.difficulty;
    }

    /**
     * @dev Get the gas limit of the current block.
     * @return gaslimit The block gas limit.
     */
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    /**
     * @dev Get the timestamp of the current block.
     * @return timestamp The block timestamp.
     */
    function getCurrentBlockTimestamp()
        public
        view
        returns (uint256 timestamp)
    {
        timestamp = block.timestamp;
    }

    /**
     * @dev Get the Ether balance of an address.
     * @param addr The address to check.
     * @return balance The Ether balance of the address.
     */
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /**
     * @dev Get the hash of the previous block.
     * @return blockHash The hash of the previous block.
     */
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(block.number - 1);
    }

    /**
     * @dev Execute multiple calls to different contracts, allowing failed calls without reverting.
     * @param requireSuccess Boolean indicating whether to require successful calls.
     * @param calls An array of Call structs representing the target contracts and call data.
     * @return returnData An array of Result structs representing the result of each call.
     */
    function tryAggregate(
        bool requireSuccess,
        Call[] memory calls
    ) public returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );

            if (requireSuccess) {
                require(success, "Multicall aggregate: call failed");
            }

            returnData[i] = Result(success, ret);
        }
    }

    /**
     * @dev Execute multiple calls to different contracts, retrieve block information, and allow failed calls without reverting.
     * @param requireSuccess Boolean indicating whether to require successful calls.
     * @param calls An array of Call structs representing the target contracts and call data.
     * @return blockNumber The current block number.
     * @return blockHash The hash of the current block.
     * @return returnData An array of Result structs representing the result of each call.
     */
    function tryBlockAndAggregate(
        bool requireSuccess,
        Call[] memory calls
    )
        public
        returns (
            uint256 blockNumber,
            bytes32 blockHash,
            Result[] memory returnData
        )
    {
        blockNumber = block.number;
        blockHash = blockhash(block.number);
        returnData = tryAggregate(requireSuccess, calls);
    }
}
