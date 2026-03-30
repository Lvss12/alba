pragma solidity ^0.8.9;

import "./ALBAStorage.sol";
import "./ECDSA.sol";

contract ALBAChannelFacet {
    event channelOpened(uint256 balP, uint256 balV);
    event channelUpdated(uint256 seqNumber, uint256 balP, uint256 balV);
    event channelClosed(uint256 seqNumber, uint256 balP, uint256 balV);

    function openChannel(
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorage.Layout storage l = _layout();

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

    function updateChannel(
        uint256 _seqNumber,
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorage.Layout storage l = _layout();

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

    function closeChannel(
        uint256 _seqNumber,
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        ALBAStorage.Layout storage l = _layout();

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
        uint256 supply = l.totalSupply;
        l.totalSupply = 0;

        (bool sentP,) = l.prover.call{value: _balP}("");
        require(sentP, "E26");
        (bool sentV,) = l.verifier.call{value: _balV}("");
        require(sentV, "E27");

        emit channelClosed(_seqNumber, _balP, _balV);
        supply;
    }

    function _layout() internal pure returns (ALBAStorage.Layout storage l) {
        return ALBAStorage.layout();
    }
}
