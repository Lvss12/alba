pragma solidity ^0.8.9;

library ALBAStorageV3 {
    bytes32 internal constant STORAGE_SLOT = keccak256("alba.storage.split.v3");

    struct ALBAState {
        bool coinsLocked;
    }

    struct ChannelState {
        uint256 balP;
        uint256 balV;
        bytes32 rKey;
        uint256 seqNumber;
        uint256 lastUpdated;
        bytes32 latestStateHash;
        bool isOpen;
    }

    enum OperationMode {
        Unset,
        Bridge,
        Channel
    }

    struct Layout {
        ALBAState state;
        ChannelState channel;
        OperationMode mode;
        bool fundsSettled;
        mapping(address => uint256) initBalEth;
        address prover;
        address verifier;
        uint256 totalSupply;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
