pragma solidity ^0.8.9;

import "./ALBAStorage.sol";

contract ALBASplitV2 {
    event lockEvent(string label, address addr, uint256 amount);

    bytes4 private constant OPEN_SELECTOR = bytes4(keccak256("openChannel(uint256,uint256,bytes32,bytes,bytes)"));
    bytes4 private constant UPDATE_SELECTOR = bytes4(keccak256("updateChannel(uint256,uint256,uint256,bytes32,bytes,bytes)"));
    bytes4 private constant CLOSE_SELECTOR = bytes4(keccak256("closeChannel(uint256,uint256,uint256,bytes32,bytes,bytes)"));

    address public openFacet;
    address public updateFacet;
    address public closeFacet;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "OWN");
        _;
    }

    constructor(
        address _prover,
        address _verifier,
        address _openFacet,
        address _updateFacet,
        address _closeFacet
    ) {
        ALBAStorage.Layout storage l = ALBAStorage.layout();
        l.prover = _prover;
        l.verifier = _verifier;
        openFacet = _openFacet;
        updateFacet = _updateFacet;
        closeFacet = _closeFacet;
        owner = msg.sender;
    }

    receive() external payable {
        ALBAStorage.Layout storage l = ALBAStorage.layout();
        require(l.fundsSettled == false, "E2");
        l.initBalEth[msg.sender] = msg.value;
        l.totalSupply = l.totalSupply + msg.value;
        l.state.coinsLocked = true;
        emit lockEvent("Coins locked!", msg.sender, msg.value);
    }

    function setFacets(address _openFacet, address _updateFacet, address _closeFacet) external onlyOwner {
        require(_openFacet != address(0), "Z0");
        require(_updateFacet != address(0), "Z1");
        require(_closeFacet != address(0), "Z2");
        openFacet = _openFacet;
        updateFacet = _updateFacet;
        closeFacet = _closeFacet;
    }

    function fundsSettled() external view returns (bool) {
        return ALBAStorage.layout().fundsSettled;
    }

    function channel()
        external
        view
        returns (
            uint256 balP,
            uint256 balV,
            bytes32 rKey,
            uint256 seqNumber,
            uint256 lastUpdated,
            bytes32 latestStateHash,
            bool isOpen
        )
    {
        ALBAStorage.ChannelState storage c = ALBAStorage.layout().channel;
        return (c.balP, c.balV, c.rKey, c.seqNumber, c.lastUpdated, c.latestStateHash, c.isOpen);
    }

    fallback() external payable {
        bytes4 selector;
        assembly {
            selector := calldataload(0)
        }

        if (selector == OPEN_SELECTOR) {
            _delegate(openFacet);
            return;
        }

        if (selector == UPDATE_SELECTOR) {
            _delegate(updateFacet);
            return;
        }

        if (selector == CLOSE_SELECTOR) {
            _delegate(closeFacet);
            return;
        }

        revert("NO_SELECTOR");
    }

    function _delegate(address impl) internal {
        require(impl != address(0), "NO_IMPL");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
