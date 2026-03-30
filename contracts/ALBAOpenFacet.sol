pragma solidity ^0.8.9;

import "./ALBAStorage.sol";
import "./ECDSA.sol";

contract ALBAOpenFacet {
    event channelOpened(uint256 balP, uint256 balV);

    function openChannel(
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorage.Layout storage l = ALBAStorage.layout();

        require(l.fundsSettled == false, "E2");
        require(l.mode != ALBAStorage.OperationMode.Bridge, "E15");
        require(l.state.coinsLocked == true, "E16");
        require(l.channel.isOpen == false, "E17");
        require(_balP + _balV == l.totalSupply, "E18");

        bytes32 message = sha256(
            abi.encodePacked(address(this), uint256(0), _balP, _balV, _rKey, "openChannel")
        );

        require(
            l.prover == ECDSA.recover(message, abi.encodePacked(_sigP))
                && l.verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "E19"
        );

        l.channel.balP = _balP;
        l.channel.balV = _balV;
        l.channel.rKey = _rKey;
        l.channel.seqNumber = 0;
        l.channel.lastUpdated = block.timestamp;
        l.channel.latestStateHash = sha256(abi.encodePacked(uint256(0), _balP, _balV, _rKey));
        l.channel.isOpen = true;
        l.mode = ALBAStorage.OperationMode.Channel;

        emit channelOpened(_balP, _balV);
    }
}
