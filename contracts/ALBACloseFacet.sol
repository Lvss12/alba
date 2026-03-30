pragma solidity ^0.8.9;

import "./ALBAStorage.sol";
import "./ECDSA.sol";

contract ALBACloseFacet {
    event channelClosed(uint256 seqNumber, uint256 balP, uint256 balV);

    function closeChannel(
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

        bytes32 providedHash = sha256(abi.encodePacked(_seqNumber, _balP, _balV, _rKey));
        require(providedHash == l.channel.latestStateHash, "E23");

        bytes32 message = sha256(abi.encodePacked(address(this), l.channel.latestStateHash, "closeChannel"));

        require(
            l.prover == ECDSA.recover(message, abi.encodePacked(_sigP))
                && l.verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "E24"
        );

        require(_balP + _balV == l.totalSupply, "E25");

        l.channel.isOpen = false;
        l.fundsSettled = true;
        l.totalSupply = 0;

        (bool sentP,) = l.prover.call{value: _balP}("");
        require(sentP, "E26");
        (bool sentV,) = l.verifier.call{value: _balV}("");
        require(sentV, "E27");

        emit channelClosed(_seqNumber, _balP, _balV);
    }
}
