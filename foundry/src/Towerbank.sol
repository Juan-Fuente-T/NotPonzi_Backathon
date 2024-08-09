
// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;
import "forge-std/console.sol";
// import {console2} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
// import "../lib/forge-std/src/Test.sol";
import './IERC20.sol';
import './Address.sol';
import './SafeERC20.sol';
import './ReentrancyGuard.sol';
import './Context.sol';
import './Ownable.sol';

/**
 * @title Towerbank
 * @dev A smart contract for managing escrow transactions between buyers and sellers.
 */
// contract Towerbank is ReentrancyGuard, Ownable, Test {
contract Towerbank is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    // 0.1 es 100 porque se multiplica por mil => 0.1 X 1000 = 100
    // Fee charged to the seller for each transaction (in basis points)
    uint256 public feeSeller;
    // Fee charged to the buyer for each transaction (in basis points)
    uint256 public feeBuyer;
    // Total fees available for withdrawal in native coin
    uint256 public feesAvailableNativeCoin;
    // Counter for order IDs
    uint256 public orderId;
    // Mapping of order ID to Escrow struct
    mapping(uint256=> Escrow) public escrows;
    // Mapping of whitelisted stablecoin addresses
    mapping(address => bool) public whitelistedStablesAddresses;
    mapping(IERC20 => uint) public feesAvailable;

    event EscrowDeposit(uint256 indexed orderId, Escrow escrow);
    event EscrowComplete(uint256 indexed orderId, Escrow escrow);
    event EscrowDisputeResolved(uint256 indexed orderId);

    error CantBeAddressZero();
    error SellerCantBeAddressZero();
    error FeeCanBeFrom0to1Percent();
    error AddressIsNotWhitelisted();
    error ValueMustBeGreaterThan0();
    error SellerCantBeTheSameAsBuyer();
    error SellerApproveEscrowFirst();
    error BuyerApproveEscrowFirst();

    error IncorretAmount();
    error EscrowIsNotFunded();
    // error EscrowHasAlreadyBeenRefund();
    error NoFeesToWithdraw();

    // Modifier to restrict access to only the buyer of an escrow
    // Buyer defined as who buys usd
    modifier onlyBuyer(uint256 _orderId) {
        require(
            msg.sender == escrows[_orderId].buyer,
            "Only Buyer can call this"
        );
        _;
    }

    // Seller defined as who sells usd
    // modifier onlySeller(uint256 _orderId) {
    //     require(
    //         msg.sender == escrows[_orderId].seller,
    //         "Only Seller can call this"
    //     );
    //     _;
    // }

    // Enum defining the status of an escrow
    enum EscrowStatus {
        Unknown,
        Funded,
        NOT_USED,
        Completed,
        Refund,
        Arbitration
    }

    // Struct representing an escrow transaction
    struct Escrow {
        address payable buyer; //Comprador
        address payable seller; //Vendedor
        uint256 value; //Valor en venta en moneda 1
        uint256 cost; //Monto compra en moneda 2
        uint256 sellerfee; //Comision vendedor
        uint256 buyerfee; //Comision comprador
        bool escrowNative;//De Escrow, USDT (false, por defecto) o ETH(true)
        IERC20 currency; //Moneda
        EscrowStatus status; //Estado
    }

    //uint256 private feesAvailable;  // summation of fees that can be withdrawn

    constructor(address currency) {
        feeSeller = 0;
        feeBuyer = 0;
        whitelistedStablesAddresses[currency] = true;
    }

    // ================== Begin External functions ==================
    
/**
* @dev Sets the fee charged to the seller for each transaction.
* @param _feeSeller The fee percentage (in basis points).
* Requirements:
* - `_feeSeller` must be between 0 and 1% (inclusive).
*/
    function setFeeSeller(uint256 _feeSeller) external onlyOwner {
        if(_feeSeller < 0 && _feeSeller > (1 * 1000)){
            revert FeeCanBeFrom0to1Percent();
        }
        feeSeller = _feeSeller;
    }

    /**
     * @dev Sets the fee charged to the buyer for each transaction.
     * @param _feeBuyer The fee percentage (in basis points).
     * Requirements:
     * - `_feeBuyer` must be between 0 and 1% (inclusive).
     */
    function setFeeBuyer(uint256 _feeBuyer) external onlyOwner {
        if(_feeBuyer < 0 && _feeBuyer > (1 * 1000)){
            revert FeeCanBeFrom0to1Percent();
        }
    
        feeBuyer = _feeBuyer;
    }

/**
* @dev Creates a new escrow transaction with an ERC20 token.
* This function allows users to initiate a new escrow transaction for an ERC20 token, specifying the amount of the transaction, the cost calculated based on the price per unit, and the currency itself.
*
* @param _value The total amount of the transaction, representing the sum of the item's price and the seller's fee.
* @param _cost The calculated cost of the transaction, derived from multiplying the item's price by the quantity.
* @param _currency The ERC20 token involved in the transaction.
* 
* Requirements:
* - The caller must be whitelisted to perform this operation.
* - The `_seller` cannot be the same as the buyer.
* - The `_seller` cannot be the zero address.
* - `_value` must be greater than 0.
* - The transaction value must be sufficient to cover the transaction amount plus the buyer's fee.
* 
* Effects:
* - Checks if the token is whitelisted and if the sender is authorized to perform the transaction.
* - Calculates the seller's fee based on the transaction value and the predefined fee rate.
* - Initializes a new escrow record with the provided details.
* - Transfers the specified amount of tokens from the buyer to the contract, including the seller's fee.
* 
* Events:
* - Emits an `EscrowDeposit` event upon successful creation of the escrow.
*/
    function createEscrowToken(
        uint256 _value,
        uint256 _cost,
        IERC20 _currency
    ) external virtual {
   ///////////////////////CHECKS///////////////////////
        if(!whitelistedStablesAddresses[address(_currency)]){
            revert AddressIsNotWhitelisted();
        }

        if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();
        }
        
        if(_value <= 0 || _cost <= 0){
            revert ValueMustBeGreaterThan0();
        }
       ///////////////////////EEFETCS/////////////////////// 

        uint8 _decimals = _currency.decimals();

        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeSeller = ((_value * (feeSeller * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;

        if(_value + _amountFeeSeller > _currency.allowance(msg.sender, address(this))){
        // if(_allowance < _currency.allowance(msg.sender, address(this))){
            revert SellerApproveEscrowFirst();
        }
       
        escrows[orderId] = Escrow(
            payable(address(0)), // Futuro comprador, buyer
            payable(msg.sender),//creador del escrow, seller
            _value,
            _cost,
            _amountFeeSeller,
            feeBuyer,
            false,
            _currency,
            EscrowStatus.Funded
    );
       ///////////////////////INTERACTIONS/////////////////////// 

        //Transferir USDT al contracto
        _currency.safeTransferFrom(
            msg.sender,
            address(this),
            (_value + _amountFeeSeller)
        );
        emit EscrowDeposit(orderId, escrows[orderId]);
        orderId ++;
    }

/**
* @dev Creates a new escrow transaction with native coin.
* This function allows a seller to deposit funds into an escrow contract, 
* setting up a transaction with a specified value and cost. It also calculates 
* and sets the fees for both the seller and the buyer based on predefined rates.
*
* @param _value The total amount of the transaction, including the seller's fee.
* @param _cost The amount of native coins (e.g., ETH) required to initiate the transaction.
* @param _currency The ERC20 token currency involved in the transaction.
    * return orderId The unique identifier assigned to this new escrow transaction.
*
* Requirements:
* - `seller` cannot be the same as the buyer.
* - `seller` cannot be the zero address.
* - `_value` must be greater than 0.
* - The transaction value must be sufficient to cover the transaction amount plus buyer fee.
* - The currency passed must be whitelisted in the contract.
*
* Events emitted:
* - `EscrowDeposit`: Indicates that a new escrow transaction has been successfully created.
*/
    function createEscrowNativeCoin(
        uint256 _value,
        uint256 _cost,
        IERC20 _currency
    ) external payable virtual {
   ///////////////////////CHECKS///////////////////////
        if(!whitelistedStablesAddresses[address(_currency)]){
            revert AddressIsNotWhitelisted();
        }

        if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();

        }
        
        if(_value <= 0 || _cost <= 0){
            revert ValueMustBeGreaterThan0();
        }
   ///////////////////////EEFETCS///////////////////////

        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeSeller = ((_value * (feeSeller * 10 ** 18)) /
            (100 * 10 ** 18)) / 1000;
        // require((_value + _amountFeeBuyer) <= msg.value, "Incorrect amount");
        if(msg.value < _value + _amountFeeSeller){
            revert IncorretAmount();
        }

        escrows[orderId] = Escrow(
            payable(address(0)), //Futuro comprador, buyer
            payable(msg.sender),//Creador del escrow, seller
            _value,
            _cost,
            _amountFeeSeller,
            feeBuyer,
            true,
            IERC20( _currency),
            EscrowStatus.Funded
        );

        emit EscrowDeposit(orderId, escrows[orderId]);
        orderId ++;
    }
/**
* @dev Accepts an escrow transaction involving ERC20 tokens.
* This function allows a buyer to finalize an escrow transaction set up with ERC20 tokens,
* transferring the agreed-upon amount of tokens from the escrow contract to the buyer.
* Additionally, it handles the payment to the seller and calculates the fees accordingly.
*
* @param _orderId The unique identifier of the escrow transaction to be accepted.
*
* Requirements:
* - The transaction must involve ERC20 tokens (`escrowNative` must be false).
* - The escrow must be previously funded.
* - The sender must not be the same as the seller associated with the escrow.
* - The transaction must send enough tokens to cover the purchase amount minus the buyer's fee.
*
* Effects:
* - Updates the status of the escrow to indicate completion.
* - Deducts the buyer's fee from the transaction amount.
* - Transfers the remaining amount to the buyer.
* - Sends the agreed-upon amount to the seller.
* - Records the transaction fees.
*
* Events emitted:
* - `EscrowComplete`: Indicates that the escrow transaction has been successfully completed.
*/
    function acceptEscrowToken(uint256 _orderId) public payable nonReentrant {
        Escrow storage escrow = escrows[_orderId];

    ///////////////////////CHECKS///////////////////////
        require(!escrow.escrowNative, "This function is for ERC20 transactions");
      
        if (escrow.status != EscrowStatus.Funded){
                revert EscrowIsNotFunded();
            }
        if (escrow.seller == msg.sender){
                revert SellerCantBeTheSameAsBuyer();
            }
        if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();

        }
        uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;
    ///////////////////////EEFETCS///////////////////////

    // Calcular y guardar las tarifas
        feesAvailable[escrow.currency] += amountFeeBuyer + escrow.sellerfee;

        // Actualizar el estado del escrow
        escrow.buyer = payable(msg.sender);
        escrow.buyerfee = amountFeeBuyer;
        escrow.status = EscrowStatus.Completed;
    ///////////////////////INTERACTIONS///////////////////////

        // require(msg.value >= escrow.cost, "Insufficient ETH value sent");
        (bool sellerSent, ) = escrow.seller.call{value: escrow.cost}("");
        require(sellerSent, "Transfer to seller failed");            

        // Transfer tokens from contract to buyer
        escrow.currency.safeTransfer(msg.sender, escrow.value - amountFeeBuyer);      

        emit EscrowComplete(_orderId, escrow);
        delete escrows[_orderId];
}
/**
 * @dev Accepts an escrow transaction involving native coins (e.g., ETH).
 * This function is called by the buyer to finalize an escrowed transaction,
 * transferring the agreed-upon amount of native coins from the escrow contract
 * to the seller, and the remaining amount to the buyer after deducting the fees.
 *
 * @param _orderId The unique identifier of the escrow transaction to be accepted.
 *
 * Requirements:
 * - The transaction must involve native coins, as indicated by `escrowNative`.
 * - The escrow must be funded, i.e., the seller must have deposited the required amount.
 * - The sender (buyer) cannot be the same as the seller.
 * - The buyer must have approved enough allowance for the contract to spend the necessary amount.
 *
 * Effects:
 * - Calculates the buyer's fee based on the transaction value and predefined rate.
 * - Updates the escrow status to indicate completion.
 * - Deducts the seller's fee and transfers the remaining amount to the seller.
 * - Transfers the buyer's fee to the contract's available fees pool.
 *
 * Interactions:
 * - Calls `safeTransferFrom` on the ERC20 token contract to transfer tokens from the buyer to the seller.
 * - Sends the remaining amount of native coins to the buyer.
 *
 * Events emitted:
 * - `EscrowComplete`: Indicates that the escrow transaction has been successfully completed.
 */
function acceptEscrowNativeCoin(uint256 _orderId) external payable nonReentrant {
    Escrow storage escrow = escrows[_orderId];

   ///////////////////////CHECKS///////////////////////
    require(escrow.escrowNative, "This function is for ETH transactions");

    if (escrow.status != EscrowStatus.Funded){
            revert EscrowIsNotFunded();
        }
    if (escrow.seller == msg.sender){
            revert SellerCantBeTheSameAsBuyer();
        }
    if (escrow.cost > escrow.currency.allowance(msg.sender, address(this))){
            revert BuyerApproveEscrowFirst();
        }
    if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();
        }
   ///////////////////////EEFFECTS///////////////////////

    // Calcular y guardar las tarifas
    uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;

    feesAvailableNativeCoin += amountFeeBuyer + escrow.sellerfee;
  

    // Actualizar el estado del escrow
    escrow.buyer = payable(msg.sender);
    escrow.buyerfee = amountFeeBuyer;
    escrow.status = EscrowStatus.Completed;

   ///////////////////////INTERACTIONS///////////////////////

    // Transferir tokens de Bob a Alice (vendedora)
    escrow.currency.safeTransferFrom(msg.sender, escrow.seller, escrow.cost);

    // Transferir ETH del contrato a Bob (comprador)
    (bool buyerSent, ) = payable(msg.sender).call{value: escrow.value - amountFeeBuyer}("");
    require(buyerSent, "Transfer to buyer failed");

    emit EscrowComplete(_orderId, escrow);
    delete escrows[_orderId];
}
/**
 * @dev Accepts an existing escrow transaction.
 * This function allows a buyer to finalize an escrowed transaction, transferring
 * either native coins (ETH) or ERC20 tokens from the escrow to the seller, and
 * then transferring the agreed-upon amount to the buyer minus any applicable fees.
 *
 * @param _orderId The unique identifier of the escrow transaction to be accepted.
 *
 * Requirements:
 * - The escrow must be funded and not yet completed.
 * - The caller must not be the seller of the escrow.
 * - The escrow must not have already been accepted.
 * - If the escrow involves ERC20 tokens, the buyer must have approved the contract
 *   to spend the necessary amount on their behalf.
 *
 * Effects:
 * - Updates the status of the escrow to Completed.
 * - Transfers the agreed-upon amount from the buyer to the seller, handling both
 *   native coins and ERC20 tokens according to the type of escrow.
 * - Deducts and transfers the buyer's fee from the escrow amount to the contract.
 * - Emits an EscrowComplete event to indicate the completion of the escrow transaction.
 *
 * Interactions:
 * - Calls `safeTransferFrom` on the ERC20 token contract if the escrow involves tokens.
 * - Performs a native coin transfer using low-level calls if the escrow involves ETH.
 *
 * Note: The buyer must approve the contract to spend the necessary amount of tokens
 * on their behalf before calling this function if the escrow involves ERC20 tokens.
 */
function acceptEscrow(uint256 _orderId) external payable nonReentrant {
    Escrow storage escrow = escrows[_orderId];

//////////////////////////////////CHECKS///////////////////////////////

        if (escrow.status != EscrowStatus.Funded){
                revert EscrowIsNotFunded();
            }
        if (escrow.seller == msg.sender){
                revert SellerCantBeTheSameAsBuyer();
            }
        if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();
        }
            
//////////////////////////////////EFFECTS///////////////////////////////
       
        uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;

        //NECESARIO  HACER UN APPROVE EN EL MOMENTO EN QUE EL BOB ACEPTE LA OFERTA EN EL FRONT
        // Transfer to buyer
        escrow.buyerfee = amountFeeBuyer;
        escrow.buyer = payable(msg.sender);
        console.log("Is escrowNative", escrow.escrowNative);

//////////////////////////////////INTERACTIONS///////////////////////////////
        if (escrow.escrowNative) {
        
            if (escrow.cost > escrow.currency.allowance(msg.sender, address(this))){
                revert BuyerApproveEscrowFirst();
            }
          
            feesAvailableNativeCoin += amountFeeBuyer + escrow.sellerfee;
            
            // Transfer tokens from buyer to seller
            escrow.currency.safeTransferFrom(msg.sender, escrow.seller, escrow.cost);

            // Transfer tokens from contract to buyer
            (bool buyerSent, ) = payable(msg.sender).call{value: escrow.value - amountFeeBuyer}("");
            require(buyerSent, "Transfer to buyer failed");
            
            // Refund excess value
            // if (msg.value > escrow.value + amountFeeBuyer) {
            //     (sent, ) = msg.sender.call{value: msg.value - (escrow.value + amountFeeBuyer)}("");
            //     require(sent, "Refund failed");
            // }
            
        } else {
            feesAvailable[escrow.currency] += amountFeeBuyer + escrow.sellerfee;
           
            // Transfer ETH from buyer to seller
            (bool sellerSent, ) = escrow.seller.call{value: escrow.cost}("");
            require(sellerSent, "Transfer to seller failed");            
            require(msg.value >= escrow.cost, "Insufficient ETH value sent");

            // Transfer tokens from contract to buyer
            escrow.currency.safeTransfer(msg.sender, escrow.value - amountFeeBuyer);        
        }
        escrow.status = EscrowStatus.Completed;
        emit EscrowComplete(_orderId, escrow);
        delete escrows[_orderId];
    }

    /**
    * @dev Releases the escrowed funds by the contract owner.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function releaseEscrowOwner(uint256 _orderId) external onlyOwner {
        _releaseEscrow(_orderId);
    }
    /**
    * @dev Releases the escrowed funds in native coin by the contract owner.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function releaseEscrowOwnerNativeCoin(uint256 _orderId) external onlyOwner {
        _releaseEscrowNativeCoin(_orderId);
    }

    /**
    * @dev Releases the escrowed funds by the buyer.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the buyer of the escrow.
    */
    function releaseEscrow(uint256 _orderId) external onlyBuyer(_orderId) {
        _releaseEscrow(_orderId);
    }

    /**
    * @dev Releases the escrowed funds in native coin by the buyer.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the buyer of the escrow.
    */
    function releaseEscrowNativeCoin(
        uint256 _orderId
    ) external onlyBuyer(_orderId) {
        _releaseEscrowNativeCoin(_orderId);
    }

    /// release funds to the buyer - cancelled contract
    /**
    * @dev Refunds the buyer in case of a cancelled contract.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function refundBuyer(uint256 _orderId) external nonReentrant onlyOwner {
        // require(escrows[_orderId].status == EscrowStatus.Refund,"Refund not approved");

        if(escrows[_orderId].status != EscrowStatus.Funded){
            revert EscrowIsNotFunded();
        }

        uint256 _value = escrows[_orderId].value;
        address _buyer = escrows[_orderId].buyer;
        IERC20 _currency = escrows[_orderId].currency;

        // dont charge seller any fees - because its a refund
        delete escrows[_orderId];

        _currency.safeTransfer(_buyer, _value);

        emit EscrowDisputeResolved(_orderId);
    }

    /**
    * @dev Refunds the buyer in native coin in case of a cancelled contract.
    * @param _orderId The ID of the escrow.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function refundBuyerNativeCoin(
        uint256 _orderId
    ) external nonReentrant onlyOwner {
        if(escrows[_orderId].status != EscrowStatus.Funded){
            revert EscrowIsNotFunded();
        }
        uint256 _value = escrows[_orderId].value;
        address _buyer = escrows[_orderId].buyer;

        // dont charge seller any fees - because its a refund
        delete escrows[_orderId];

        //Transfer call
        (bool sent, ) = payable(address(_buyer)).call{value: _value}("");
        require(sent, "Transfer failed.");

        emit EscrowDisputeResolved(_orderId);
    }

    /**
    * @dev Withdraws fees accumulated in a specific currency by the contract owner.
    * @param _currency The currency token.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function withdrawFees(IERC20 _currency) external onlyOwner {
        uint256 _amount = feesAvailable[_currency];

        if(feesAvailable[_currency] <= 0){
            revert NoFeesToWithdraw();
        }
        // This check also prevents underflow
        // require(feesAvailable[_currency] > 0, "Amount > feesAvailable");

        feesAvailable[_currency] -= _amount;

        _currency.safeTransfer(owner(), _amount);
    }

    /**
    * @dev Withdraws fees accumulated in native coin by the contract owner.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function withdrawFeesNativeCoin() external onlyOwner {
        //_amount = feesAvailable[_currency];
        uint256 _amount = feesAvailableNativeCoin;

        if(_amount <= 0){
            revert NoFeesToWithdraw();
        }
        // This check also prevents underflow
        // require(feesAvailableNativeCoin > 0, "Amount > feesAvailable");

        feesAvailableNativeCoin -= _amount;
        //Transfer
        (bool sent, ) = payable(msg.sender).call{value: _amount}("");
        require(sent, "Transfer failed.");
    }

    // ================== End External functions ==================

    // ================== Begin External functions that are pure ==================

    /**
    * @dev Returns the version of the contract.
    */
    function version() external pure virtual returns (string memory) {
        return "0.0.3";
    }

    // ================== End External functions that are pure ==================

    /// ================== Begin Public functions ==================
    
    /**
    * @dev Retrieves the escrow details based on the provided escrow ID.
    * @param escrowId The ID of the escrow.
    * @return Escrow The details of the escrow.
    */
    function getEscrow(uint256 escrowId) public view returns(Escrow memory){
        return escrows[escrowId];
    }
    /**
    * @dev Retrieves the status of an escrow based on the provided order ID.
    * @param _orderId The ID of the order.
    * @return EscrowStatus The status of the escrow.
    */
    function getState(uint256 _orderId) public view returns (EscrowStatus) {
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.status;
    }

    /**
    * @dev Retrieves the value of an escrow based on the provided order ID.
    * @param _orderId The ID of the order.
    * @return uint256 The value of the escrow.
    */
    function getValue(uint256 _orderId) public view returns (uint256) {
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.value;
    }
    /**
    * @dev Retrieves the type of an escrow based on the provided order ID. Can be native, ETH or with token
    * @param _orderId The ID of the order.
    * @return bool The type of the escrow. True for native.
    */
    function isEscrowNative(uint256 _orderId) public view returns (bool) {
        Escrow memory _escrow = escrows[_orderId];
        return _escrow.escrowNative;
    }

    /**
    * @dev Adds the address of a stablecoin to the whitelist.
    * @param _addressStableToWhitelist The address of the stablecoin to whitelist.
    * Requirements:
    * - `_addressStableToWhitelist` cannot be the zero address.
    */
    function addStablesAddresses(
        address _addressStableToWhitelist
    ) public onlyOwner {
        if(_addressStableToWhitelist == address(0)){
            revert CantBeAddressZero();
        }
        whitelistedStablesAddresses[_addressStableToWhitelist] = true;
    }

    /**
    * @dev Removes the address of a stablecoin from the whitelist.
    * @param _addressStableToWhitelist The address of the stablecoin to remove from the whitelist.
    */
    function delStablesAddresses(
        address _addressStableToWhitelist
    ) public onlyOwner {
        whitelistedStablesAddresses[_addressStableToWhitelist] = false;
    }

    /// ================== End Public functions ==================

    // ================== Begin Private functions ==================
    /**
    * @dev Releases the escrowed funds to the seller.
    * @param _orderId The ID of the order.
    * Requirements:
    * - The status of the escrow must be 'Funded'.
    * - The transfer of funds must be successful.
    */
    function _releaseEscrow(uint256 _orderId) private nonReentrant {
        // require(
        //     escrows[_orderId].status == EscrowStatus.Funded,
        //     "USDT has not been deposited"
        // );
        if( escrows[_orderId].status != EscrowStatus.Funded){
            revert EscrowIsNotFunded();
        }

        uint8 _decimals = escrows[_orderId].currency.decimals();

        //Obtiene el monto a transferir desde el comprador al contrato //sellerfee //buyerfee
        uint256 _amountFeeBuyer = ((escrows[_orderId].value *
            (escrows[_orderId].buyerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        uint256 _amountFeeSeller = ((escrows[_orderId].value *
            (escrows[_orderId].sellerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;

        //feesAvailable += _amountFeeBuyer + _amountFeeSeller;
        feesAvailable[escrows[_orderId].currency] +=
            _amountFeeBuyer +
            _amountFeeSeller;

        // write as complete, in case transfer fails
        escrows[_orderId].status = EscrowStatus.Completed;

        //Transfer to sellet Price Asset - FeeSeller
        escrows[_orderId].currency.safeTransfer(
            escrows[_orderId].seller,
            escrows[_orderId].value - _amountFeeSeller
        );

        emit EscrowComplete(_orderId, escrows[_orderId]);
        delete escrows[_orderId];
    }

    /**
    * @dev Releases the escrowed native coin funds to the seller.
    * @param _orderId The ID of the order.
    * Requirements:
    * - The status of the escrow must be 'Funded'.
    * - The transfer of funds must be successful.
    */
    function _releaseEscrowNativeCoin(uint256 _orderId) private nonReentrant {
        // require(
        //     escrows[_orderId].status == EscrowStatus.Funded,
        //     "THX has not been deposited"
        // );

        if( escrows[_orderId].status != EscrowStatus.Funded){
            revert EscrowIsNotFunded();
        }


        uint8 _decimals = 6; //Wei

        //Obtiene el monto a transferir desde el comprador al contrato //sellerfee //buyerfee
        uint256 _amountFeeBuyer = ((escrows[_orderId].value *
            (escrows[_orderId].buyerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        uint256 _amountFeeSeller = ((escrows[_orderId].value *
            (escrows[_orderId].sellerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;

        //Registra los fees obtenidos para Towerbank
        feesAvailableNativeCoin += _amountFeeBuyer + _amountFeeSeller;

        // write as complete, in case transfer fails
        escrows[_orderId].status = EscrowStatus.Completed;

        //Transfer to sellet Price Asset - FeeSeller
        (bool sent, ) = escrows[_orderId].seller.call{
            value: escrows[_orderId].value - _amountFeeSeller
        }("");
        require(sent, "Transfer failed.");

        emit EscrowComplete(_orderId, escrows[_orderId]);
        delete escrows[_orderId];
    }
    // ================== End Private functions ==================
}