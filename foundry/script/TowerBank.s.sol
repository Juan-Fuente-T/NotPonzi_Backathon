// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import { Script } from "forge-std/Script.sol";
import { Towerbank } from "../src/Towerbank.sol";
import { USDTToken } from "../src/UsdtToken.sol";
import { console} from "forge-std/console.sol";

contract TowerbankDeploy is Script {

    function run() public {
        vm.startBroadcast();

        //address owner = vm.envAddress("OWNER");

        USDTToken usdtToken = new USDTToken();
        console.log("USDTToken deployed at: ", address(usdtToken));

        Towerbank towerbank = new Towerbank(address(usdtToken), 10, 100, 5, 1);
        console.log("Towerbank deployed at: ", address(towerbank));

        vm.stopBroadcast();
    }
}