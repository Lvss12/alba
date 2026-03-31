pragma solidity ^0.8.9;

import "./ALBAStorageV3.sol";

contract ALBASplitV3 {
    event lockEvent(string label, address addr, uint256 amount);

    bytes4 private constant OPEN_SELECTOR = bytes4(keccak256("openChannel(uint256,uint256,bytes32,bytes,bytes)"));

    address public openFacet;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "OWN");
        _;
    }

    constructor(address _prover, address _verifier, address _openFacet) {
        ALBAStorageV3.Layout storage l = ALBAStorageV3.layout();
        l.prover = _prover;
        l.verifier = _verifier;
        openFacet = _openFacet;
        owner = msg.sender;
    }

    receive() external payable {
        ALBAStorageV3.Layout storage l = ALBAStorageV3.layout();
        require(!l.fundsSettled, "E2");
        l.initBalEth[msg.sender] = msg.value;
        l.totalSupply += msg.value;
        l.state.coinsLocked = true;
        emit lockEvent("Coins locked!", msg.sender, msg.value);
    }

    function setOpenFacet(address _openFacet) external onlyOwner {
        require(_openFacet != address(0), "Z0");
        openFacet = _openFacet;
    }

    function fundsSettled() external view returns (bool) {
        return ALBAStorageV3.layout().fundsSettled;
    }

    function channel()
        external
        view
        returns (uint256 balP, uint256 balV, bytes32 rKey, uint256 seqNumber, uint256 lastUpdated, bytes32 latestStateHash, bool isOpen)
    {
        ALBAStorageV3.ChannelState storage c = ALBAStorageV3.layout().channel;
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
