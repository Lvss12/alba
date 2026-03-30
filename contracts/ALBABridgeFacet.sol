pragma solidity ^0.8.9;

import "./ALBAStorage.sol";

contract ALBABridgeFacet {
    event stateEvent(string label, bool status);

    function setup(
        bytes32,
        bytes memory,
        bytes4,
        bytes memory,
        bytes memory,
        bytes memory,
        uint256,
        uint256,
        bytes memory,
        bytes memory
    ) external pure {
        revert("SPLIT_TODO");
    }

    function submitProof(bytes memory, bytes memory) external pure {
        revert("SPLIT_TODO");
    }

    function optimisticSubmitProof(bytes memory, bytes memory, uint256) external pure {
        revert("SPLIT_TODO");
    }

    function dispute(bytes memory, bytes memory) external pure {
        revert("SPLIT_TODO");
    }

    function resolveValidDispute(bytes memory) external pure {
        revert("SPLIT_TODO");
    }

    function resolveInvalidDispute(string memory) external pure {
        revert("SPLIT_TODO");
    }

    function settle() external pure {
        revert("SPLIT_TODO");
    }

    function _layout() internal pure returns (ALBAStorage.Layout storage l) {
        return ALBAStorage.layout();
    }
}
