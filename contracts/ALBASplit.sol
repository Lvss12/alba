pragma solidity ^0.8.9;

import "./ALBAStorage.sol";

contract ALBASplit {
    event lockEvent(string label, address addr, uint256 amount);

    bytes4 private constant OPEN_SELECTOR = bytes4(keccak256("openChannel(uint256,uint256,bytes32,bytes,bytes)"));
    bytes4 private constant UPDATE_SELECTOR = bytes4(keccak256("updateChannel(uint256,uint256,uint256,bytes32,bytes,bytes)"));
    bytes4 private constant CLOSE_SELECTOR = bytes4(keccak256("closeChannel(uint256,uint256,uint256,bytes32,bytes,bytes)"));

    address public channelFacet;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "OWN");
        _;
    }

    constructor(address _prover, address _verifier, address _channelFacet) {
        ALBAStorage.Layout storage l = ALBAStorage.layout();
        l.prover = _prover;
        l.verifier = _verifier;
        channelFacet = _channelFacet;
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

    function setChannelFacet(address _facet) external onlyOwner {
        require(_facet != address(0), "Z0");
        channelFacet = _facet;
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

        if (selector == OPEN_SELECTOR || selector == UPDATE_SELECTOR || selector == CLOSE_SELECTOR) {
            _delegate(channelFacet);
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
