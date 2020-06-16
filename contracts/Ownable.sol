pragma solidity ^0.5.12;

contract Ownable {
  address public owner;

  modifier onlyOwner(){
    require(msg.sender == owner, "Not owner");
    _;
  }

  constructor() public {
    owner = msg.sender;
  }
}
