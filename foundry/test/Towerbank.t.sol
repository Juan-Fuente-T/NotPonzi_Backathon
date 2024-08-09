// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import {Test, console, console2} from "forge-std/Test.sol";
import { Towerbank } from "../src/Towerbank.sol";
import { USDTToken } from "../src/USDTToken.sol";
import { IERC20 } from "../src/IERC20.sol";
contract TowerbankTest is Test {
    Towerbank public towerbank;
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
        uint256 value; //Valor en venta en moneda 1
        uint256 cost; //Monto compra en moneda 2
        uint256 sellerfee; //Comision vendedor
        uint256 buyerfee; //Comision comprador
        bool escrowNative;//De Escrow, USDT (false, por defecto) o ETH(true)
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
    //     towerbank = new Towerbank(address(token));
    //     towerbank.addStablesAddresses(address(token));
    // }
    function setUp() public {
        if (!skipNormalSetup) {
            alice = 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6;
            bob = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
            vm.startPrank(alice);
            token = new USDTToken();
            vm.stopPrank();
            towerbank = new Towerbank(address(token));
            towerbank.addStablesAddresses(address(token));
            startHoax(alice, 100000000);
            console.log(address(token));
        }
    }


        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));

////////////////////////////////////TEST ADD STABLE COIN//////////////////////////////////
    function testAddStablesAddresses() public{
        vm.stopPrank();
        // vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        towerbank.addStablesAddresses(address(token));
        assertTrue(towerbank.whitelistedStablesAddresses(address(token)));
    }

    ////////////////////////////////////TEST FAIL ADD STABLE COIN//////////////////////////////////
    function testAddStablesAddressesFail() public{
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CantBeAddressZero()"));
        towerbank.addStablesAddresses(address(0));
    }

////////////////////////////////////TEST DEL STABLE COIN//////////////////////////////////
    function testDelStablesAddresses() public{
        vm.stopPrank();
        towerbank.addStablesAddresses(address(token));
        assertTrue(towerbank.whitelistedStablesAddresses(address(token)));
        towerbank.delStablesAddresses(address(token));
        assertFalse(towerbank.whitelistedStablesAddresses(address(token)));
    }
////////////////////////////////////TEST CREATE ESCROW//////////////////////////////////
    function testCreateEscrowToken() public {
      
        console.log("Balance USDT Alice: ",token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(alice.balance, 100000000);
        
        token.approve(address(towerbank), 50);
        // vm.expectEmit();
        // emit EscrowDeposit(0, Towerbank.towerbank.getEscrow(0));
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
        towerbank.createEscrowToken(50, 100, IERC20(address(token)));


        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        assertEq(towerbank.getValue(0), 50);

        Towerbank.Escrow memory escrow = towerbank.getEscrow(0);
        assertEq(escrow.seller, alice);
        assertEq(escrow.value, 50);
        assertEq(escrow.cost, 100);
        assertEq(escrow.escrowNative, false);
    }
 ////////////////////////////////////TEST FAIL CREATE ESCROW//////////////////////////////////   
    function testCreateEscrowTokenFail() public {
        console.log("Balance USDT Alice: ",token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        
        // vm.expectEmit(0,  towerbank.getEscrow(0));
        vm.expectRevert(abi.encodeWithSignature("SellerApproveEscrowFirst()"));
        // vm.expectRevert("ERC20: transfer amount exceeds allowance");
        towerbank.createEscrowToken( 150, 300, IERC20(address(token)));

        token.approve(address(towerbank), 200);
        
        // vm.expectRevert(abi.encodeWithSignature("SellerCantBeAddressZero()"));
        // towerbank.createEscrowToken(150, 300, IERC20(address(token)));
        vm.expectRevert(abi.encodeWithSignature("AddressIsNotWhitelisted()")); 
        towerbank.createEscrowToken(150, 300, IERC20(address(bob)));

        // vm.expectRevert(abi.encodeWithSignature("SellerCantBeTheSameAsBuyer()"));
        // towerbank.createEscrowToken(150, 300, IERC20(address(token)));
        
        vm.expectRevert(abi.encodeWithSignature("ValueMustBeGreaterThan0()"));
        towerbank.createEscrowToken(0, 300, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        
        vm.expectRevert(abi.encodeWithSignature("ValueMustBeGreaterThan0()"));
        towerbank.createEscrowToken(150, 0, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 50000000000000000000000000);

        vm.startPrank(bob);
        token.approve(address(towerbank), 150);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        towerbank.createEscrowToken(150, 300, IERC20(address(token)));
        
    }
 ////////////////////////////////////TEST ACCEPT ESCROW USDT////////////////////////////////// 
    function testAcceptEscrowToken() public {
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        // token.transfer(bob, 300);
        // assertEq(token.balanceOf(alice), 49999999999999999999999700);
        // assertEq(token.balanceOf(bob), 100);
        assertEq(alice.balance, 100000000);
        assertEq(token.balanceOf(bob), 0);
        token.approve(address(towerbank), 100);
        towerbank.createEscrowToken(100, 20, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999900);
        vm.stopPrank();

        Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
        assertEq(escrow.seller, alice);
        // assertEq(escrow.buyer, bob);
        assertEq(address(escrow.currency), address(token));
        assertEq(escrow.value, 100);
        assertEq(escrow.cost, 20);
        assertEq(uint256(escrow.status), 1);

        startHoax(bob, 1000);
        assertEq(bob.balance, 1000);
        // token.approve(address(towerbank), 300);
        // towerbank.acceptEscrow(0);
    // vm.expectEmit(true, true, true, true);
    // emit EscrowComplete(
    //     0, 
    //     Escrow({
    //         seller: escrow.seller,
    //         buyer: escrow.buyer,
    //         value: escrow.value,
    //         cost: escrow.cost,
    //         sellerfee: escrow.sellerfee,
    //         buyerfee: escrow.buyerfee,
    //         escrowNative: escrow.escrowNative,
    //         currency: escrow.currency,
    //         EscrowStatus status
    //     })
    // );

   
        // towerbank.acceptEscrowToken{value: escrow.cost}(0);
        towerbank.acceptEscrow{value: escrow.cost}(0);
        assertEq(token.balanceOf(bob), 100);
        assertEq(bob.balance, 980);
        assertEq(alice.balance, 100000020);

        Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(escrow1.cost, 0);
        assertEq(uint256(escrow1.status), 0);
    }
 ////////////////////////////////////TEST ACCEPT ESCROW ETH////////////////////////////////// 
    function testAcceptEscrowNativeCoin() public {
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        assertEq(token.balanceOf(bob), 0);
        token.transfer(bob, 300);
        assertEq(token.balanceOf(alice), 49999999999999999999999700);
        assertEq(token.balanceOf(bob), 300);
        assertEq(alice.balance, 100000000);
        towerbank.createEscrowNativeCoin{value: 100}(100, 200, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999700);
        assertEq(alice.balance, 99999900);
        vm.stopPrank();

        Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
        assertEq(escrow.seller, alice);
        // assertEq(escrow.buyer, bob);
        assertEq(address(escrow.currency), address(token));
        assertEq(escrow.value, 100);
        assertEq(escrow.cost, 200);
        assertEq(uint256(escrow.status), 1);

        startHoax(bob, 1000);
        assertEq(bob.balance, 1000);
        // token.approve(address(towerbank), 300);
        // towerbank.acceptEscrow(0);
    // vm.expectEmit(true, true, true, true);
    // emit EscrowComplete(
    //     0, 
    //     Escrow({
    //         seller: escrow.seller,
    //         buyer: escrow.buyer,
    //         value: escrow.value,
    //         cost: escrow.cost,
    //         sellerfee: escrow.sellerfee,
    //         buyerfee: escrow.buyerfee,
    //         escrowNative: escrow.escrowNative,
    //         currency: escrow.currency,
    //         EscrowStatus status
    //     })
    // );
        console.log("Es eth?:", escrow.escrowNative);
        token.approve(address(towerbank), 2000);
        // towerbank.acceptEscrow(0);
        // towerbank.acceptEscrowNativeCoin(0);
        towerbank.acceptEscrow(0);
        assertEq(bob.balance, 1100);
        assertEq(alice.balance, 99999900);
        assertEq(token.balanceOf(alice), 49999999999999999999999900);
        assertEq(token.balanceOf(bob), 100);

        Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(escrow1.cost, 0);
        assertEq(uint256(escrow1.status), 0);
    }
//  ////////////////////////////////////TEST RELEASE ESCROW OWNER////////////////////////////////// 
//     function testReleaseEscrowOwner() public {
//         assertEq(token.balanceOf(alice), 50000000000000000000000000);
//         assertEq(token.balanceOf(bob), 0);
//         token.approve(address(towerbank), 100);
//         towerbank.createEscrow(100, 300, IERC20(address(token)));
//         assertEq(token.balanceOf(alice), 49999999999999999999999900);
//         vm.stopPrank();

//         Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
//         assertEq(escrow.buyer, alice);
//         assertEq(escrow.seller, bob);
//         assertEq(address(escrow.currency), address(token));
//         assertEq(escrow.value, 100);
//         assertEq(uint256(escrow.status), 1);

//         towerbank.releaseEscrowOwner(0);
//         assertEq(token.balanceOf(bob), 100);

//         Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
//         assertEq(escrow1.buyer, address(0));
//         assertEq(escrow1.seller, address(0));
//         assertEq(address(escrow1.currency), address(0));
//         assertEq(escrow1.value, 0);
//         assertEq(uint256(escrow1.status), 0);
//     }
     ////////////////////////////////////TEST FAIL RELEASE ESCROW OWNER////////////////////////////////// 
    function testReleaseEscrowOwnerFail() public {
        token.approve(address(towerbank), 100);
        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.releaseEscrowOwner(0);

        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        towerbank.releaseEscrowOwner(0);
    }
 ////////////////////////////////////TEST RELEASE ESCROW////////////////////////////////// 
    // function testReleaseEscrowBuyer() public {
    //     assertEq(token.balanceOf(alice), 50000000000000000000000000);
    //     assertEq(token.balanceOf(bob), 0);
    //     token.approve(address(towerbank), 100);
    //     towerbank.createEscrow(100, 300, IERC20(address(token)));
    //     assertEq(token.balanceOf(alice), 49999999999999999999999900);

    //     Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
    //     assertEq(escrow.buyer, alice);
    //     assertEq(escrow.seller, bob);
    //     assertEq(address(escrow.currency), address(token));
    //     assertEq(escrow.value, 100);
    //     assertEq(uint256(escrow.status), 1);

    //     towerbank.releaseEscrow(0);
    //     assertEq(token.balanceOf(bob), 100);

    //     Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
    //     assertEq(escrow1.buyer, address(0));
    //     assertEq(escrow1.seller, address(0));
    //     assertEq(address(escrow1.currency), address(0));
    //     assertEq(escrow1.value, 0);
    //     assertEq(uint256(escrow1.status), 0);
    // }
 ////////////////////////////////////TEST FAIL RELEASE ESCROW//////////////////////////////////     
        
    // function testReleaseEscrowBuyerFail() public {
    //     token.approve(address(towerbank), 100);
    //     towerbank.createEscrow(100, 300, IERC20(address(token)));

    //     vm.stopPrank();
        
    //     vm.expectRevert("Only Buyer can call this");
    //     towerbank.releaseEscrow(0);
    //     vm.startPrank(alice);
    //     towerbank.releaseEscrow(0);
    //     vm.expectRevert("Only Buyer can call this");
    //     towerbank.releaseEscrow(0); 
    //     vm.expectRevert("Only Buyer can call this");
    //     towerbank.releaseEscrow(1);
    // }
////////////////////////////////////TEST CREATE ESCROW NATIVE COIN////////////////////////////////// 
    // function testCreateEscrowNativeCoin() public {
    //     // startHoax(bob);
    //     // token.approve(address(towerbank), 100);
    //     // assertEq(token.allowance(alice, address(towerbank)),100);
    //     // vm.startPrank(alice);
    //     console.log("Balance USDT Alice: ", alice.balance);
    //     assertEq(alice.balance, 100000000);
        
    //     // vm.expectEmit();
    //     // emit EscrowDeposit(0, towerbank.getEscrow(0));
    //     towerbank.createEscrowNativeCoin{value:50}(50, 300, address(token));
    //     assertEq(towerbank.getValue(0), 50);
    //     assertEq(alice.balance, 99999950);
        
    //     Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
    //     // assertEq(escrow.status, 1);
    //     assertEq(escrow.seller, alice);
    //     assertEq(escrow.buyer, address(0));
    //     assertEq(escrow.sellerfee, 0);//Si la fee cambia no debe ser 0
    //     assertEq(escrow.buyerfee, 0);
    //     assertEq(address(escrow.currency), address(0));
    //     assertEq(escrow.value, 50);
    //     assertEq(escrow.cost, 300);
    //     assertEq(uint256(escrow.status), 1);
    // }

////////////////////////////////////TEST FAIL CREATE ESCROW NATIVE COIN//////////////////////////////////    
    // function testCreateEscrowNativeCoinFail() public {
    //     // vm.expectEmit();
    //     // emit EscrowDeposit(0, towerbank.getEscrow(0));

    //     assertEq(alice.balance, 100000000);

    //     vm.expectRevert(abi.encodeWithSignature("IncorretAmount()"));
    //     towerbank.createEscrowNativeCoin{value:50}(100, 300, address(token));
    //     assertEq(alice.balance, 100000000);

    //     vm.expectRevert(abi.encodeWithSignature("ValueMustBeGreaterThan0()"));
    //     towerbank.createEscrowNativeCoin{value:0}(0, 300, address(token));
    //     assertEq(alice.balance, 100000000);

    //     // vm.expectRevert(abi.encodeWithSignature("SellerCantBeAddressZero()"));
    //     // towerbank.createEscrowNativeCoin{value:100}(100, 300, address(token));
        
    //     //Prueba. El Escrow se crea con el valor 100 pero el contrato guarda el valor 120
    //     towerbank.createEscrowNativeCoin{value:120}(100, 300, address(token));
    //     assertEq(alice.balance, 99999880);
    // }

////////////////////////////////////TEST RELEASE ESCROW NATIVE COIN OWNER////////////////////////////////// 
    function testReleaseEscrowOwnerNativeCoin() public {
        assertEq(bob.balance, 0);
        towerbank.createEscrowNativeCoin{value:50}(50, 300, IERC20(address(token)));
        assertEq(alice.balance, 99999950);
    
        Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 50);
        assertEq(uint256(escrow.status), 1);

        vm.stopPrank();
        towerbank.releaseEscrowOwnerNativeCoin(0);
        assertEq(bob.balance, 50);

        Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
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
        towerbank.releaseEscrowOwnerNativeCoin(1);

        vm.startPrank(alice);
        assertEq(bob.balance, 0);
        towerbank.createEscrowNativeCoin{value:50}(50, 300, IERC20(address(token)));
        assertEq(towerbank.getValue(0), 50);
        assertEq(alice.balance, 99999950);
    
        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.releaseEscrowOwnerNativeCoin(0);
        assertEq(bob.balance, 0);
    }
    
////////////////////////////////////TEST RELEASE ESCROW NATIVE COIN////////////////////////////////// 
    function testReleaseEscrowBuyerNativeCoin() public {
        assertEq(bob.balance, 0);
        towerbank.createEscrowNativeCoin{value:50}(50,300, IERC20(address(token)));
        assertEq(towerbank.getValue(0), 50);
        assertEq(alice.balance, 99999950);

        Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 50);
        assertEq(uint256(escrow.status), 1);

        towerbank.releaseEscrowNativeCoin(0);
        assertEq(bob.balance, 50);

        Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0);
    }

////////////////////////////////////TEST FAIL RELEASE ESCROW NATIVE COIN////////////////////////////////// 
    function testReleaseEscrowBuyerNativeCoinFail() public {
        vm.expectRevert("Only Buyer can call this");
        towerbank.releaseEscrowNativeCoin(1);

        assertEq(bob.balance, 0);
        towerbank.createEscrowNativeCoin{value:50}(50, 300, IERC20(address(token)));
        assertEq(towerbank.getValue(0), 50);
        assertEq(alice.balance, 99999950);

        vm.stopPrank();    
        vm.expectRevert("Only Buyer can call this");
        towerbank.releaseEscrowNativeCoin(0);
        assertEq(bob.balance, 0);
    }

////////////////////////////////////TEST REFUND ESCROW////////////////////////////////// 
    // function testRefundBuyer() public{
    //     assertEq(token.balanceOf(alice), 50000000000000000000000000);
    //     assertEq(token.balanceOf(bob), 0);
    //     token.approve(address(towerbank), 130);
    //     towerbank.createEscrow(100, 300, IERC20(address(token)));
    //     assertEq(token.balanceOf(alice), 49999999999999999999999900);

    //     vm.stopPrank();

    //     Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
    //     assertEq(escrow.buyer, alice);
    //     assertEq(escrow.seller, bob);
    //     assertEq(address(escrow.currency), address(token));
    //     assertEq(escrow.value, 100);
    //     assertEq(uint256(escrow.status), 1);

    //     vm.expectEmit();
    //     emit EscrowDisputeResolved(0);
    //     towerbank.refundBuyer(0);
    //     assertEq(token.balanceOf(alice), 50000000000000000000000000);
    //     assertEq(token.balanceOf(bob), 0);

    //     Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
    //     assertEq(escrow1.buyer, address(0));
    //     assertEq(escrow1.seller, address(0));
    //     assertEq(address(escrow1.currency), address(0));
    //     assertEq(escrow1.value, 0);
    //     assertEq(uint256(escrow1.status), 0); 
    // }
////////////////////////////////////TEST FAIL REFUND ESCROW////////////////////////////////// 
    // function testRefundBuyerFail() public{

    //     assertEq(token.balanceOf(alice), 50000000000000000000000000);
    //     token.approve(address(towerbank), 100);
    //     towerbank.createEscrow(100, 300, IERC20(address(token)));
    //     assertEq(token.balanceOf(alice), 49999999999999999999999900);

    //     vm.expectRevert("Ownable: caller is not the owner");
    //     towerbank.refundBuyer(0);
    //     vm.stopPrank();

    //     vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
    //     towerbank.refundBuyer(5);
    //     assertEq(token.balanceOf(alice), 49999999999999999999999900);

    //     towerbank.refundBuyer(0);
    //     vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
    //     towerbank.refundBuyer(0);
        
    // }
 
////////////////////////////////////TEST REFUND ESCROW NATIVE COIN////////////////////////////////// 
    function testRefundBuyerNativeCoin() public{
        assertEq(alice.balance, 100000000);
        towerbank.createEscrowNativeCoin{value: 100}(100, 300, IERC20(address(token)));
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);
        
        vm.stopPrank();

        Towerbank.Escrow memory escrow  = towerbank.getEscrow(0);
        assertEq(escrow.buyer, alice);
        assertEq(escrow.seller, bob);
        assertEq(address(escrow.currency), address(0));
        assertEq(escrow.value, 100);
        assertEq(uint256(escrow.status), 1);

        vm.expectEmit();
        emit EscrowDisputeResolved(0);
        towerbank.refundBuyerNativeCoin(0);
        assertEq(alice.balance, 100000000);
        assertEq(bob.balance, 0);

        Towerbank.Escrow memory escrow1  = towerbank.getEscrow(0);
        assertEq(escrow1.buyer, address(0));
        assertEq(escrow1.seller, address(0));
        assertEq(address(escrow1.currency), address(0));
        assertEq(escrow1.value, 0);
        assertEq(uint256(escrow1.status), 0); 
    }

////////////////////////////////////TEST FAIL REFUND ESCROW NATIVE COIN////////////////////////////////// 
    function testRefundBuyerNativeCoinFail() public{
        assertEq(alice.balance, 100000000);
        towerbank.createEscrowNativeCoin{value: 100}(100, 300, IERC20(address(token)));
        assertEq(alice.balance, 99999900);

        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.refundBuyerNativeCoin(0);
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);

        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("EscrowIsNotFunded()"));
        towerbank.refundBuyerNativeCoin(5);
        assertEq(alice.balance, 99999900);
        assertEq(bob.balance, 0);
    }
////////////////////////////////////TEST WITHDRAW FEES////////////////////////////////// 
    function testWithdrawFees() public {
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
        towerbank.setFeeSeller(500);
        vm.startPrank(alice);
        assertEq(towerbank.feesAvailable(IERC20(address(token))), 0);
        token.approve(address(towerbank), 3500);
        towerbank.createEscrowToken(700, 1400, IERC20(address(token)));
        towerbank.releaseEscrow(0);
        towerbank.createEscrowToken(500, 1000, IERC20(address(token)));
        towerbank.releaseEscrow(1);
        towerbank.createEscrowToken(700, 1400, IERC20(address(token)));
        towerbank.releaseEscrow(2);
        towerbank.createEscrowToken(600, 1200, IERC20(address(token)));
        towerbank.releaseEscrow(3);
        assertEq(token.balanceOf(address(this)),0);
        assertEq(towerbank.feesAvailable(IERC20(address(token))), 11);

        vm.stopPrank();
        towerbank.withdrawFees(IERC20(address(token)));

        assertEq(token.balanceOf(address(this)),11);
        assertEq(token.balanceOf(bob), 2500-11);
        assertEq(towerbank.feesAvailable(IERC20(address(token))), 0);
    }
////////////////////////////////////TEST FAIL WITHDRAW FEES////////////////////////////////// 
    function testWithdrawFeesFail() public{
            assertEq(token.balanceOf(address(this)),0);
            vm.expectRevert("Ownable: caller is not the owner");
            towerbank.withdrawFees(IERC20(address(token)));

            vm.stopPrank();
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
            towerbank.withdrawFees(IERC20(address(token)));

            towerbank.setFeeSeller(500);

            assertEq(towerbank.feesAvailable(IERC20(address(token))), 0);
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
            towerbank.withdrawFees(IERC20(address(token)));
            assertEq(towerbank.feesAvailable(IERC20(address(token))), 0);
            assertEq(token.balanceOf(address(this)),0);
    }

////////////////////////////////////TEST WITHDRAW FEES NATIVE COIN////////////////////////////////// 
    function testWithdrawFeesNativeCoin() public { 
        vm.stopPrank();
        towerbank.transferOwnership(alice);
        vm.startPrank(alice);
        towerbank.setFeeBuyer(500);
        towerbank.setFeeSeller(400);
        assertEq(towerbank.feesAvailableNativeCoin(), 0);
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
  
        towerbank.createEscrowNativeCoin{value: _value + _amountFeeBuyer}( _value, 300, IERC20(address(token)));
        towerbank.createEscrowNativeCoin{value: _value2 + _amountFeeBuyer2}(_value2, 300, IERC20(address(token)));

        assertEq(alice.balance, (aliceBalance - _value - _value2 - _amountFeeBuyer - _amountFeeBuyer2));
        assertEq(bob.balance, 0);

        towerbank.releaseEscrowNativeCoin(0);
        towerbank.releaseEscrowNativeCoin(1);

        assertEq(towerbank.feesAvailableNativeCoin(), totalFees);

        towerbank.withdrawFeesNativeCoin();
        assertEq(alice.balance, aliceBalance - _value - _value2 - _amountFeeBuyer - _amountFeeBuyer2 + totalFees);
        assertEq(bob.balance, _value + _value2 - _amountFeeSeller - _amountFeeSeller2);
    }

////////////////////////////////////TEST FAIL WITHDRAW FEES NATIVE COIN////////////////////////////////// 
    function testWithdrawFeesNativeCoinFail() public { 
        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.withdrawFeesNativeCoin();
        vm.stopPrank();
        towerbank.transferOwnership(alice);
        vm.startPrank(alice);
        assertEq(towerbank.feesAvailableNativeCoin(), 0);
            vm.expectRevert(abi.encodeWithSignature("NoFeesToWithdraw()"));
        towerbank.withdrawFeesNativeCoin();
        assertEq(towerbank.feesAvailableNativeCoin(), 0);
    }


////////////////////////////////////TEST VERSION////////////////////////////////// 
    function TestVersion() public {
        string memory version = towerbank.version();
        assertEq(version, '0.0.3');
        assertEq(towerbank.version(), '0.0.3');
    }

////////////////////////////////////TEST GETESCROW////////////////////////////////// 
    function testGetEscrow() public{
      token.approve(address(towerbank), 50);
        towerbank.createEscrowToken(50, 300, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);

        Towerbank.Escrow memory escrowInfo  = towerbank.getEscrow(0);
        assertEq(escrowInfo.buyer, alice);
        assertEq(escrowInfo.seller, bob);
        assertEq(escrowInfo.value, 50);
        assertEq(escrowInfo.sellerfee, 0);
        assertEq(escrowInfo.buyerfee, 0);
        assertEq(escrowInfo.escrowNative, false);
        // assertEq(towerbank.getEscrow(0).status, false);
        // assertEq(escrowInfo.currency, IERC20(address(token)));

        // console.log(escrowInfo.buyer);
        // console.log(escrowInfo.seller);
        // console.log(escrowInfo.escrowNative);
    }
////////////////////////////////////TEST GETVALUE////////////////////////////////// 
    function testGetValue() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(towerbank), 50);
        towerbank.createEscrowToken(50, 300, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        uint256 value = towerbank.getValue(0);
        assertEq(value, 50);
        assertEq(towerbank.getValue(0), 50);
    }
////////////////////////////////////TEST GETSTATE////////////////////////////////// 
    function testGetState() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(towerbank), 50);
        towerbank.createEscrowToken(50, 300, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        Towerbank.EscrowStatus state = towerbank.getState(0);
        require(state == Towerbank.EscrowStatus.Funded, "Estado del escrow no es Funded");
    }
////////////////////////////////////TEST ISESCROWNATIVE////////////////////////////////// 
    function testIsEscrowNative() public{
        assertEq(token.balanceOf(alice), 50000000000000000000000000);
        token.approve(address(towerbank), 50);
        towerbank.createEscrowToken(50, 300, IERC20(address(token)));
        assertEq(token.balanceOf(alice), 49999999999999999999999950);
        bool typeEscrow = towerbank.isEscrowNative(0);
        assertEq(typeEscrow, false);
        assertEq(towerbank.isEscrowNative(0), false);
    }
////////////////////////////////////TEST SET FEESELLER////////////////////////////////// 
    function testSetFeeSeller() public{
        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.setFeeSeller(500);
        vm.stopPrank();
        // vm.expectRevert(abi.encodeWithSignature("FeeCanBeFrom0to1Percent"));
        assertEq(towerbank.feeSeller(), 0);
        towerbank.setFeeSeller(500);
        assertEq(towerbank.feeSeller(), 500);
        // vm.expectRevert("The fee can be from 0% to 1%");
        // towerbank.setFeeSeller(400 - 500);
    }
////////////////////////////////////TEST SET FEEBUYER////////////////////////////////// 
    function testSetFeeBuyer() public{
        vm.expectRevert("Ownable: caller is not the owner");
        towerbank.setFeeBuyer(500);
        vm.stopPrank();
        assertEq(towerbank.feeBuyer(), 0);
        towerbank.setFeeBuyer(500);
        assertEq(towerbank.feeBuyer(), 500);
        // vm.expectRevert("The fee can be from 0% to 1%");
        // towerbank.setFeeBuyer(400 - 500);
    }
}

