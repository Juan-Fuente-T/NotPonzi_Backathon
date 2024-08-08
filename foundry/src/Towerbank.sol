
// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;
import "forge-std/console.sol";
import {console2} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
import "../lib/forge-std/src/Test.sol";
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
     * @dev Creates a new escrow transaction.
     * @param _value The amount of the transaction.
     * @param _currency The currency token used for the transaction.
     * Requirements:
     * - `_value` must be greater than 0.
     */
    function createEscrow(
        // address payable _seller,
        uint256 _value,
        uint256 _cost,
        IERC20 _currency
    ) external virtual {
        if(!whitelistedStablesAddresses[address(_currency)]){
            revert AddressIsNotWhitelisted();
        }

        // if(msg.sender == _seller){
        //     revert SellerCantBeTheSameAsBuyer();
            
        // }
        if(msg.sender == address(0)){
            revert SellerCantBeAddressZero();
        }
        
        if(_value <= 0 || _cost <= 0){
            revert ValueMustBeGreaterThan0();
        }
        uint8 _decimals = _currency.decimals();
        //Obtiene el monto a transferir desde el comprador al contrato
        uint256 _amountFeeSeller = ((_value * (feeSeller * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        if(_value + _amountFeeSeller > _currency.allowance(msg.sender, address(this))){
        // if(_allowance < _currency.allowance(msg.sender, address(this))){
            revert SellerApproveEscrowFirst();
        }
        //ESTA LINEA SOBRA!!
        // uint256 _allowance = _currency.allowance(msg.sender, address(this));


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

        //Transfer USDT to contract
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
    * param _seller The address of the seller.
    * @param _value The amount of the transaction.
    * Requirements:
    // * - `_seller` cannot be the same as the buyer.
    // * - `_seller` cannot be the zero address.
    * - `_value` must be greater than 0.
    * - The transaction value must be sufficient to cover the transaction amount plus buyer fee.
    */
    function createEscrowNativeCoin(
        // uint256 _orderId,
        // address payable _seller,
        uint256 _value,
        uint256 _cost
    ) external payable virtual {

        // if(msg.sender == _seller){
        //     revert SellerCantBeTheSameAsBuyer();
            
        // }
        // if(_seller == address(0)){
        //     revert SellerCantBeAddressZero();

        // }
        
        if(_value <= 0){
            revert ValueMustBeGreaterThan0();
        }

        // uint8 _decimals = 18;
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
            IERC20(address(0)),
            EscrowStatus.Funded
        );
        // (bool sent, ) = address(this).call{value: _value + _amountFeeSeller}("");
        // require(sent, "Transfer from seller failed"); 

        emit EscrowDeposit(orderId, escrows[orderId]);
        orderId ++;
    }

    function acceptEscrow(uint256 _orderId) external payable nonReentrant {
        Escrow storage escrow = escrows[_orderId];

//////////////////////////////////CHECKS///////////////////////////////

        require(escrow.status == EscrowStatus.Funded, "Escrow is not funded");
        require(escrow.seller != msg.sender, "Seller and buyer can't be the same");
        // require(escrow.buyer == address(0), "Escrow already accepted");
        // require(escrow.escrowNative, "Escrow is for native coin");

//////////////////////////////////EFFETS///////////////////////////////
        // uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;
        // uint256 amountFeeSeller = (escrow.value * feeSeller) / 10000;
        // uint256 amountFeeSeller = (escrow.value * escrow.sellerfee) / 10000;
        uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;

        // escrow.buyer = payable(msg.sender);
        //NECESARIO  HACER UN APPROVE EN EL MOMENTO EN QUE EL BOB ACEPTE LA OFERTA EN EL FRONT
        // Transfer to buyer
        escrow.buyerfee = amountFeeBuyer;
        escrow.buyer = payable(msg.sender);
        console.log("Is escrowNative", escrow.escrowNative);

        if (escrow.escrowNative) {
//////////////////////////////////INTERACTIONS///////////////////////////////
             console.log("Allowance",  escrow.currency.allowance(msg.sender, address(this)));
             console.log("escrow.cost", escrow.cost);
            if (escrow.cost > escrow.currency.allowance(msg.sender, address(this))){
                revert BuyerApproveEscrowFirst();
            }
             console.log("Datos", msg.sender, escrow.seller, escrow.cost);
            // Transfer tokens from buyer to seller
            //  escrow.currency.safeTransferFrom(msg.sender, address(this), escrow.value + amountFeeBuyer);
            // (bool sent, ) = escrow.seller.call{value: escrow.value - amountFeeSeller}("");
            // require(sent, "Transfer to seller failed");
            //  escrow.currency.safeTransfer(msg.sender, escrow.value - amountFeeBuyer);
            // Transfer ETH from contract to buyer

            // feesAvailableNativeCoin += amountFeeBuyer + escrow.sellerfee;
            //  console.log("Datos tansferFrom", msg.sender, escrow.seller, escrow.cost);
            //  escrow.currency.safeTransferFrom(msg.sender, escrow.seller, escrow.cost);

            // (bool buyerSent, ) = escrow.buyer.call{value: escrow.value - amountFeeBuyer}("");
            // require(buyerSent, "Transfer to buyer failed");
            
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
        // console.log("ESCROW", escrow.seller, escrow.buyer, escrow.buyerfee, escrow.sellerfee, escrow.buyerfee, escrow.value, escrow.cost, escrow.status, escrow.escrowNative);
        emit EscrowComplete(_orderId, escrow);
        delete escrows[_orderId];
        // console.log("ESCROW DES", escrow.seller, escrow.buyer, escrow.buyerfee, escrow.sellerfee, escrow.buyerfee, escrow.value, escrow.cost, escrow.status, escrow.escrowNative);
    }
//     function acceptEscrowNativeCoin(uint256 _orderId) external payable nonReentrant {
//         Escrow storage escrow = escrows[_orderId];
//         require(escrow.status == EscrowStatus.Funded, "Escrow is not funded");
//         // require(escrow.buyer == address(0), "Escrow already accepted");
//         require(escrow.status == Funded, "Escrow already accepted");

//         // uint256 amountFeeBuyer = (escrow.value * feeBuyer) / 10000;
//         uint256 amountFeeBuyer = (escrow.value * escrow.buyerfee) / 10000;
//         // uint256 amountFeeSeller = (escrow.value * feeSeller) / 10000;
//         uint256 amountFeeSeller = (escrow.value * escrow.sellerfee) / 10000;

//         escrow.buyer = payable(msg.sender);
// _currency.allowance(msg.sender, address(this))
//         if (escrow.status == 'funded') {
//             if (escrow.value + amountFeeBuyer > escrow.currency.allowance(msg.sender, address(this))){
//                 revert BuyerApproveEscrowFirst();
//             };
//             feesAvailableNativeCoin += amountFeeBuyer + amountFeeSeller;

//             // Transfer to seller
//             (bool sent, ) = escrow.seller.call{value: escrow.value - amountFeeSeller}("");
//             require(sent, "Transfer to seller failed");

//             // Refund excess value
//             if (msg.value > escrow.value + amountFeeBuyer) {
//                 (sent, ) = msg.sender.call{value: msg.value - (escrow.value + amountFeeBuyer)}("");
//                 require(sent, "Refund failed");
//             }
//         } else {
//             escrow.currency.transferFrom(msg.sender, address(this), escrow.value + amountFeeBuyer);
//             feesAvailable[escrow.currency] += amountFeeBuyer + amountFeeSeller;

//             // Transfer to seller
//             escrow.currency.transfer(escrow.seller, escrow.value - amountFeeSeller);
//         }

//         escrow.status = EscrowStatus.Completed;

//         emit EscrowComplete(_orderId, escrow);
//     }

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