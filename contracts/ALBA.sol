pragma solidity ^0.8.9;
//pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "./ParseBTCLib.sol";
import "./BytesLib.sol";
import "./BTCUtils.sol";
import "./ECDSA.sol";
import "./ALBAHelper.sol";
import "./SchnorrN.sol";

// This contract is used by Prover P and verifier V to verify on Ethereum the current state of their Lightning payment channel 

contract ALBA {

    event stateEvent(string label, bool status);
    event lockEvent(string label, address addr, uint amount);
    event channelOpened(uint256 balP, uint256 balV);
    event channelUpdated(uint256 seqNumber, uint256 balP, uint256 balV);
    event channelClosed(uint256 seqNumber, uint256 balP, uint256 balV);

    // define global variables for this contract instance (setup phase)
    struct ALBAParam {
        bytes32 fundTxId;
        bytes fundTxScript;
        bytes4 fundTxIndx;
        bytes sighash;
        bytes pkPUncompr; 
        bytes pkVUncompr;
        uint256 timelock; //timelock is 1701817200, i.e., Tue Dec 05 2023 23:00:00 GMT+0000. 
        uint256 timelockDisp; //relative timelock 
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

    // NOTE: This struct is used by the bridge/dispute logic as temporary storage
    // for balances and the revocation key extracted from Bitcoin transactions.
    struct PaymentChannel {
        uint balP; // balance extracted from Bitcoin commitment tx
        uint balV; // balance extracted from Bitcoin commitment tx
        bytes32 rKey; // revocation key extracted from Bitcoin commitment tx
    }

    // This struct is used for the Ethereum-side channel lifecycle management.
    struct ChannelState {
        uint256 balP;
        uint256 balV;
        bytes32 rKey;
        uint256 seqNumber;
        uint256 lastUpdated;
        bytes32 latestStateHash; // hash of the latest verified state
        bool isOpen;
    }

    enum OperationMode {
        Unset,
        Bridge,
        Channel
    }

    ALBAParam public bridge;
    ALBAState public state;    
    PaymentChannel public paymentChan;
    ChannelState public channel;
    OperationMode public mode;
    bool public fundsSettled;

    mapping(address => uint256) initBalEth;

    address prover;
    address verifier;
    uint256 totalSupply;

    modifier onlyParticipants() {
        require(msg.sender == prover || msg.sender == verifier, "Only channel participants");
        _;
    }

    constructor(address _prover, address _verifier) {
        prover = _prover; 
        verifier = _verifier; 
    } 

    // this function allows protocol parties to lock funds in the contract
    receive() external payable {

        // React to receiving ether
        require(fundsSettled == false, "Funds already settled");
        initBalEth[msg.sender] = msg.value; 
        totalSupply = totalSupply + msg.value;
        state.coinsLocked = true;
        emit lockEvent("Coins locked!", msg.sender, msg.value);
    
    } 

    function setup(bytes32 fundTxId, 
                   bytes memory fundTxScript, 
                   bytes4 fundTxIndx, 
                   bytes memory sighash,
                   bytes memory pkPUncompr, 
                   bytes memory pkVUncompr, 
                   uint256 timelock, 
                   uint256 timelockDisp, 
                   bytes memory sigP, 
                   bytes memory sigV) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        
        // populate protocol specifics
        bridge.fundTxId = fundTxId;
        bridge.fundTxScript = fundTxScript;
        bridge.fundTxIndx = fundTxIndx;
        bridge.sighash = sighash;
        bridge.pkPUncompr = pkPUncompr;
        bridge.pkVUncompr = pkVUncompr;
        bridge.timelock = timelock;
        bridge.timelockDisp = timelockDisp;

        bridge.balDistr = 7; // TODO for the future: make it dynamic

        // verify signatures over setup data
        bytes memory message = bytes.concat(BytesLib.toBytes(bridge.fundTxId), bridge.fundTxScript, BytesLib.toBytesNew(bridge.fundTxIndx), bridge.sighash, bridge.pkPUncompr, bridge.pkVUncompr, BytesLib.uint256ToBytes(bridge.timelock), BytesLib.uint256ToBytes(bridge.timelockDisp));
        require(prover == ECDSA.recover(sha256(message), abi.encodePacked(sigP)) && verifier == ECDSA.recover(sha256(message), abi.encodePacked(sigV)), "Invalid signatures over setup data");

        // populate state variables
        state.proofSubmitted = false;
        state.disputeOpened = false;
        state.disputeClosedP = false;
        state.disputeClosedV = false;
        state.setupDone = true;
        mode = OperationMode.Bridge;
    }

    function submitProof(bytes memory CT_P_unlocked,                    
                         bytes memory CT_V_unlocked) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        // check that current time is smaller than the timeout defined in Setup, and check proof has not yet been submitted, nor dispute raised
        if (block.timestamp < bridge.timelock && (state.coinsLocked == true && 
                                                  state.setupDone == true && 
                                                  state.proofSubmitted == false && 
                                                  state.disputeOpened == false)) {

            // check transactions are not locked
            require(ParseBTCLib.getTimelock(CT_P_unlocked) == bytes4(0), "CTxP locked");
            require(ParseBTCLib.getTimelock(CT_V_unlocked) == bytes4(0), "CTxV locked");

            // check transactions are well formed
            ParseBTCLib.HTLCData[2] memory htlc;
            ParseBTCLib.P2PKHData[2] memory p2pkh; 
            ParseBTCLib.OpReturnData memory opreturn;
            (htlc, p2pkh, opreturn) = ALBAHelper.checkTxAreWellFormed(CT_P_unlocked, CT_V_unlocked, bridge.fundTxScript, bridge.fundTxId);

            ALBAHelper.checkSignaturesEcrecover(CT_P_unlocked, CT_V_unlocked, bridge.fundTxScript, bridge.sighash, bridge.pkPUncompr, bridge.pkVUncompr);         

            // Check on the channel balance: e.g., require the balance of P is higher than X, with X = 10 in this example
            require(htlc[0].value > 10, "Prover does not have a sufficient amount of coins");
    
            // update state of the protocol
            state.proofSubmitted = true;

            emit stateEvent("Proof successfully verified", state.proofSubmitted);

        } else {

            emit stateEvent("Proof verification failed", state.proofSubmitted);

        } 
    }

    function optimisticSubmitProof(bytes memory sigP, 
                             bytes memory sigV, uint256 seqNumber) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        //string memory label = "proofSubmitted";
        bytes32 message = sha256(bytes.concat(BytesLib.uint256ToBytes(seqNumber), abi.encodePacked("proofSubmitted"), abi.encodePacked(true)));

        // check that P and V signed a message of the form (sn, proofSubmitted, true), where they acknowledge to distribute funds
        if (block.timestamp < bridge.timelock && state.coinsLocked == true 
                                              && state.setupDone == true 
                                              && state.proofSubmitted == false 
                                              && state.disputeOpened == false
                                              && prover == ECDSA.recover(message, abi.encodePacked(sigP)) 
                                              && verifier == ECDSA.recover(message, abi.encodePacked(sigV))) {

            // update state of the protocol
            state.proofSubmitted = true;

            emit stateEvent("Proof optimistically verified", state.proofSubmitted);

        } else {

            emit stateEvent("Proof verification failed", state.proofSubmitted);

        }   
    }

    function dispute(bytes memory CT_P_locked, 
                     bytes memory CT_V_unlocked) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        // check that current time is smaller than the timeout defined in Setup, and check proof has not yet been submitted, nor dispute raised
        if (block.timestamp < bridge.timelock && (state.coinsLocked == true && 
                                                  state.setupDone == true && 
                                                  state.proofSubmitted == false && 
                                                  state.disputeOpened == false)) {
            
            // check commitment transaction of P is locked and commitment transaction of V is unlocked
            require(ParseBTCLib.getTxTimelock(CT_P_locked) > bridge.timelock + bridge.timelockDisp, "CTxP is unlocked or its timelocked is smaller than/equal to T + T_rel"); 
            require(ParseBTCLib.getTxTimelock(CT_V_unlocked) == uint32(0), "CTxV is locked"); 

            // check transactions are well formed
            ParseBTCLib.HTLCData[2] memory htlc;
            ParseBTCLib.P2PKHData[2] memory p2pkh; 
            ParseBTCLib.OpReturnData memory opreturn;
            (htlc, p2pkh, opreturn) = ALBAHelper.checkTxAreWellFormed(CT_P_locked, CT_V_unlocked, bridge.fundTxScript, bridge.fundTxId);

            require(ALBAHelper.checkSignaturesEcrecover(CT_P_locked, CT_V_unlocked, bridge.fundTxScript, bridge.sighash, bridge.pkPUncompr, bridge.pkVUncompr) == true, "Invalid signatures");   

            // Check on the channel balance: e.g., require the balance of P is higher than X, with X = 10 in this example
            require(htlc[0].value > 10, "No sufficient amount of coins");

            // store balances
            paymentChan.balP = htlc[0].value;
            paymentChan.balV = htlc[1].value;
            // store also the revocation key of P for resolveInvalidDispute
            paymentChan.rKey = ALBAHelper.getRevSecret(CT_P_locked);
    
            // update state of the protocol
            state.disputeOpened = true;

            emit stateEvent("Dispute opened", state.disputeOpened); 

        } else {

            emit stateEvent("Failed to open dispute", state.disputeOpened);
        } 
    }

    // resolve valid dispute raised by P: V submits the unlocked version of the transaction
    function resolveValidDispute(bytes memory CT_P_unlocked) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        if (block.timestamp < (bridge.timelock + bridge.timelockDisp) && (state.coinsLocked == true && state.setupDone == true && state.proofSubmitted == false && state.disputeOpened == true)) {

            // check transaction is not locked
            require(ParseBTCLib.getTimelock(CT_P_unlocked) == bytes4(0), "CTxP locked");

            //check transaction spends the funding transaction
            require(ParseBTCLib.getInputsData(CT_P_unlocked).txid == bridge.fundTxId, "CTxP does not spend funding Tx");

            // check balance correctness
            ParseBTCLib.HTLCData memory htlc;
            ParseBTCLib.P2PKHData memory p2pkh; 
            ParseBTCLib.OpReturnData memory opreturn;
            (htlc, p2pkh, opreturn) = ParseBTCLib.getOutputsDataLNB(CT_P_unlocked); 
            require(htlc.value == paymentChan.balP, "The value in the HTLC does not corrispond to the value in the HTLC of P's locked transaction");
            require(p2pkh.value == paymentChan.balV, "The value in the p2pkh does not corrispond to the value in the HTLC of V's unlocked transaction");

            //check signature
            ALBAHelper.checkSignatureEcrecover(CT_P_unlocked, bridge.fundTxScript, bridge.sighash, bridge.pkVUncompr);    
        
            // update state of the protocol
            state.disputeClosedP = true;

            emit stateEvent("Valid Dispute resolved", state.disputeClosedP);

        } else {

            emit stateEvent("Valid Dispute unresolved", state.disputeClosedP);
        } 
    }

    // resolve invalid dispute raised by P: V provides the revocation secret for that proves P opened the dispute with an old state
    function resolveInvalidDispute(string memory revSecret) external {
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        if (block.timestamp < (bridge.timelock + bridge.timelockDisp) 
            && (state.coinsLocked == true  && state.setupDone == true && state.proofSubmitted == false && state.disputeOpened == true)
            && paymentChan.rKey == sha256(abi.encodePacked(sha256(bytes(revSecret))))) {

            // update state of the protocol
            state.disputeClosedV = true;

            emit stateEvent("Invalid Dispute resolved", state.disputeClosedV);

        } else {

            emit stateEvent("Invalid Dispute unresolved", state.disputeClosedV);
        } 
       
    }
    
    /// @notice Open a payment channel using the locked funds.
    /// @dev Both parties must have already locked coins and completed setup.
    /// @param _balP Initial balance of the prover inside the channel (in wei).
    /// @param _balV Initial balance of the verifier inside the channel (in wei).
    /// @param _rKey Initial revocation key for the first state.
    function openChannel(
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        require(fundsSettled == false, "Funds already settled");
        require(mode != OperationMode.Bridge, "Bridge mode active");
        require(state.coinsLocked == true, "Coins are not locked");
        require(channel.isOpen == false, "Channel already open");
        require(_balP + _balV == totalSupply, "Balances must equal total supply");

        bytes32 message = sha256(
            abi.encodePacked(
                address(this),
                uint256(0),
                _balP,
                _balV,
                _rKey,
                "openChannel"
            )
        );
        require(
            prover == ECDSA.recover(message, abi.encodePacked(_sigP)) &&
            verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "Invalid signatures for channel open"
        );

        channel.balP = _balP;
        channel.balV = _balV;
        channel.rKey = _rKey;
        channel.seqNumber = 0;
        channel.lastUpdated = block.timestamp;
        channel.latestStateHash = sha256(abi.encodePacked(uint256(0), _balP, _balV, _rKey));
        channel.isOpen = true;
        mode = OperationMode.Channel;

        emit channelOpened(_balP, _balV);
    }

    /// @notice Update the payment channel state with a new off-chain agreed balance.
    /// @dev Requires signatures from both prover and verifier over the new state.
    /// @param _seqNumber Monotonically increasing sequence number of the new state.
    /// @param _balP New balance of the prover (in wei).
    /// @param _balV New balance of the verifier (in wei).
    /// @param _rKey New revocation key associated to this state.
    /// @param _sigP Signature of the prover over the new state.
    /// @param _sigV Signature of the verifier over the new state.
    function updateChannel(
        uint256 _seqNumber,
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        require(fundsSettled == false, "Funds already settled");
        require(mode != OperationMode.Bridge, "Bridge mode active");
        require(channel.isOpen == true, "Channel is not open");
        require(_seqNumber > channel.seqNumber, "Sequence number not increasing");
        require(_balP + _balV == totalSupply, "Balances must equal total supply");

        // Both parties sign the new state to acknowledge the update.
        bytes32 message = sha256(
            abi.encodePacked(
                address(this),
                _seqNumber,
                _balP,
                _balV,
                _rKey,
                "updateChannel"
            )
        );

        require(
            prover == ECDSA.recover(message, abi.encodePacked(_sigP)) &&
            verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "Invalid signatures for channel update"
        );

        channel.balP = _balP;
        channel.balV = _balV;
        channel.rKey = _rKey;
        channel.seqNumber = _seqNumber;
        channel.lastUpdated = block.timestamp;
        channel.latestStateHash = sha256(abi.encodePacked(_seqNumber, _balP, _balV, _rKey));
        mode = OperationMode.Channel;

        emit channelUpdated(_seqNumber, _balP, _balV);
    }

    /// @notice Close the currently open channel and distribute funds according to the latest state.
    /// @dev Requires signatures from both parties over the close request using the latest sequence number.
    /// @param _sigP Signature of the prover over the close message.
    /// @param _sigV Signature of the verifier over the close message.
    function closeChannel(
        uint256 _seqNumber,
        uint256 _balP,
        uint256 _balV,
        bytes32 _rKey,
        bytes memory _sigP,
        bytes memory _sigV
    ) external {
        require(fundsSettled == false, "Funds already settled");
        require(mode != OperationMode.Bridge, "Bridge mode active");
        require(channel.isOpen == true, "Channel is not open");

        bytes32 providedHash = sha256(abi.encodePacked(_seqNumber, _balP, _balV, _rKey));
        require(providedHash == channel.latestStateHash, "State does not match latest verified state");

        bytes32 message = sha256(
            abi.encodePacked(
                address(this),
                channel.latestStateHash,
                "closeChannel"
            )
        );

        require(
            prover == ECDSA.recover(message, abi.encodePacked(_sigP)) &&
            verifier == ECDSA.recover(message, abi.encodePacked(_sigV)),
            "Invalid signatures for channel close"
        );

        require(_balP + _balV == totalSupply, "Inconsistent balances");

        channel.isOpen = false;
        fundsSettled = true;
        uint256 supply = totalSupply;
        totalSupply = 0;

        (bool sentP, ) = prover.call{value: _balP}("");
        require(sentP, "Failed to send ETH to prover");
        (bool sentV, ) = verifier.call{value: _balV}("");
        require(sentV, "Failed to send ETH to verifier");

        emit channelClosed(_seqNumber, _balP, _balV);
        // silence unused warning for supply in case optimizer changes
        supply;
    }
    
    function settle() external payable {
        require(fundsSettled == false, "Funds already settled");
        require(mode != OperationMode.Channel, "Channel mode active");
        mode = OperationMode.Bridge;

        if (state.proofSubmitted == true || (state.disputeOpened == true && state.disputeClosedP == true)) {

            // distribute funds in the contract according to mapping
            fundsSettled = true;
            uint256 supply = totalSupply;
            totalSupply = 0;
            uint256 amtP = (supply * (bridge.balDistr / 100));
            uint256 amtV = supply - amtP;
            (bool sentP, ) = prover.call{value: amtP}("");
            require(sentP, "Failed to send ETH");
            (bool sentV, ) = verifier.call{value: amtV}("");
            require(sentV, "Failed to send ETH");

            emit stateEvent("Valid proof submitted and funds distributed", true);

        } else if (state.disputeOpened == true && (state.disputeClosedP == false && state.disputeClosedV == false)) {

            // dispute has not been closed: give all funds in the contract to prover
            fundsSettled = true;
            uint256 supply2 = totalSupply;
            totalSupply = 0;
            (bool sentP, ) = prover.call{value: supply2}("");
            require(sentP, "Failed to send ETH");

            emit stateEvent("All funds given to P", true);

        } else if (state.disputeOpened == true && state.disputeClosedV == true ) {

            // dispute was opened with an old state: give all funds in the contract to verifier
            fundsSettled = true;
            uint256 supply3 = totalSupply;
            totalSupply = 0;
            (bool sentV, ) = verifier.call{value: supply3}("");
            require(sentV, "Failed to send ETH");

            emit stateEvent("All funds given to V", true);

        } else if (state.coinsLocked == true && state.setupDone == false) {

            // nobody submitted nothing: distribute funds according to inital state (give back to P and V the amount they contributed with)
            fundsSettled = true;
            uint256 amtP2 = initBalEth[prover];
            uint256 amtV2 = initBalEth[verifier];
            totalSupply = 0;
            (bool sentP, ) = prover.call{value: amtP2}("");
            require(sentP, "Failed to send ETH");
            (bool sentV, ) = verifier.call{value: amtV2}("");
            require(sentV, "Failed to send ETH");

            emit stateEvent("Funds distributed", true);

        }
    } 

}
