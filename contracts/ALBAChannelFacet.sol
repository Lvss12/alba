pragma solidity ^0.8.9;

import "./ALBAStorage.sol";

contract ALBAChannelFacet {
    event channelOpened(uint256 balP, uint256 balV);
    event channelUpdated(uint256 seqNumber, uint256 balP, uint256 balV);
    event channelClosed(uint256 seqNumber, uint256 balP, uint256 balV);

    function openChannel(
        uint256,
        uint256,
        bytes32,
        bytes memory,
        bytes memory
    ) external pure {
        revert("SPLIT_TODO");
    }

    function updateChannel(
        uint256,
        uint256,
        uint256,
        bytes32,
        bytes memory,
        bytes memory
    ) external pure {
        revert("SPLIT_TODO");
    }

    function closeChannel(
        uint256,
        uint256,
        uint256,
        bytes32,
        bytes memory,
        bytes memory
    ) external pure {
        revert("SPLIT_TODO");
    }

    function _layout() internal pure returns (ALBAStorage.Layout storage l) {
        return ALBAStorage.layout();
    }
}
