// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import {Test, console, console2} from "forge-std/Test.sol";
import { Towerbank } from "../src/Towerbank.sol";
import { USDTToken } from "../src/USDTToken.sol";
import { IERC20 } from "../src/IERC20.sol";
contract TowerbankTest is Test {
    Towerbank public myEscrow;
    USDTToken  public token;
    address alice;
    address bob;
    bool private skipNormalSetup;

    enum EscrowStatus {
        Unknown,
        Funded,
        NOT_USED,
        Completed,
        Refund,
        Arbitration
    }


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

    event EscrowDeposit(uint256 indexed orderId, Escrow escrow);
    event EscrowComplete(uint256 indexed orderId, Escrow escrow);
    event EscrowDisputeResolved(uint indexed orderId);

    // function setupSpecificTest() internal {
    // // Configurar estado específico necesario para esta prueba
    //     alice = 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6;
    //     bob = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
    //     startHoax(alice, 100000000);
    //     token = new USDTToken();
    //     myEscrow = new Towerbank(address(token));
    //     myEscrow.addStablesAddresses(address(token));
    // }
    function setUp() public {
        if (!skipNormalSetup) {
            alice = 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6;
            bob = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
            vm.startPrank(alice);
            token = new USDTToken();
            vm.stopPrank();
            myEscrow = new Towerbank(address(token));
            myEscrow.addStablesAddresses(address(token));
            startHoax(alice, 100000000);
        }
    }


        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));

////////////////////////////////////TEST ADD STABLE COIN//////////////////////////////////
    function testAddStablesAddresses() public{
        vm.stopPrank();
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        myEscrow.addStablesAddresses(address(token));
        assertTrue(myEscrow.whitelistedStablesAddresses(address(token)));
    }

    ////////////////////////////////////TEST FAIL ADD STABLE COIN//////////////////////////////////
    function testAddStablesAddressesFail() public{
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        myEscrow.addStablesAddresses(address(0));
    }

////////////////////////////////////TEST DEL STABLE COIN//////////////////////////////////
    function testDelStablesAddresses() public{
        vm.stopPrank();
        myEscrow.addStablesAddresses(address(token));
        assertTrue(myEscrow.whitelistedStablesAddresses(address(token)));
        myEscrow.delStablesAddresses(address(token));
        assertFalse(myEscrow.whitelistedStablesAddresses(address(token)));
    }
////////////////////////////////////TEST CREATE ESCROW//////////////////////////////////
    function testCreateEscrow() public {
      
        console.log("Balance USDT Alice: ",token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        
        token.approve(address(myEscrow), 50);
        // vm.expectEmit();
        // emit EscrowDeposit(0, Towerbank.myEscrow.getEscrow(0));
    //     emit EscrowDeposit(0, {
    //     alice; //Comprador
    //     bob; //Vendedor
    //     50; //Monto compra
    //     0; //Comision vendedor
    //     0; //Comision comprador
    //     false;//De Escrow, USDT o ETH
    //     IERC20(address(token)); //Moneda
    //     Towerbank.EscrowStatus.Funded; //Estado
    // });
        // emit EscrowDeposit(0, Escrow escrow);
        myEscrow.createEscrow(payable(bob), 50, IERC20(address(token)));


        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        assertEq(myEscrow.getValue(0), 50);

        Towerbank.Escrow memory escrow = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(escrow.escrowNative, false);
    }
 ////////////////////////////////////TEST FAIL CREATE ESCROW//////////////////////////////////   
    function testCreateEscrowFail() public {
        console.log("Balance USDT Alice: ",token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        
        // vm.expectEmit(0,  myEscrow.getEscrow(0));
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        myEscrow.createEscrow(payable(bob), 150, IERC20(address(token)));

        token.approve(address(myEscrow), 200);
        
        vm.expectRevert(abi.encodeWithSignature("SellerCantBeAddressZero()"));
        myEscrow.createEscrow(payable(address(0)), 150, IERC20(address(token)));
        vm.expectRevert(abi.encodeWithSignature("AddressIsNotWhitelisted()")); 
        myEscrow.createEscrow(payable(bob), 150, IERC20(address(bob)));

        vm.expectRevert(abi.encodeWithSignature("SellerCantBeTheSameAsBuyer()"));
        myEscrow.createEscrow(payable(alice), 150, IERC20(address(token)));
        
        vm.expectRevert(abi.encodeWithSignature("ValueMustBeGreaterThan0()"));
        myEscrow.createEscrow(payable(bob), 0, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);

        vm.startPrank(bob);
        token.approve(address(myEscrow), 150);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        myEscrow.createEscrow(payable(alice), 150, IERC20(address(token)));
        
    }
 ////////////////////////////////////TEST RELEASE ESCROW OWNER////////////////////////////////// 
    function testReleaseEscrowOwner() public {
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(token.balanceOf(bob), 0);
        token.approve(address(myEscrow), 100);
        myEscrow.createEscrow(payable(bob), 100, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999900);
        vm.stopPrank();

        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(token));
        assertEq(escrow.value, 100);
        assertEq(uint256(escrow.status), 1);

        myEscrow.releaseEscrowOwner(0);
        assertEq(token.balanceOf(bob), 100);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0);
    }
     ////////////////////////////////////TEST FAIL RELEASE ESCROW OWNER////////////////////////////////// 
    function testReleaseEscrowOwnerFail() public {
        token.approve(address(myEscrow), 100);
        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.releaseEscrowOwner(0);

        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        myEscrow.releaseEscrowOwner(0);
    }
 ////////////////////////////////////TEST RELEASE ESCROW////////////////////////////////// 
    function testReleaseEscrowBuyer() public {
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(token.balanceOf(bob), 0);
        token.approve(address(myEscrow), 100);
        myEscrow.createEscrow(payable(bob), 100, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999900);

        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(token));
        assertEq(escrow.value, 100);
        assertEq(uint256(escrow.status), 1);

        myEscrow.releaseEscrow(0);
        assertEq(token.balanceOf(bob), 100);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0);
    }
 ////////////////////////////////////TEST FAIL RELEASE ESCROW//////////////////////////////////     
        
    function testReleaseEscrowBuyerFail() public {
        token.approve(address(myEscrow), 100);
        myEscrow.createEscrow(payable(bob), 100, IERC20(address(token)));

        vm.stopPrank();
        
        vm.expectRevert("Only Buyer can call this");
        myEscrow.releaseEscrow(0);
        vm.startPrank(alice);
        myEscrow.releaseEscrow(0);
        vm.expectRevert("Only Buyer can call this");
        myEscrow.releaseEscrow(0); 
        vm.expectRevert("Only Buyer can call this");
        myEscrow.releaseEscrow(1);
    }
////////////////////////////////////TEST CREATE ESCROW NATIVE COIN////////////////////////////////// 
    function testCreateEscrowNativeCoin() public {
        // startHoax(bob);
        // token.approve(address(myEscrow), 100);
        // assertEq(token.allowance(alice, address(myEscrow)),100);
        // vm.startPrank(alice);
        console.log("Balance USDT Alice: ", alice.balance);
        assertEq(alice.balance, 100000000);
        
        // vm.expectEmit();
        // emit EscrowDeposit(0, myEscrow.getEscrow(0));
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 50);
        assertEq(myEscrow.getValue(0), 50);
        assertEq(alice.balance, 99999950);
        
        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        // assertEq(escrow.status, 1);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(escrow.sellerfee, 0);
        assertEq(escrow.buyerfee, 0);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 50);
        assertEq(uint256(escrow.status), 1);
    }

////////////////////////////////////TEST FAIL CREATE ESCROW NATIVE COIN//////////////////////////////////    
    function testCreateEscrowNativeCoinFail() public {
        // vm.expectEmit();
        // emit EscrowDeposit(0, myEscrow.getEscrow(0));

        assertEq(alice.balance, 100000000);

        vm.expectRevert(abi.encodeWithSignature("SellerCantBeTheSameAsBuyer()"));
        myEscrow.createEscrowNativeCoin{value:100}(payable(alice), 100);

        vm.expectRevert(abi.encodeWithSignature("IncorretAmount()"));
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 100);
        assertEq(alice.balance, 100000000);

        vm.expectRevert(abi.encodeWithSignature("ValueMustBeGreaterThan0()"));
        myEscrow.createEscrowNativeCoin{value:0}(payable(bob), 0);
        assertEq(alice.balance, 100000000);

        vm.expectRevert(abi.encodeWithSignature("SellerCantBeAddressZero()"));
        myEscrow.createEscrowNativeCoin{value:100}(payable(address(0)), 100);
        
        //Prueba. El Escrow se crea con el valor 100 pero el contrato guarda el valor 120
        myEscrow.createEscrowNativeCoin{value:120}(payable(bob), 100);
        assertEq(alice.balance, 99999880);
    }

////////////////////////////////////TEST RELEASE ESCROW NATIVE COIN OWNER////////////////////////////////// 
    function testReleaseEscrowOwnerNativeCoin() public {
        assertEq(bob.balance, 0);
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 50);
        assertEq(myEscrow.getValue(0), 50);
        assertEq(alice.balance, 99999950);
    
        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 50);
        assertEq(uint256(escrow.status), 1);

        vm.stopPrank();
        myEscrow.releaseEscrowOwnerNativeCoin(0);
        assertEq(bob.balance, 50);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0);
    }

////////////////////////////////////TEST FAIL RELEASE ESCROW NATIVE COIN OWNER////////////////////////////////// 
    function testReleaseEscrowOwnerNativeCoinFail() public {
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        // vm.expectRevert("THX has not been deposited");
        myEscrow.releaseEscrowOwnerNativeCoin(1);

        vm.startPrank(alice);
        assertEq(bob.balance, 0);
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 50);
        assertEq(myEscrow.getValue(0), 50);
        assertEq(alice.balance, 99999950);
    
        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.releaseEscrowOwnerNativeCoin(0);
        assertEq(bob.balance, 0);
    }
    
////////////////////////////////////TEST RELEASE ESCROW NATIVE COIN////////////////////////////////// 
    function testReleaseEscrowBuyerNativeCoin() public {
        assertEq(bob.balance, 0);
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 50);
        assertEq(myEscrow.getValue(0), 50);
        assertEq(alice.balance, 99999950);

        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 50);
        assertEq(uint256(escrow.status), 1);

        myEscrow.releaseEscrowNativeCoin(0);
        assertEq(bob.balance, 50);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0);
    }

////////////////////////////////////TEST FAIL RELEASE ESCROW NATIVE COIN////////////////////////////////// 
    function testReleaseEscrowBuyerNativeCoinFail() public {
        vm.expectRevert("Only Buyer can call this");
        myEscrow.releaseEscrowNativeCoin(1);

        assertEq(bob.balance, 0);
        myEscrow.createEscrowNativeCoin{value:50}(payable(bob), 50);
        assertEq(myEscrow.getValue(0), 50);
        assertEq(alice.balance, 99999950);

        vm.stopPrank();    
        vm.expectRevert("Only Buyer can call this");
        myEscrow.releaseEscrowNativeCoin(0);
        assertEq(bob.balance, 0);
    }

////////////////////////////////////TEST REFUND ESCROW////////////////////////////////// 
    function testRefundBuyer() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(token.balanceOf(bob), 0);
        token.approve(address(myEscrow), 130);
        myEscrow.createEscrow(payable(bob), 100, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999900);

        vm.stopPrank();

        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(token));
        assertEq(escrow.value, 100);
        assertEq(uint256(escrow.status), 1);

        vm.expectEmit();
        emit EscrowDisputeResolved(0);
        myEscrow.refundBuyer(0);
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(token.balanceOf(bob), 0);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0); 
    }
////////////////////////////////////TEST FAIL REFUND ESCROW////////////////////////////////// 
    function testRefundBuyerFail() public{

        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(myEscrow), 100);
        myEscrow.createEscrow(payable(bob), 100, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999900);

        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.refundBuyer(0);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        myEscrow.refundBuyer(5);
        assertEq(token.balanceOf(alice), 49999999999999999999999900);

        myEscrow.refundBuyer(0);
        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        myEscrow.refundBuyer(0);
        
    }
 
////////////////////////////////////TEST REFUND ESCROW NATIVE COIN////////////////////////////////// 
    function testRefundBuyerNativeCoin() public{
        assertEq(alice.balance, 100000000);
        myEscrow.createEscrowNativeCoin{value: 100}(payable(bob), 100);
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);
        
        vm.stopPrank();

        Towerbank.Escrow memory escrow  = myEscrow.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 100);
        assertEq(uint256(escrow.status), 1);

        vm.expectEmit();
        emit EscrowDisputeResolved(0);
        myEscrow.refundBuyerNativeCoin(0);
        assertEq(alice.balance, 100000000);
        assertEq(bob.balance, 0);

        Towerbank.Escrow memory escrow1  = myEscrow.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0); 
    }

////////////////////////////////////TEST FAIL REFUND ESCROW NATIVE COIN////////////////////////////////// 
    function testRefundBuyerNativeCoinFail() public{
        assertEq(alice.balance, 100000000);
        myEscrow.createEscrowNativeCoin{value: 100}(payable(bob), 100);
        assertEq(alice.balance, 99999900);

        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.refundBuyerNativeCoin(0);
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);

        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        myEscrow.refundBuyerNativeCoin(5);
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);
    }
////////////////////////////////////TEST WITHDRAW FEES////////////////////////////////// 
    function testWithdrawFees() public {
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
        myEscrow.setFeeSeller(500);
        vm.startPrank(alice);
        assertEq(myEscrow.feesAvailable(IERC20(address(token))), 0);
        token.approve(address(myEscrow), 3500);
        myEscrow.createEscrow(payable(bob), 700, IERC20(address(token)));
        myEscrow.releaseEscrow(0);
        myEscrow.createEscrow(payable(bob), 500, IERC20(address(token)));
        myEscrow.releaseEscrow(1);
        myEscrow.createEscrow(payable(bob), 700, IERC20(address(token)));
        myEscrow.releaseEscrow(2);
        myEscrow.createEscrow(payable(bob), 600, IERC20(address(token)));
        myEscrow.releaseEscrow(3);
        assertEq(token.balanceOf(address(this)),0);
        assertEq(myEscrow.feesAvailable(IERC20(address(token))), 11);

        vm.stopPrank();
        myEscrow.withdrawFees(IERC20(address(token)));

        assertEq(token.balanceOf(address(this)),11);
        assertEq(token.balanceOf(bob), 2500-11);
        assertEq(myEscrow.feesAvailable(IERC20(address(token))), 0);
    }
////////////////////////////////////TEST FAIL WITHDRAW FEES////////////////////////////////// 
    function testWithdrawFeesFail() public{
            assertEq(token.balanceOf(address(this)),0);
            vm.expectRevert("Ownable: caller is not the owner");
            myEscrow.withdrawFees(IERC20(address(token)));

            vm.stopPrank();
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
            myEscrow.withdrawFees(IERC20(address(token)));

            myEscrow.setFeeSeller(500);

            assertEq(myEscrow.feesAvailable(IERC20(address(token))), 0);
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
            myEscrow.withdrawFees(IERC20(address(token)));
            assertEq(myEscrow.feesAvailable(IERC20(address(token))), 0);
            assertEq(token.balanceOf(address(this)),0);
    }

////////////////////////////////////TEST WITHDRAW FEES NATIVE COIN////////////////////////////////// 
    function testWithdrawFeesNativeCoin() public { 
        vm.stopPrank();
        myEscrow.transferOwnership(alice);
        vm.startPrank(alice);
        myEscrow.setFeeBuyer(500);
        myEscrow.setFeeSeller(400);
        assertEq(myEscrow.feesAvailableNativeCoin(), 0);
        assertEq(alice.balance, 100000000);
        uint256 aliceBalance = alice.balance;
        uint256 _value= 100000;
        uint256 _value2= 200000;

        uint256 _amountFeeBuyer = ((_value * (500 * 10 ** token.decimals())) /
            (100 * 10 ** token.decimals())) / 1000;

        uint256 _amountFeeSeller = ((_value *
            (400 * 10 ** token.decimals())) /
            (100 * 10 ** token.decimals())) / 1000;

        uint256 _amountFeeBuyer2 = ((_value2 * (500 * 10 ** token.decimals())) /
            (100 * 10 ** token.decimals())) / 1000;

        uint256 _amountFeeSeller2 = ((_value2 *
            (400 * 10 ** token.decimals())) /
            (100 * 10 ** token.decimals())) / 1000;
        uint256 totalFees =  _amountFeeBuyer + _amountFeeBuyer2 + _amountFeeSeller + _amountFeeSeller2;
  
        myEscrow.createEscrowNativeCoin{value: _value + _amountFeeBuyer}(payable(bob), _value);
        myEscrow.createEscrowNativeCoin{value: _value2 + _amountFeeBuyer2}(payable(bob), _value2);

        assertEq(alice.balance, (aliceBalance - _value - _value2 - _amountFeeBuyer - _amountFeeBuyer2));
        assertEq(bob.balance, 0);

        myEscrow.releaseEscrowNativeCoin(0);
        myEscrow.releaseEscrowNativeCoin(1);

        assertEq(myEscrow.feesAvailableNativeCoin(), totalFees);

        myEscrow.withdrawFeesNativeCoin();
        assertEq(alice.balance, aliceBalance - _value - _value2 - _amountFeeBuyer - _amountFeeBuyer2 + totalFees);
        assertEq(bob.balance, _value + _value2 - _amountFeeSeller - _amountFeeSeller2);
    }

////////////////////////////////////TEST FAIL WITHDRAW FEES NATIVE COIN////////////////////////////////// 
    function testWithdrawFeesNativeCoinFail() public { 
        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.withdrawFeesNativeCoin();
        vm.stopPrank();
        myEscrow.transferOwnership(alice);
        vm.startPrank(alice);
        assertEq(myEscrow.feesAvailableNativeCoin(), 0);
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
        myEscrow.withdrawFeesNativeCoin();
        assertEq(myEscrow.feesAvailableNativeCoin(), 0);
    }


////////////////////////////////////TEST VERSION////////////////////////////////// 
    function TestVersion() public {
        string memory version = myEscrow.version();
        assertEq(version, '0.0.3');
        assertEq(myEscrow.version(), '0.0.3');
    }

////////////////////////////////////TEST GETESCROW////////////////////////////////// 
    function testGetEscrow() public{
      token.approve(address(myEscrow), 50);
        myEscrow.createEscrow(payable(bob), 50, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);

        Towerbank.Escrow memory escrowInfo  = myEscrow.getEscrow(0);
        assertEq(escrowInfo.buyer, alice);
        assertEq(escrowInfo.seller, bob);
        assertEq(escrowInfo.value, 50);
        assertEq(escrowInfo.sellerfee, 0);
        assertEq(escrowInfo.buyerfee, 0);
        assertEq(escrowInfo.escrowNative, false);
        // assertEq(myEscrow.getEscrow(0).status, false);
        // assertEq(escrowInfo.currency, IERC20(address(token)));

        // console.log(escrowInfo.buyer);
        // console.log(escrowInfo.seller);
        // console.log(escrowInfo.escrowNative);
    }
////////////////////////////////////TEST GETVALUE////////////////////////////////// 
    function testGetValue() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(myEscrow), 50);
        myEscrow.createEscrow(payable(bob), 50, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        uint256 value = myEscrow.getValue(0);
        assertEq(value, 50);
        assertEq(myEscrow.getValue(0), 50);
    }
////////////////////////////////////TEST GETSTATE////////////////////////////////// 
    function testGetState() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(myEscrow), 50);
        myEscrow.createEscrow(payable(bob), 50, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        Towerbank.EscrowStatus state = myEscrow.getState(0);
        require(state == Towerbank.EscrowStatus.Funded, "Estado del escrow no es Funded");
    }
////////////////////////////////////TEST ISESCROWNATIVE////////////////////////////////// 
    function testIsEscrowNative() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(myEscrow), 50);
        myEscrow.createEscrow(payable(bob), 50, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        bool typeEscrow = myEscrow.isEscrowNative(0);
        assertEq(typeEscrow, false);
        assertEq(myEscrow.isEscrowNative(0), false);
    }
////////////////////////////////////TEST SET FEESELLER////////////////////////////////// 
    function testSetFeeSeller() public{
        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.setFeeSeller(500);
        vm.stopPrank();
        // vm.expectRevert(abi.encodeWithSignature("FeeCanBeFrom0to1Percent"));
        assertEq(myEscrow.feeSeller(), 0);
        myEscrow.setFeeSeller(500);
        assertEq(myEscrow.feeSeller(), 500);
        // vm.expectRevert("The fee can be from 0% to 1%");
        // myEscrow.setFeeSeller(400 - 500);
    }
////////////////////////////////////TEST SET FEEBUYER////////////////////////////////// 
    function testSetFeeBuyer() public{
        vm.expectRevert("Ownable: caller is not the owner");
        myEscrow.setFeeBuyer(500);
        vm.stopPrank();
        assertEq(myEscrow.feeBuyer(), 0);
        myEscrow.setFeeBuyer(500);
        assertEq(myEscrow.feeBuyer(), 500);
        // vm.expectRevert("The fee can be from 0% to 1%");
        // myEscrow.setFeeBuyer(400 - 500);
    }
}

