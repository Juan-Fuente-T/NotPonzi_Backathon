
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
    // Fee charged to the seller for each transaction (in basis points)
    uint256 private feeSeller;
    // Fee charged to the buyer for each transaction (in basis points)
    uint256 private feeBuyer;
    // Counter for order Ids
    uint256 public orderId;
    // Amount of fees available for withdrawal in ether
    uint256 public availableEtherFees;
    // Percentage divisor
    uint256 public percentageDivisor;
    // Max fee allowed
    uint256 public maxFeeAllowed;

    // Key: token address -> Value: amount of fees available for withdrawal in that token
    mapping(IERC20 => uint256) public availableTokenFees;
    // Key: order Id -> Value: Escrow struct
    mapping(uint256=> Escrow) public escrows;
    // Key: token address -> Value: true for whitelisted tokens or false for not whitelisted
    mapping(address => bool) public whitelistToken;

    event EscrowDeposit(uint256 indexed orderId, Escrow escrow);
    event EscrowComplete(uint256 indexed orderId, Escrow escrow);
    event TokenFeesSuccessfullyWithdrawn(address indexed token);
    event EtherFeesSuccessfullyWithdrawn(bool indexed isSent);
    event TokenAddedToWhitelist(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event BuyerFeeUpdated(uint256 indexed oldFeeBuyer,uint256 indexed newFeeBuyer);
    event SellerFeeUpdated(uint256 indexed oldFeeSeller, uint256 indexed newFeeSeller);

    error CantBeAddressZero();
    error SellerCantBeAddressZero();
    error BuyerCantBeAddressZero();
    error FeeCanBeFrom0to1Percent();
    error AddressIsNotWhitelisted();
    error ValueMustBeGreaterThan0();
    error SellerCantBeTheSameAsBuyer();
    error SellerApproveEscrowFirst();
    error BuyerApproveEscrowFirst();
    error IncorretAmount();
    error EscrowIsNotFunded();
    error NoFeesToWithdraw();

    // Modifiers

    modifier onlyBuyer(uint256 _orderId) {
        require(msg.sender == escrows[_orderId].buyer, "Only Buyer can call this");
        _;
    }

    modifier onlySeller(uint256 _orderId) {
        require(msg.sender == escrows[_orderId].seller, "Only Seller can call this");
        _;
    }

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
        address payable buyer;
        address payable seller;
        uint256 amountToSell;
        uint256 price;
        uint256 sellerFeeAmount;
        uint256 buyerFeeAmount;
        bool isEscrowEther;
        IERC20 token;
        EscrowStatus status;
    }

    constructor(address _token, uint256 _maxFeeAllowed, uint256 _percentageDivisor, uint256 _newFeeSeller, uint256 _newFeeBuyer) {
        whitelistToken[_token] = true;
        maxFeeAllowed = _maxFeeAllowed;
        percentageDivisor = _percentageDivisor;
        setFeeSeller(_newFeeSeller);
        setFeeBuyer(_newFeeBuyer);                
    }

    // ================== Begin External functions ==================          

    /**
    * @dev Creates a new escrow transaction with an ERC20 token.
    * This function allows users to initiate a new escrow transaction for an ERC20 token, specifying the amount of the transaction, the cost calculated based on the price per unit, and the currency itself.
    *
    * @param _amountToSell The total amount of the transaction, representing the sum of the item's price and the seller's fee.
    * @param _price The calculated cost of the transaction, derived from multiplying the item's price by the quantity.
    * @param _token The ERC20 token involved in the transaction.
    * 
    * Requirements:
    * - The caller must be whitelisted to perform this operation.
    * - The `_seller` cannot be the same as the buyer.
    * - The `_seller` cannot be the zero address.
    * - `_amountToSell` must be greater than 0.
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
    function createEscrowToken(uint256 _amountToSell, uint256 _price, IERC20 _token) external nonReentrant {
        _sellerValidation(_amountToSell, _price, _token);
        uint256 feeSellerPercentage = getFeeSeller();
        uint256 sellerFeeAmount = _calculateAmountFee(_amountToSell, feeSellerPercentage);        
        uint256 totalToTransfer = _amountToSell + sellerFeeAmount;
        uint256 converterWeisToEntireNumber = totalToTransfer / 10**_token.decimals();

        if (converterWeisToEntireNumber > _token.allowance(msg.sender, address(this))) {
            revert SellerApproveEscrowFirst();
        }
        
        // Transfer USDT from seller to contract
        _token.safeTransferFrom(msg.sender, address(this), (converterWeisToEntireNumber));
        orderId ++;
        escrows[orderId] = Escrow(
            payable(address(0)),
            payable(msg.sender),
            _amountToSell,
            _price,
            sellerFeeAmount,
            0,
            false,
            _token,
            EscrowStatus.Funded
        );
        emit EscrowDeposit(orderId, escrows[orderId]);
    }

    /**
    * @dev Creates a new escrow transaction with native coin.
    * This function allows a seller to deposit funds into an escrow contract, 
    * setting up a transaction with a specified value and cost. It also calculates 
    * and sets the fees for both the seller and the buyer based on predefined rates.
    *
    * @param _amountToSell The total amount of the transaction, including the seller's fee.
    * @param _price The amount of native coins (e.g., ETH) required to initiate the transaction.
    * @param _token The ERC20 token currency involved in the transaction.
        * return orderId The unique identifier assigned to this new escrow transaction.
    *
    * Requirements:
    * - `seller` cannot be the same as the buyer.
    * - `seller` cannot be the zero address.
    * - `_amountToSell` must be greater than 0.
    * - The transaction value must be sufficient to cover the transaction amount plus buyer fee.
    * - The currency passed must be whitelisted in the contract.
    *
    * Events emitted:
    * - `EscrowDeposit`: Indicates that a new escrow transaction has been successfully created.
    */
    function createEscrowETH(uint256 _amountToSell, uint256 _price, IERC20 _token) external payable nonReentrant {
        _sellerValidation(_amountToSell, _price, _token);
        uint256 feeSellerPercentage = getFeeSeller();
        uint256 sellerFeeAmount = _calculateAmountFee(_amountToSell, feeSellerPercentage);
        if (msg.value < (_amountToSell + sellerFeeAmount)) {
            revert IncorretAmount();
        }
        orderId ++;
        escrows[orderId] = Escrow(
            payable(address(0)),
            payable(msg.sender),
            _amountToSell,
            _price,
            sellerFeeAmount,
            0,
            true,
            IERC20(_token),
            EscrowStatus.Funded
        );
        emit EscrowDeposit(orderId, escrows[orderId]);
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
        if (escrow.status != EscrowStatus.Funded) {
            revert EscrowIsNotFunded();
        }
        if (escrow.seller == msg.sender) {
            revert SellerCantBeTheSameAsBuyer();
        }
        if (msg.sender == address(0)) {
            revert BuyerCantBeAddressZero();
        }
        uint256 feeBuyerPercentage = getFeeBuyer();
        uint256 buyerFeeAmount = _calculateAmountFee(escrow.amountToSell, feeBuyerPercentage);
        uint256 converterWeisToEntireNumber = escrow.price / 10**6;
        if (escrow.isEscrowEther) {            
            if (converterWeisToEntireNumber > escrow.token.allowance(msg.sender, address(this))) {
                revert BuyerApproveEscrowFirst();
            }
            availableEtherFees += buyerFeeAmount + escrow.sellerFeeAmount;
            // Transfer tokens from buyer to seller
            escrow.token.safeTransferFrom(msg.sender, escrow.seller, converterWeisToEntireNumber);
            // Transfer ETH from contract to buyer
            (bool buyerSent, ) = payable(msg.sender).call{value: (escrow.amountToSell - buyerFeeAmount)}("");
            require(buyerSent, "Transfer to buyer failed");
        } else {
            availableTokenFees[escrow.token] += buyerFeeAmount + escrow.sellerFeeAmount;
            // Transfer ETH from buyer to seller
            require(msg.value == escrow.price, "Insufficient ETH value sent");
            (bool sellerSent, ) = escrow.seller.call{value: escrow.price}("");
            require(sellerSent, "Transfer to seller failed");
            uint256 total = escrow.amountToSell - buyerFeeAmount;
            uint256 converterWeisToEntireNumber2 = total / 10**6;
            // Transfer tokens from contract to buyer
            escrow.token.safeTransfer(msg.sender, converterWeisToEntireNumber2);            
        }
        escrow.buyerFeeAmount = buyerFeeAmount;
        escrow.buyer = payable(msg.sender);
        escrow.status = EscrowStatus.Completed;
        emit EscrowComplete(_orderId, escrow);
    }

    /**
    * @dev Withdraws fees accumulated in a specific token by the contract owner.
    * @param _token The token address.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function WithdrawTokenFees(IERC20 _token) external onlyOwner {
        uint256 amount = availableTokenFees[_token];
        if (amount <= 0) {
            revert NoFeesToWithdraw();
        }
        availableTokenFees[_token] = 0;
        _token.safeTransfer(owner(), amount);
        emit TokenFeesSuccessfullyWithdrawn(address(_token));
    }

    /**
    * @dev Withdraws fees accumulated in ether by the contract owner.
    * Requirements:
    * - The caller must be the contract owner.
    */
    function WithdrawEtherFees() external onlyOwner {
        uint256 amount = availableEtherFees;
        if(amount <= 0){
            revert NoFeesToWithdraw();
        }        
        (bool sent, ) = payable(msg.sender).call{value: amount * 1 ether}("");
        require(sent, "Transfer failed.");
        availableEtherFees = 0;
        emit EtherFeesSuccessfullyWithdrawn(sent);
    }
    // ================== End External functions ===================


    /// ================== Begin Public functions ==================

    function getFeeSeller() public view returns(uint256) {
        return feeSeller;
    }

    function getFeeBuyer() public view returns(uint256) {
        return feeBuyer;
    }   
    
    /**
    * @dev Retrieves the escrow details based on the provided orderId.
    * @param _orderId The Id of the order.
    * @return Escrow The structure containing the details of the escrow.
    */    
    function getEscrow(uint256 _orderId) public view returns(Escrow memory){
        return escrows[_orderId];
    }

    /**
    * @dev Retrieves the status of an escrow based on the provided order Id.
    * @param _orderId The Id of the order.
    * @return EscrowStatus The status of the escrow.
    */
    function getStatus(uint256 _orderId) public view returns (EscrowStatus) {
        Escrow memory escrow = escrows[_orderId];
        return escrow.status;
    }

    /**
    * @dev Retrieves the value of an escrow based on the provided order Id.
    * @param _orderId The Id of the order.
    * @return uint256 The value of the escrow.
    */
    function getAmountToSell(uint256 _orderId) public view returns (uint256) {
        Escrow memory escrow = escrows[_orderId];
        return escrow.amountToSell;
    }
    /**
    * @dev Retrieves the type of an escrow based on the provided order Id. Can be ETH or token ERC20.
    * @param _orderId The Id of the order.
    * @return bool The type of the escrow. True for ETH, false for ERC20.
    */
    function isEscrowEther(uint256 _orderId) public view returns (bool) {
        Escrow memory escrow = escrows[_orderId];
        return escrow.isEscrowEther;
    }

    /**
    * @dev Add the address of the token to the whitelist.
    * @param _token The address of the token to add to the whitelist.
    * Requirements:
    * - `_token` cannot be the zero address.
    */
    function addTokenToWhitelist(address _token) public onlyOwner {
        if (_token == address(0)) {
            revert CantBeAddressZero();
        }
        whitelistToken[_token] = true;
        emit TokenAddedToWhitelist(_token);
    }

    /**
    * @dev Remove the address of the token from the whitelist.
    * @param _token The address of the token to remove from the whitelist.
    */
    function deleteTokenFromWhitelist(address _token) public onlyOwner {
        if (_token == address(0)) {
            revert CantBeAddressZero();
        }
        whitelistToken[_token] = false;
        emit TokenRemovedFromWhitelist(_token);
    }

    /**
    * @dev Sets the fee charged to the seller for each transaction.
    * @param _newFeeSeller The fee percentage (in basis points).
    * Requirements:
    * - `_feeSeller` must be between 0 and 1% (inclusive).
    */
    function setFeeSeller(uint256 _newFeeSeller) public onlyOwner {
        _feeValidation(_newFeeSeller);
        uint256 oldFeeSeller = feeSeller;
        feeSeller = _newFeeSeller;
        emit SellerFeeUpdated(oldFeeSeller, _newFeeSeller);
    }

    /**
     * @dev Sets the fee charged to the buyer for each transaction.
     * @param _newFeeBuyer The fee percentage (in basis points).
     * Requirements:
     * - `_newFeeBuyer` must be between 0 and 1% (inclusive).
     */
    function setFeeBuyer(uint256 _newFeeBuyer) public onlyOwner {
        _feeValidation(_newFeeBuyer);
        uint256 oldFeeBuyer = feeBuyer;
        feeBuyer = _newFeeBuyer;
        emit BuyerFeeUpdated(oldFeeBuyer, _newFeeBuyer);
    } 
    /// =================== End Public functions ====================   

    /// ================== Begin private functions ==================

    function _calculateAmountFee(uint256 _amount, uint256 _fee) private view returns(uint256) {
        return _amount * _fee / percentageDivisor;
    }

    function _feeValidation(uint256 _newFee) private view {
        if (_newFee < 0 || _newFee > maxFeeAllowed) {
            revert FeeCanBeFrom0to1Percent();
        }
    }

    function _sellerValidation(uint256 _amountToSell, uint256 _price, IERC20 _token) private view {
        if (!whitelistToken[address(_token)]){
            revert AddressIsNotWhitelisted();
        }
        if (msg.sender == address(0)){
            revert SellerCantBeAddressZero();
        }
        if (_amountToSell <= 0 || _price <= 0) {
            revert ValueMustBeGreaterThan0();
        }
    }

    /// =================== End Private functions ====================   
    
}