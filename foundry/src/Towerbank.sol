
// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;
import {console} from "forge-std/Test.sol";
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
        uint256 value; //Monto compra
        uint256 sellerfee; //Comision vendedor
        uint256 buyerfee; //Comision comprador
        bool escrowNative;//De Escrow, USDT o ETH
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
     * @dev Creates a new escrow transaction.
     * @param _seller The address of the seller.
     * @param _value The amount of the transaction.
     * @param _currency The currency token used for the transaction.
     * Requirements:
     * - `_seller` cannot be the same as the buyer.
     * - `_seller` cannot be the zero address.
     * - `_value` must be greater than 0.
     */
    function createEscrow(
        address payable _seller,
        uint256 _value,
        IERC20 _currency
    ) external virtual {
        if(!whitelistedStablesAddresses[address(_currency)]){
            revert AddressIsNotWhitelisted();
        }

        if(msg.sender == _seller){
            revert SellerCantBeTheSameAsBuyer();
            
        }
        if(_seller == address(0)){
            revert SellerCantBeAddressZero();

        }
        if(_value <= 0){
            revert ValueMustBeGreaterThan0();
        }
        uint8 _decimals = _currency.decimals();
        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeBuyer = ((_value * (feeBuyer * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;

        uint256 _allowance = _currency.allowance(msg.sender, address(this));
        if(_allowance < _currency.allowance(msg.sender, address(this))){
            revert SellerApproveEscrowFirst();
        }

        //Transfer USDT to contract
        _currency.safeTransferFrom(
            msg.sender,
            address(this),
            (_value + _amountFeeBuyer)
        );

        escrows[orderId] = Escrow(
            payable(msg.sender),
            _seller,
            _value,
            feeSeller,
            feeBuyer,
            false,
            _currency,
            EscrowStatus.Funded
        );

        emit EscrowDeposit(orderId, escrows[orderId]);
        orderId ++;
    }

    /**
    * @dev Creates a new escrow transaction with native coin.
    * @param _seller The address of the seller.
    * @param _value The amount of the transaction.
    * Requirements:
    * - `_seller` cannot be the same as the buyer.
    * - `_seller` cannot be the zero address.
    * - `_value` must be greater than 0.
    * - The transaction value must be sufficient to cover the transaction amount plus buyer fee.
    */
    function createEscrowNativeCoin(
        // uint256 _orderId,
        address payable _seller,
        uint256 _value
    ) external payable virtual {

        if(msg.sender == _seller){
            revert SellerCantBeTheSameAsBuyer();
            
        }
        if(_seller == address(0)){
            revert SellerCantBeAddressZero();

        }
        if(_value <= 0){
            revert ValueMustBeGreaterThan0();
        }
        
        uint8 _decimals = 6;
        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeBuyer = ((_value * (feeBuyer * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        if(msg.value < _value + _amountFeeBuyer){
            revert IncorretAmount();
        }
        // require((_value + _amountFeeBuyer) <= msg.value, "Incorrect amount");

        escrows[orderId] = Escrow(
            payable(msg.sender),
            _seller,
            _value,
            feeSeller,
            feeBuyer,
            true,
            IERC20(address(0)),
            EscrowStatus.Funded
        );

        emit EscrowDeposit(orderId, escrows[orderId]);
        orderId ++;
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