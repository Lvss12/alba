pragma solidity ^0.8.9;

import "./ALBAStorage.sol";
import "./ECDSA.sol";

contract ALBAUpdateFacet {
    event channelUpdated(uint256 seqNumber, uint256 balP, uint256 balV);

    function updateChannel(
        uint256 _seqNumber,
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorage.Layout storage l = ALBAStorage.layout();

        require(l.fundsSettled == false, "E2");
        require(l.mode != ALBAStorage.OperationMode.Bridge, "E15");
        require(l.channel.isOpen == true, "E20");
        require(_seqNumber > l.channel.seqNumber, "E21");
        require(_balP + _balV == l.totalSupply, "E18");

        bytes32 message = sha256(
            abi.encodePacked(address(this), _seqNumber, _balP, _balV, _rKey, "updateChannel")
        );

        require(
            l.prover == ECDSA.recover(message, abi.encodePacked(_sigP))
                && l.verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "E22"
        );

        l.channel.balP = _balP;
        l.channel.balV = _balV;
        l.channel.rKey = _rKey;
        l.channel.seqNumber = _seqNumber;
        l.channel.lastUpdated = block.timestamp;
        l.channel.latestStateHash = sha256(abi.encodePacked(_seqNumber, _balP, _balV, _rKey));
        l.mode = ALBAStorage.OperationMode.Channel;

        emit channelUpdated(_seqNumber, _balP, _balV);
    }
}
