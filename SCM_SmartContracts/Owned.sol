
/// @author Pedro Azevedo prgazevedo@gmail.com
/// @title Scaffolding of a well behaved contract
contract Owned {
     address public owner;

     constructor() public {
         owner = msg.sender;
     }

     modifier onlyOwner {
         require(msg.sender == owner, "Only the contract owner may call this function");
         _;
     }

     function transferOwnership(address newOwner) public onlyOwner {
         owner = newOwner;
     }

     function destroy() public onlyOwner{
          selfdestruct(owner);
     }
     function () public payable{
          emit Deposit(msg.sender,msg.value);
     }

}
