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

  enum actorType { SUPPLIER, TRANSFORMATION, LOGISTICS, RETAILERS, MANAGER }


  ///  mapping with struct has some advantages for unique Ids - https://ethfiddle.com/PgDM-drAc9
  mapping (address => SCActor) scActors;
  mapping (uint40 => address) companyPrefixToactorAddress;


  /// After call registerActor(): Event to request import of ID and certificates of SC Actor
  event importIDCertificate(
        address actorAddress,
        uint prefix
  );

  /// After event importIDCertificate(): Event to request validation of ID and certificates of SC Actor
  event RequestKYC(
        address actorAddress,
        uint prefix
  );

  /// After call registerProduct(): Event to request import of ID and certificates of product
  event importEPCCertificate(
        address callerAddress,
        uint96 EPC
  );

  /// Event to request validation of ID and certificates of SC Actor
  event RequestKYP(
        address certificateOwnerAddress,
        //the Actor that will be able to view the certificate via the SCM url
        address viewerAddress,
        uint96 EPC
  );

   /**
    /* The Certificate Validator role  (SCM Manager) is Required
    * The SCM Manager/Validator is responsible to validate the SCA identities
    * (hash verification has to be done off chain due to EVM hasing costs)
    * and when product certificates are imported into the Store he will be the owner/ID
    * of the product certificates in order to be able to respond to other SCAs/customer certificate
    * verification requests
    */

  address validatorAddress;


  /// ValidateID: onlyValidator
  modifier onlyValidator{
    require(msg.sender == validatorAddress,"Only the validator may call this function");
    _;
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
  modifier isNotManager {
      require(getActorRole(msg.sender) != actorType.MANAGER, "Function not accessible to SC Manager");
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

    /// ValidateID: Set validator wallet address
    function setValidator(address validatorAddress_) public onlyOwner{
      validatorAddress=validatorAddress_;
      scActors[validatorAddress_].actorAddress=validatorAddress_;
      scActors[validatorAddress_].actorRole=actorType.MANAGER;
      scActors[validatorAddress_].registered=true;
      scActors[validatorAddress_].validated=true;
    }
    /// Helper function
    function setActorAsValidated(address actorAddress_, bool validated_) internal returns (bool ret) {
         scActors[actorAddress_].validated=validated_;
         return true;
    }

    /// Helper function
    function getActorAddress(uint40 prefix_) internal view returns (address) {
      return companyPrefixToactorAddress[prefix_];
    }
    /// Helper function
    function getActorRole(address actorAddress_) internal view returns (actorType) {
      return scActors[actorAddress_].actorRole;
    }
    /// Helper function
    function isActorValidated(address actorAddress_) internal view returns(bool ret){
      return scActors[actorAddress_].validated;
    }

      /// Helper function
    function isActorRegistered(address addressToCheck_) internal view returns(bool ret){
      return scActors[addressToCheck_].registered;
    }


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
      setActorAsValidated(actorAddress_, true);
    }

    /// @notice called by User after successful importEPCCertificate
    function ProductCertificateImported(address actorAddress_, uint96 EPC_) public{
        //request KYP for the ownerAddress which in this case is also the the viewerAddress
        emit RequestKYP(actorAddress_, actorAddress_, EPC_);
    }

    /// @notice Called by CertificateValidator after KYP (Product) has been completed - only CertificateValidator address may call this
    function KYPcompleted(uint96 EPC_) public onlyValidator{
        setProductAsCertified(EPC_, true);
    }


  /**
  /* SCM Product Management
  */

    struct productData {
        address certificateOwner; //references the certificate owner
        uint96 certificateEPC; //references the EPC that has certificate
        bool hasCertificate;
        address owner; //references the current owner of the
        custodyState custody;
        bool  exists;
        address nextOwner;
        geoPosition location;
        uint96 previousEPC; //used to maintain traceability of certificates
        uint96 myEPC;

        //no need to add Time data since all Transactions are visible and TimeStamped
    }

    enum custodyState {inControl, inTransfer, lost, consumed, sold}

    /// 32 bits seems enough for location database - https://www.thethingsnetwork.org/forum/t/best-practices-when-sending-gps-location-data/1242
    struct geoPosition{
      uint32 latitude;
      uint32 longitude;
      uint16 altitude;
    }

    /// Map with all products by EPC
    mapping (uint96 => productData) public productMap;

    /* reduce storage by removing product balance per owner
    struct ownedEPCs {
      uint96[] myOwnedEPCS; //dynamic size array
      mapping(uint96 => uint) epcPointers;
    }
    /// Map with products by owner
    mapping (address => ownedEPCs) internal ownerProducts;
    */

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
    /*
    modifier ownerHasProducts(){
        require(haveProducts(msg.sender),"Caller does not have any products. Add products first");
      _;
    }
    */

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

    /// EPC validated flag must be set before certificates can be retrieved
    modifier isEPCCertified(uint96 EPC_){
      require(isEPCValidated(EPC_), "Product with given EPC is not certified");
     _;
    }

    /**
    /* SCM Product Internal Helper Functions
    */

    /// Internal Helper function
    function isMember(uint96 EPC_) internal view returns(bool retExists) {
          return productMap[EPC_].exists;
    }
    /// Helper function
    function extractPrefix(uint96 EPC_) internal pure returns (uint40 ret){
      return uint40(EPC_ >> 42);
    }
    /// Internal Helper function
    function verifyEPC(uint96 EPC_,address callerAddress_) internal view returns (bool ret){
      if( getActorAddress(extractPrefix(EPC_)) == callerAddress_ ) return true;
      else return false;
    }

    /// Internal Helper function
    function isEPCValidated(uint96 EPC_) internal view returns (bool ret){
      if( productMap[EPC_].hasCertificate==true ) return true;
      else return false;
    }

    /// Internal Helper function
    function isStateSold(uint96 EPC_) internal view returns (bool ret){
      if(getCurrentState(EPC_)==custodyState.sold) return true;
      else return false;
    }

    /*  next code commented to remove balance of products
    /// Internal Helper function

    function haveProducts(address ownerAddress_) internal view returns (bool ret){
      if(ownerProducts[ownerAddress_].myOwnedEPCS.length != 0) return true;
      else return false;
    }

    ///  Helper function
    function getEPCPointer(address ownerAddress_, uint96 EPC_) internal view returns (uint ret){
       return ownerProducts[ownerAddress_].epcPointers[EPC_];
    }

    /// Internal Helper function
    function existsEPC(address ownerAddress_, uint96 EPC_) internal view returns (bool ret){
      if(ownerProducts[ownerAddress_].myOwnedEPCS[getEPCPointer(ownerAddress_,EPC_)] == EPC_) return true;
      else return false;
    }

    /// Internal Helper function
    function isEPCOwned(address ownerAddress_, uint96 EPC_) internal view returns(bool isOwned) {
        if(!haveProducts(ownerAddress_)) return false;
        else return existsEPC(ownerAddress_,EPC_);
    }
    /// Internal Helper function - TODO TEST
    function deleteEPC(address ownerAddress_, uint96 EPC_) internal {
        ownedEPCs storage temp = ownerProducts[ownerAddress_];
        require(isEPCOwned(ownerAddress_, EPC_));
        uint indexToDelete = temp.epcPointers[EPC_]; //no need to delete epcPointers => initialized HashMap
        temp.myOwnedEPCS[indexToDelete] = temp.myOwnedEPCS[temp.myOwnedEPCS.length-1]; //move to Last
        temp.myOwnedEPCS.length--; //deleteLast
    }
    /// Internal Helper function - TODO TEST
    function addEPC(address ownerAddress_, uint96 EPC_) internal {
        uint epcPointer = ownerProducts[ownerAddress_].myOwnedEPCS.push(EPC_)-1;
        ownerProducts[ownerAddress_].epcPointers[EPC_]=epcPointer;
    }
    */
    /// @notice When the product is to be sold the owner is the SC Manager
    function setManagerAsOwner( uint96 EPC_) internal returns (bool ret){
        productMap[EPC_].owner = validatorAddress;
        productMap[EPC_].nextOwner = validatorAddress;
        return true;
    }
    /// Internal Helper function
    /// SCAs can view certificate and Customer by proxy if product is in sale (role=MANAGER)
    function isCallerAllowedToViewCertificate(address callerAddress_,uint96 EPC_) internal view returns(bool retAllowed){
      //either it is the owner of the product
      if(getCurrentOwner(EPC_)==callerAddress_) return true;
      //or it is a customer by proxy of SC manager
      else if(validatorAddress==callerAddress_)
      {
        if(isStateSold(EPC_)) return true;
        else return false;
      }
      else return false;
    }

    /**
    /* SCM Product GET/SET Use case functions
    */

    /* next code commented to remove balance of products
    /// @notice Implements the use case:  getEPCBalance
    /// TODO TEST
    function getEPCBalance(address ownerAddress_)
    isNotManager
    isAddressValidated(msg.sender)
    isAddressFromCaller(ownerAddress_)
    public view returns (uint ret){
        if(haveProducts(ownerAddress_))  return ownerProducts[ownerAddress_].myOwnedEPCS.length;
        else return 0;
    }

    /// @notice  Implements the use case:  getMyEPCs
    /// TODO TEST
    function getMyEPCs(address ownerAddress_)
    isNotManager
    isAddressValidated(msg.sender)
    isAddressFromCaller(ownerAddress_)
    ownerHasProducts public view returns (uint96[] memory ret){
        require(haveProducts(ownerAddress_),"You have no products registered");
        return ownerProducts[msg.sender].myOwnedEPCS;
    }
    */

    /// @notice  Implements the use case:  getCurrentOwner
    function getCurrentOwner(uint96 EPC_)
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (address retOwner) {
        return productMap[EPC_].owner;
    }

    /// @notice  Implements the use case:  getNextOwner
    function getNextOwner(uint96 EPC_)
    isNotManager
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) view public returns (address ret_nextOwnerAddress) {
        return productMap[EPC_].nextOwner;
    }

    /// @notice Implements the use case: getCurrentState
    function getCurrentState(uint96 EPC_)
    isCallerCurrentOwner(EPC_) //only owner can view the state
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (custodyState ret_state) {
        return productMap[EPC_].custody;
    }
    /// @notice Implements the use case: getCurrentLocation
    function getCurrentLocation(uint96 EPC_)
    isCallerCurrentOwner(EPC_) //only owner can view the state
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_) public view returns (geoPosition memory ret_location) {
        return productMap[EPC_].location;
    }

    /// @notice Helper function: getCertificateOwner
    function getCertificateOwner(uint96 EPC_)
    isCallerCurrentOwner(EPC_) //only owner can view the state
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_)
    isEPCCertified(EPC_) public view returns (address ret_address) {
        return productMap[EPC_].certificateOwner;
    }

    /// @notice Helper function: getCertificateOwner
    function getCertificateEPC(uint96 EPC_)
    isCallerCurrentOwner(EPC_) //only owner can view the state
    isAddressValidated(msg.sender)
    isRegisteredEPC(EPC_)
    isEPCCertified(EPC_) public view returns (uint96 ret_EPC) {
        return productMap[EPC_].certificateEPC;
    }

    /// @notice  Implements the use case: setCurrentState
    /// Actors can additionally set the role: sold - to indicate that
    /// certificate information can now be retrieved by SC Manager
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
    function setProductAsCertified(uint96 EPC_, bool certified_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isCallerCurrentOwner(EPC_) public returns (bool ret) {
        productMap[EPC_].certificateOwner=getCurrentOwner(EPC_);
        productMap[EPC_].certificateEPC=EPC_;
         productMap[EPC_].hasCertificate=certified_;
         return true;
    }

    //TODO when to release memory of sold products?
    /// @notice Implements setProductAsSold
    function setProductAsSold(uint96 EPC_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isCallerCurrentOwner(EPC_) public returns (bool ret) {
         setCurrentState( EPC_,custodyState.sold);
         if(setManagerAsOwner(EPC_)) return true;
         else return false;
    }


    /*
    * MAJOR USE CASES
    */

    /// @notice Implements the use case: getProductCertificate
    function getProductCertificate(uint96 EPC_)
      isAddressValidated(msg.sender)
      isRegisteredEPC(EPC_)
      isEPCCertified(EPC_) public returns (bool ret) {
         //Can view Certificate if he is the owner of the EPC or if the product has been sold the customer by proxy to SCM
         if(isCallerAllowedToViewCertificate(msg.sender,EPC_)){
          emit RequestKYP(getCertificateOwner(EPC_), msg.sender, getCertificateEPC(EPC_));
           return true;
         }
         else return false;
    }

    /// @notice  Implements the use case: register Product
    // https://github.com/ethereum/solidity/releases/tag/v0.5.7 has fix for ABIEncoderV2
    function registerProduct(address callerAddress_, uint96 EPC_, geoPosition memory _location  )
    isAddressValidated(msg.sender)
    isSupplier
    isAddressFromCaller(callerAddress_)
    isEPCcorrect(EPC_,callerAddress_)
    notRegisteredEPC(EPC_) public returns (bool ret){
        productMap[EPC_].owner = callerAddress_;
        productMap[EPC_].custody = custodyState.inControl;
        productMap[EPC_].exists = true;
        productMap[EPC_].nextOwner = callerAddress_;
        productMap[EPC_].location = _location;
        productMap[EPC_].myEPC = EPC_;
        //next line commented to remove balance of products
        //addEPC(callerAddress_, EPC_);
        //Start the Product certificate validation: import the ID and Certificates
        emit importEPCCertificate(callerAddress_, EPC_);
        return true;
    }


    /// @notice Implements the use case:  transfer Ownership TO
    function transferTO( address addressTO_, uint96 EPC_)
    isNotManager
    isAddressValidated(msg.sender)
    isAddressValidated(addressTO_)
    isRegisteredEPC(EPC_)
    isCallerCurrentOwner(EPC_)
    isStateOwned(EPC_) public returns (bool ret){
        productMap[EPC_].custody = custodyState.inTransfer;
        productMap[EPC_].nextOwner = addressTO_;
        return true;
    }

    /// @notice Implements the use case:  transfer Ownership TO
    function receiveFROM( address addressFROM_, uint96 EPC_)
    isNotManager
    isAddressValidated(msg.sender)
    isPreviousOwner(EPC_,addressFROM_)
    isRegisteredEPC(EPC_)
    isCallerNextOwner(EPC_)
    isStateinTransfer(EPC_) public returns (bool ret){
        productMap[EPC_].owner = msg.sender;
        productMap[EPC_].custody = custodyState.inControl;
        productMap[EPC_].nextOwner = msg.sender;
        return true;
    }

    /// @notice Implements the use case:  lostProduct
    function lostProduct(uint96 EPC_)
    isNotManager
    isAddressValidated(msg.sender)
    isPreviousOwner(EPC_,msg.sender)
    isRegisteredEPC(EPC_) public returns (bool ret){
        setCurrentState( EPC_,custodyState.lost );
        productMap[EPC_].owner = msg.sender;
        productMap[EPC_].nextOwner = msg.sender;
        //next line commented to remove balance of products
        //deleteEPC(msg.sender, EPC_);
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
        //Create new product with reference to old product
        productMap[newEPC_].owner = msg.sender;
        productMap[newEPC_].custody = custodyState.inControl;
        productMap[newEPC_].exists = true;
        productMap[newEPC_].location = productMap[oldEPC_].location;
        productMap[newEPC_].myEPC = newEPC_;
        productMap[newEPC_].previousEPC=oldEPC_;
        //next 2 lines commented to remove balance of products
        //deleteEPC(msg.sender, oldEPC_); remove balance of products
        //addEPC(msg.sender, newEPC_);  remove balance of products

        return true;
    }


}
//END
