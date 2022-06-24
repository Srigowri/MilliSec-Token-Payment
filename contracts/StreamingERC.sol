// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";
contract Streaming is ERC20{
    uint256 private noOfTokensPerEth=10;
    uint256 public streamIdCounter;
    // uint256 public immutable decimal;
    uint256 public _totalSupply=1000000000000000000000000;
    string private _name;
    string private _symbol;
    address private immutable _owner;
    
    mapping(uint256 => Stream) private streams;        
    modifier onlySenderOrRecipient(uint256 streamId) {
        require(
            msg.sender == streams[streamId].sender || msg.sender == streams[streamId].recipient,
            "caller is not the sender or the recipient of the stream"
        );
        _;
    }
    modifier validStream(uint256 streamId){
      require(streams[streamId].sender  != address(0x00) && streams[streamId].recipient !=  address(0x00) ,"stream does not exist");  
      _;
    }

    struct Stream {
        address recipient;
        address sender;
        uint256 deposit;
        uint256 startTime;
        uint256 stopTime;
        uint256 rate;
        uint256 balance;
    }
    
    event CancelStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,  
        uint256 deposit,      
        uint256 balance      
    );

    event CreateStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 deposit,
        uint256 startTime,
        uint256 stopTime
    );

    event WithdrawFromStream(uint256 indexed streamId, address indexed recipient);
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        _owner  = msg.sender;
        _name = name;
        _symbol = symbol;                
        _mint(msg.sender, _totalSupply );
    }
    
    receive() external payable {}

    function createStream(
            address recipient,            
            uint256 startTime,
            uint256 stopTime
    ) external payable returns (uint256 streamId) {
        
        // the stream creator pays in ether to get some tokens to be sent to the receiver.
        require(recipient != address(0x00), "Stream to the zero address");
        require(recipient != address(this), "Stream to the contract itself");
        require(recipient != msg.sender, "Stream to the caller");
        require(msg.value > 0, "Deposit is equal to zero");
        require(startTime >= block.timestamp, "Start time before block timestamp");

        //msg.value must be in wei
        uint256 tokensToBeSent = msg.value * noOfTokensPerEth;
        require(balanceOf(_owner) >= tokensToBeSent, "Contract has insufficient tokens");

        uint256 duration = stopTime - startTime;
        
        require(tokensToBeSent >= duration, "Deposit smaller than duration");
        require(tokensToBeSent % duration == 0, "Deposit is not a multiple of time delta");
        
        streamIdCounter += 1;
        uint256 currentStreamId = streamIdCounter;
        
        // Rate Per second
        uint256 rate = tokensToBeSent / duration;
        
        streams[currentStreamId] = Stream({
           balance: tokensToBeSent,
           deposit: tokensToBeSent,
           rate: rate,
           recipient: recipient,
           sender: msg.sender,
           startTime: startTime,
           stopTime: stopTime
        });

        
        emit CreateStream(currentStreamId, msg.sender, recipient, tokensToBeSent, startTime, stopTime);
        emit Transfer(_owner, msg.sender, tokensToBeSent);
        _transfer(_owner, msg.sender, tokensToBeSent );        
        payable(_owner).transfer(msg.value); // send ether to the contract owner for giving the tokens
        return currentStreamId;
    }
    function cancelStream(uint256 streamId) external validStream(streamId) onlySenderOrRecipient(streamId) {
        
        Stream memory stream = streams[streamId];
        address sender = stream.sender;
        address recipient = stream.recipient;
        uint256 deposit = stream.deposit;
                      
        uint256 senderBalance = balanceOfWho(streamId, sender);
        uint256 recipientBalance = balanceOfWho(streamId, recipient);

        // require(senderBalance >= recipientBalance, "contract has insufficient balance");        

        streams[streamId] = Stream({
           balance: 0,
           deposit: 0,
           rate: 0,
           recipient: address(0x00),
           sender: address(0x00),
           startTime: 0,
           stopTime: 0
        });
        // (bool successRecipient, ) = payable(recipient).call{value: recipientBalance}("");
        // (bool successSender, ) = payable(sender).call{value: senderBalance}("");

        _transfer(sender, recipient, recipientBalance);  //transfer remaining tokens to recipient
        uint256 senderBalanceEth = senderBalance/noOfTokensPerEth; //pay eth equivalent of remaining token to the sender
        require(senderBalanceEth<=address(this).balance,"Contract has insufficient balance");
        payable(sender).call{value: senderBalanceEth};
        // require(successRecipient && successSender , "Contract execution failed");                
        // emit CancelStream(streamId, sender,recipient, deposit, stream.balance );
        emit CancelStream(streamId, sender,recipient, deposit, 0 );        
    }

    function balanceOfWho( uint256 streamId, address who)  public view validStream(streamId)  returns (uint256 balance) {
        Stream memory stream = streams[streamId];
        uint256 elapsedTime = elapsedTimeFor(streamId);
        uint256 due = elapsedTime * stream.rate;
        
        if (who == stream.recipient) {
            return due;
        } else if (who == stream.sender) {
            return stream.balance - due;
        } else {
            return 0;
        }
    }
        
        
    function elapsedTimeFor(uint256 streamId) private view returns (uint256 delta) {
        Stream memory stream = streams[streamId];
        
        // Before the start of the stream
        if ((block.timestamp <= stream.startTime) || (stream.startTime >= stream.stopTime)) return 0;
        
        // During the stream
        if (block.timestamp < stream.stopTime) return block.timestamp - stream.startTime;
        
        // After the end of the stream
        return stream.stopTime - stream.startTime;
    }
    
    function withdrawFromStream(uint256 streamId)  external validStream(streamId){

        Stream storage stream = streams[streamId];
        address sender = stream.sender;
        address recipient = stream.recipient;
        require(msg.sender == recipient, "invalid recipient of the stream");
        uint256 balance = balanceOfWho(streamId, recipient);
        require(balanceOf(sender) >= balance, "sender has insufficient tokens in the stream");
        require(balance > 0, "Available balance is 0");
        
        stream.startTime = block.timestamp;
        _transfer(sender, recipient, balance) ;       
        // stream.balance -= balance;                
        
        emit WithdrawFromStream(streamId, recipient);
    }

    function getStream(uint256 streamId)
        external
        view
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            uint256 startTime,
            uint256 stopTime,
            uint256 rate
        )
    {
        Stream memory stream = streams[streamId];
        sender = stream.sender;
        recipient = stream.recipient;
        deposit = stream.deposit;
        startTime = stream.startTime;
        stopTime = stream.stopTime;
        rate = stream.rate;
    }
    
}