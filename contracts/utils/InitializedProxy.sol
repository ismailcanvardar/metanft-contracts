// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title InitializedProxy
 * @dev A proxy contract that initializes and delegates calls to an implementation contract.
 * The initialization calldata is passed to the implementation contract during deployment.
 */
contract InitializedProxy {
    address public immutable logic;

    constructor(address _logic, bytes memory _initializationCalldata) {
        logic = _logic;

        // Delegate the initialization call to the implementation contract
        (bool _ok, bytes memory returnData) = _logic.delegatecall(
            _initializationCalldata
        );
        require(_ok, string(returnData));
    }

    /**
     * @dev Fallback function that delegates all calls to the implementation contract.
     * If the call fails, it reverts with the error message returned by the implementation contract.
     */
    fallback() external payable {
        address _impl = logic;
        assembly {
            // Copy the calldata to memory
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            // Delegate the call to the implementation contract
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)

            // Get the size of the returned data
            let size := returndatasize()

            // Copy the returned data to memory
            returndatacopy(ptr, 0, size)

            // Check the result of the delegatecall
            switch result
            case 0 {
                // If the call failed, revert with the returned error message
                revert(ptr, size)
            }
            default {
                // If the call succeeded, return the returned data
                return(ptr, size)
            }
        }
    }

    receive() external payable {}
}
