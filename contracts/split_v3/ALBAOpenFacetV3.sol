pragma solidity ^0.8.9;

import "../ECDSA.sol";
import "./ALBAStorageV3.sol";

contract ALBAOpenFacetV3 {
    event channelOpened(uint256 balP, uint256 balV);

    function openChannel(
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorageV3.Layout storage l = ALBAStorageV3.layout();
        require(!l.fundsSettled, "E2");
        require(l.mode != ALBAStorageV3.OperationMode.Bridge, "E15");
        require(l.state.coinsLocked, "E16");
        require(!l.channel.isOpen, "E17");
        require(_balP + _balV == l.totalSupply, "E18");

        bytes32 message = sha256(abi.encodePacked(address(this), uint256(0), _balP, _balV, _rKey, "openChannel"));
        require(l.prover == ECDSA.recover(message, abi.encodePacked(_sigP)), "E19");
        require(l.verifier == ECDSA.recover(message, abi.encodePacked(_sigV)), "E19");

        l.channel = ALBAStorageV3.ChannelState({
            balP: _balP,
            balV: _balV,
            rKey: _rKey,
            seqNumber: 0,
            lastUpdated: block.timestamp,
            latestStateHash: sha256(abi.encodePacked(uint256(0), _balP, _balV, _rKey)),
            isOpen: true
        });
        l.mode = ALBAStorageV3.OperationMode.Channel;

        emit channelOpened(_balP, _balV);
    }
}
