//https://solidity.readthedocs.io/en/v0.5.11/index.html
///@dev: this version requires conversion of string to string memory
pragma solidity ^0.5.11;

///@dev: The ABI v2 encoder allows structs, nested and dynamic variables to be passed/returned into/from functions/events
///@dev:  do not use ABIEncoderV2 on live/release deployments
pragma experimental ABIEncoderV2;

import "./Owned.sol";

/// @author Pedro Azevedo prgazevedo@gmail.com
/// @title SCM is a Supply Chain Management contract supporting traceability, provenance and chain of custody
contract SCM is Owned{

  /**
  /* SCM Actor Management
  */
  /// SCM Actor struct
  struct SCActor {
      uint40 companyPrefix; // store the prefix to validate against the EPC
      address actorAddress;
      actorType actorRole;
      bool      registered;
      bool      validated;
  }

  enum actorType { SUPPLIER, TRANSFORMATION, LOGISTICS, RETAILERS, CUSTOMER }


  ///  mapping with struct has some advantages for unique Ids - https://ethfiddle.com/PgDM-drAc9
  mapping (address => SCActor) scActors;
  mapping (uint40 => address) companyPrefixToactorAddress;

  /// ValidateID: onlyValidator
  modifier onlyValidator{
    require(msg.sender == validator,"Only the validator may call this function");
    _;
  }

  /// After call registerActor(): Event to request import of ID and certificates of SC Actor
  event importIDCertificate(
        address actorAddress_,
        uint prefix_
  );

  /// After event importIDCertificate(): Event to request validation of ID and certificates of SC Actor
  event RequestKYC(
        address actorAddress_,
        uint prefix_
  );

  /// After call registerProduct(): Event to request import of ID and certificates of product
  event importEPCCertificate(
        address callerAddress_,
        uint96 EPC_
  );

  /// Event to request validation of ID and certificates of SC Actor
  event RequestKYP(
        address actorAddress_,
        uint96 EPC_
  );


  /// @notice  Implements the use case: register Actor
  /// @dev Emits event to start the use case: ValidateID (access control)
  function registerActor (address actorAddress_, uint40 prefix_, actorType  actorRole_) public  {
    scActors[actorAddress_].companyPrefix=prefix_;
    scActors[actorAddress_].actorAddress=msg.sender;
    scActors[actorAddress_].actorRole=actorRole_;
    scActors[actorAddress_].registered=true;
    companyPrefixToactorAddress[prefix_]=msg.sender;
      //Start the SCA certificate validation: import the ID and Certificates
    emit importIDCertificate(actorAddress_, prefix_);

  }

  /**
   /* Interworking with WallId Architecture
   */

  /// @notice called by User after successful importIDCertificate
  function IDCertificateImported(address actorAddress_, uint40 prefix_) public{
      emit RequestKYC(actorAddress_, prefix_);
  }

  /// @notice Called by CertificateValidator after KYC(Actor) has been completed - only CertificateValidator address may call this
  function KYCcompleted(address actorAddress_) public onlyValidator{
    setActorAsValidated(actorAddress_);
  }

  /// @notice called by User after successful importEPCCertificate
  function ProductCertificateImported(address actorAddress_, uint96 EPC_) public{
      emit RequestKYP(actorAddress_, EPC_);
  }

  /// @notice Called by CertificateValidator after KYP (Product) has been completed - only CertificateValidator address may call this
  function KYPcompleted(uint96 EPC_) public onlyValidator{
      setProductAsCertified(EPC_);
  }



   /**
    /* A Certificate Validator off chain (SC Manager) is Required
    */

  address validator;

  /// ValidateID: Set validator wallet address
  function setValidator(address validatorAddress_) public onlyOwner{
    validator=validatorAddress_;
  }
  /// Helper function
  function setActorAsValidated(address actorAddress_) internal returns (bool ret) {
       scActors[actorAddress_].validated=true;
       return true;
  }
  
  /// Helper function
  function getActorAddress(uint40 prefix_) public view returns (address) {
    return companyPrefixToactorAddress[prefix_];
  }
  /// Helper function
  function getActorRole(address actorAddress_) public view returns (actorType) {
    return scActors[actorAddress_].actorRole;
  }
  /// Helper function
  function isActorValidated(address actorAddress_) public view returns(bool ret){
    return scActors[actorAddress_].validated;
  }

    /// Helper function
  function isActorRegistered(address addressToCheck_) public view returns(bool ret){
    return scActors[addressToCheck_].registered;
  }

  /// Only supplier can register products
  modifier isSupplier {
      require(getActorRole(msg.sender) == actorType.SUPPLIER, "Only suppliers can register products");
      _;
  }

  /// Only supplier can register products
  modifier isTransformation {
      require(getActorRole(msg.sender) == actorType.TRANSFORMATION, "Only Transformation actor can transform products");
      _;
  }

  /// Only supplier can register products
  modifier isNotCustomer {
      require(getActorRole(msg.sender) != actorType.CUSTOMER, "Function not accessible to Customers");
      _;
  }

  /// Only validated SCM Actors can operate on products
  modifier isAddressFromCaller(address actorAddress_) {
    require(msg.sender==actorAddress_, "Only caller/owner may call this");
      _;
  }

  /// Only validated SCM Actors can operate on products
    modifier isAddressValidated(address addressToValidate_) {
      require(isActorValidated(addressToValidate_), "Only validated SC Actors can operate");
        _;
    }

    /// Only validated SCM Actors can operate on products
    modifier isAddressRegistered(address addressToCheck_) {
      require(isActorRegistered(addressToCheck_), "Address is not a registered SC Actor");
        _;
    }

  /**
  /* SCM Product Management
  */

    struct productData {
        address owner;
        custodyState custody;
        bool  exists;
        address nextOwner;
        geoPosition location;
        uint96 myEPC;
        bool hasCertificate;
        //no need to add Time data since all Transactions are visible and TimeStamped
    }

    enum custodyState {inControl, inTransfer, lost, consumed}

    /// 32 bits seems enough for location database - https://www.thethingsnetwork.org/forum/t/best-practices-when-sending-gps-location-data/1242
    struct geoPosition{
      uint32 latitude;
      uint32 longitude;
      uint16 altitude;
    }

    /// Map with all products by EPC
    mapping (uint96 => productData) public productMap;

    struct ownedEPCs {
      uint96[] myOwnedEPCS; //dynamic size array
      mapping(uint96 => uint) epcPointers;
    }
    /// Map with products by owner
    mapping (address => ownedEPCs) internal ownerProducts;

    /**
    /* SCM Product Function Modifiers
    */

    /// EPC format must be correct
    modifier isEPCcorrect(uint96 EPC_,address callerAddress_){
      require(verifyEPC(EPC_,callerAddress_), "The EPC does not belong to the caller company - malformed/incorrect EPC");
        _;
    }

    /// EPC must not have been registered
    modifier notRegisteredEPC(uint96 EPC_) {
        require(!isMember(EPC_),"Product already registered. Enter a different EPC");
        _;
    }

    /// EPC must have been registered
    modifier isRegisteredEPC(uint96 EPC_) {
       require(isMember(EPC_),"Product not registered. Register product first");
        _;
    }
    modifier ownerHasProducts(){
        require(haveProducts(msg.sender),"Caller does not have any products. Add products first");
      _;
    }

    /// EPC must belong to caller
    modifier isCallerCurrentOwner(uint96 EPC_){
      require(getCurrentOwner(EPC_)==msg.sender,"Caller is not the product owner. Request transfer ownership first");
      _;
    }

    /// EPC state must be inControl before transfer
    modifier isStateOwned(uint96 EPC_){
      require(getCurrentState(EPC_)==custodyState.inControl, "Current state of product does not allow transfer");
      _;
    }

     /// EPC nextOwner was marked as the caller
    modifier isPreviousOwner(uint96 EPC_,address previousOwner_){
      require(getCurrentOwner(EPC_)==previousOwner_,"That  owner did not sign off this product. Request transfer ownership first");
      _;
    }

    /// EPC nextOwner was marked as the caller
    modifier isCallerNextOwner(uint96 EPC_){
      require(getNextOwner(EPC_)==msg.sender,"Caller is not signed as the next product owner. Request transfer ownership first");
      _;
    }

    /// EPC state must be inTransfer before final change of custody
    modifier isStateinTransfer(uint96 EPC_){
      require(getCurrentState(EPC_)==custodyState.inTransfer, "Current state of product does not allow transfer");
     _;
    }


    /**
    /* SCM Product Helper Functions
    */


    /// Helper function
    function isMember(uint96 EPC_) internal view returns(bool retExists) {
          return productMap[EPC_].exists;
    }
    /// Helper function
    function extractPrefix(uint96 EPC_) internal pure returns (uint40 ret){
      return uint40(EPC_ >> 42);
    }
    /// Helper function
    function verifyEPC(uint96 EPC_,address callerAddress_) internal view returns (bool ret){
      if( getActorAddress(extractPrefix(EPC_)) == callerAddress_ ) return true;
      else return false;
    }


    /// Helper function
    function haveProducts(address ownerAddress_) internal view returns (bool ret){
      if(ownerProducts[ownerAddress_].myOwnedEPCS.length != 0) return true;
      else return false;
    }

    ///  Helper function
    function getEPCPointer(address ownerAddress_, uint96 EPC_) internal view returns (uint ret){
       return ownerProducts[ownerAddress_].epcPointers[EPC_];
    }

    /// Helper function
    function existsEPC(address ownerAddress_, uint96 EPC_) internal view returns (bool ret){
      if(ownerProducts[ownerAddress_].myOwnedEPCS[getEPCPointer(ownerAddress_,EPC_)] == EPC_) return true;
      else return false;
    }
    ///  Helper function
    function isEPCOwned(address ownerAddress_, uint96 EPC_) public view returns(bool isOwned) {
        if(!haveProducts(ownerAddress_)) return false;
        else return existsEPC(ownerAddress_,EPC_);
    }
    /// Helper function - MUST TEST
    function deleteEPC(address ownerAddress_, uint96 EPC_) internal {
        ownedEPCs storage temp = ownerProducts[ownerAddress_];
        require(isEPCOwned(ownerAddress_, EPC_));
        uint indexToDelete = temp.epcPointers[EPC_]; //no need to delete epcPointers => initialized HashMap
        temp.myOwnedEPCS[indexToDelete] = temp.myOwnedEPCS[temp.myOwnedEPCS.length-1]; //move to Last
        temp.myOwnedEPCS.length--; //deleteLast
    }
    /// Helper function - MUST TEST
    function addEPC(address ownerAddress_, uint96 EPC_) internal {
        uint epcPointer = ownerProducts[ownerAddress_].myOwnedEPCS.push(EPC_)-1;
        ownerProducts[ownerAddress_].epcPointers[EPC_]=epcPointer;
    }

    /// @notice Implements the use case:  getEPCBalance
    /// Helper function - MUST TEST
    function getEPCBalance(address ownerAddress_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isAddressFromCaller(ownerAddress_)
    public view returns (uint ret){
        if(haveProducts(ownerAddress_))  return ownerProducts[ownerAddress_].myOwnedEPCS.length;
        else return 0;
    }

    /// @notice  Implements the use case:  getMyEPCs
    /// Helper function - MUST TEST
    function getMyEPCs(address ownerAddress_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isAddressFromCaller(ownerAddress_)
    ownerHasProducts public view returns (uint96[] memory ret){
        require(haveProducts(ownerAddress_),"You have no products registered");
        return ownerProducts[msg.sender].myOwnedEPCS;
    }

    /**
    /* SCM Product Use Case Functions
    */

    /// @notice  Implements the use case:  getCurrentOwner
    function getCurrentOwner(uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (address retOwner) {
        return productMap[EPC_].owner;
    }

    /// @notice  Implements the use case:  getNextOwner
    function getNextOwner(uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) view public returns (address ret_nextOwnerAddress) {
        return productMap[EPC_].nextOwner;
    }

    /// @notice Implements the use case: getCurrentState
    function getCurrentState(uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (custodyState ret_state) {
        return productMap[EPC_].custody;
    }
    /// @notice Implements the use case: getCurrentLocation
    function getCurrentLocation(uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (geoPosition memory ret_location) {
        return productMap[EPC_].location;
    }

    /// @notice Implements the use case: isProductCertified
    /// @dev This is accessible by final Customers
    function isProductCertified(uint96 EPC_)
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (bool ret) {
        return productMap[EPC_].hasCertificate;
    }

    /// @notice  Implements the use case: setCurrentState
    function setCurrentState(uint96 EPC_,custodyState state_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isCallerCurrentOwner(EPC_) public returns (bool ret) {
         productMap[EPC_].custody= state_;
         return true;
    }

    /// @notice Implements the use case: setCurrentLocation
    function setCurrentLocation(uint96 EPC_, geoPosition memory location_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isCallerCurrentOwner(EPC_) public returns (bool ret) {
         productMap[EPC_].location=location_;
         return true;
    }

    /// @notice Implements the use case: setProductAsCertified
    function setProductAsCertified(uint96 EPC_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isCallerCurrentOwner(EPC_) public returns (bool ret) {
         productMap[EPC_].hasCertificate=true;
         return true;
    }


    /// @notice  Implements the use case: register Product
    // https://github.com/ethereum/solidity/releases/tag/v0.5.7 has fix for ABIEncoderV2
    function registerProduct(address callerAddress_, uint96 EPC_, geoPosition memory _location  )
    isAddressValidated(msg.sender)
    isSupplier //TODO: check access clash with Transformation
    isAddressFromCaller(callerAddress_)
    isEPCcorrect(EPC_,callerAddress_)
    notRegisteredEPC(EPC_) public returns (bool ret){
        productMap[EPC_].owner = callerAddress_;
        productMap[EPC_].custody = custodyState.inControl;
        productMap[EPC_].exists = true;
        productMap[EPC_].nextOwner = callerAddress_;
        productMap[EPC_].location = _location;
        productMap[EPC_].myEPC = EPC_;
        addEPC(callerAddress_, EPC_);
        //Start the Product certificate validation: import the ID and Certificates
        emit importEPCCertificate(callerAddress_, EPC_);
        return true;
    }


    /// @notice Implements the use case:  transfer Ownership TO
    function transferTO( address addressTO_, uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isAddressValidated(addressTO_)
    isRegisteredEPC(EPC_)
    isCallerCurrentOwner(EPC_)
    isStateOwned(EPC_) public returns (bool ret){
        productMap[EPC_].custody = custodyState.inTransfer;
        productMap[EPC_].nextOwner = addressTO_;
        //TODO replace return with event
        return true;
    }

    /// @notice Implements the use case:  transfer Ownership TO
    function receiveFROM( address addressFROM_, uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isPreviousOwner(EPC_,addressFROM_)
    isRegisteredEPC(EPC_)
    isCallerNextOwner(EPC_)
    isStateinTransfer(EPC_) public returns (bool ret){
        productMap[EPC_].owner = msg.sender;
        productMap[EPC_].custody = custodyState.inControl;
        productMap[EPC_].nextOwner = msg.sender;
        //TODO replace return with event
        return true;
    }

    /// @notice Implements the use case:  lostProduct
    function lostProduct(uint96 EPC_)
    isNotCustomer
    isAddressValidated(msg.sender)
    isPreviousOwner(EPC_,msg.sender)
    isRegisteredEPC(EPC_) public returns (bool ret){
        setCurrentState( EPC_,custodyState.lost );
        productMap[EPC_].owner = msg.sender;
        productMap[EPC_].nextOwner = msg.sender;
        deleteEPC(msg.sender, EPC_);
        //TODO replace return with event
        return true;
    }


    /// @notice Implements the use case:  transformProduct
    /// @dev first register new EPC --> TransformProduct
    function transformProduct(uint96 oldEPC_,uint96 newEPC_)
    isTransformation
    isAddressValidated(msg.sender)
    isPreviousOwner(oldEPC_,msg.sender)
    isRegisteredEPC(oldEPC_)
    isRegisteredEPC(newEPC_)
    isStateOwned(oldEPC_) public returns (bool ret){
        setCurrentState( oldEPC_,custodyState.consumed );
        productMap[oldEPC_].owner = msg.sender;
        productMap[oldEPC_].nextOwner = msg.sender;
        deleteEPC(msg.sender, oldEPC_);
        //TODO replace return with event
        return true;
    }


}
//END
