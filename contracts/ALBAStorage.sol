pragma solidity ^0.8.9;

library ALBAStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("alba.storage.v1");

    struct ALBAParam {
        bytes32 fundTxId;
        bytes fundTxScript;
        bytes4 fundTxIndx;
        bytes sighash;
        bytes pkPUncompr;
        bytes pkVUncompr;
        uint256 timelock;
        uint256 timelockDisp;
        uint256 balDistr;
    }

    struct ALBAState {
        bool coinsLocked;
        bool setupDone;
        bool proofSubmitted;
        bool disputeOpened;
        bool disputeClosedP;
        bool disputeClosedV;
    }

    struct PaymentChannel {
        uint256 balP;
        uint256 balV;
        bytes32 rKey;
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
        ALBAParam bridge;
        ALBAState state;
        PaymentChannel paymentChan;
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
