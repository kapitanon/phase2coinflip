pragma solidity ^0.5.12;

import "./provableAPI_0.5.sol";
import "./Ownable.sol";

contract Coinflip is usingProvable, Ownable{

    struct Bet {
        address payable playerAddress;
        uint betValue;
        uint headsTails;
        uint playerWinnings;
        string message;
    }


    mapping(bytes32 => Bet) private waiting;
    mapping(address => Bet) private afterWaiting;


    uint public contractBalance;
    uint256 constant NUM_RANDOM_BYTES_REQUESTED = 1;
    uint256 public latestNumber;


    event logNewProvableQuery(string description);
    event generatedRandomNumber(uint256 randomNumber);
    event winner(address, string, uint, string);
    event loser(address, string, uint, string);


    address payable public owner = msg.sender;


    constructor() public payable{
        owner = msg.sender;
        contractBalance = msg.value;
    }


    function flip(uint oneZero) public payable {
        //Minimum .001 eth to maximum 10 eth
        require(msg.value > .001 ether && msg.value < 10 ether, "Please bet within our parameters");
        require(contractBalance >= (msg.value * 2), "We don't have enough funds");

        //Calling provable library function
        uint256 QUERY_EXECUTION_DELAY = 0;
        uint256 GAS_FOR_CALLBACK = 200000;
        bytes32 queryId = provable_newRandomDSQuery(
            QUERY_EXECUTION_DELAY,
            NUM_RANDOM_BYTES_REQUESTED,
            GAS_FOR_CALLBACK
            );


        //Adding user to mapping with address, bet, and queryID
        Bet memory newBetter;
        newBetter.playerAddress = msg.sender;
        newBetter.betValue = msg.value;
        newBetter.headsTails = oneZero;

        waiting[queryId] = newBetter;

        emit logNewProvableQuery("Provable query was sent, standing by for the answer...");

    }



    function __callback(bytes32 _queryID, string memory _result, bytes memory _proof) public {
        require(msg.sender == provable_cbAddress());

        //Merge mappings
        Bet memory postBetter;

        postBetter.playerAddress = waiting[_queryID].playerAddress;
        postBetter.betValue = waiting[_queryID].betValue;
        postBetter.playerWinnings = waiting[_queryID].playerWinnings;


        //Deleting waiting mapping except for headsTails
        delete(waiting[_queryID].playerAddress);
        waiting[_queryID].betValue = 0;
        waiting[_queryID].playerWinnings = 0;

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(_result))) % 2;
        latestNumber = randomNumber;

         //Variable to check if user wins
        uint headsTails = waiting[_queryID].headsTails;
        //Clear waiting mapping heads or tails value
        delete(waiting[_queryID].headsTails);

        //Winner
        if(headsTails == latestNumber){
            postBetter.playerWinnings += postBetter.betValue * 2;
            contractBalance -= postBetter.betValue;
            postBetter.message = "You won!";
            afterWaiting[postBetter.playerAddress] = postBetter;
            emit winner(postBetter.playerAddress, " won ", postBetter.betValue, " wei!");
        //Loser
        } else {
            emit loser(postBetter.playerAddress, " lost ", postBetter.betValue, " wei...");
            contractBalance += postBetter.betValue;
            postBetter.betValue = 0;
            postBetter.message = "You lost...";
            afterWaiting[postBetter.playerAddress] = postBetter;
        }
        emit generatedRandomNumber(randomNumber);
    }


    function getWinningsBalance() public view returns(uint){
        return(afterWaiting[msg.sender].playerWinnings);
    }


    //adding another getter to ease web3 integration
    function getContractBalance() public view returns(uint){
        return(address(this).balance);
    }

    function addFunds() public payable{
      contractBalance += msg.value;
    }


    function userWithdraw() public {
        require(result[msg.sender].playerWinnings > 0, "You don't have any funds");
        //require msg.sender is the player in Bet struct after this
        uint toTransfer = afterWaiting[msg.sender].playerWinnings;
        contractBalance -= toTransfer;
        msg.sender.transfer(toTransfer);
        assert(afterWaiting[msg.sender].playerWinnings == 0 && toTransfer == 0);
    }


    function ownerWithdrawAll() public onlyOwner{
        require(msg.sender == owner);
        uint toTransfer = contractBalance;
        contractBalance -= contractBalance;
        msg.sender.transfer(toTransfer);
        assert(contractBalance == 0 && toTransfer == 0);
    }


}
