// # Deploy em rede local (Anvil)
// forge script script/Counter.s.sol:CounterScript --rpc-url http://localhost:8545 --private-key 0x... --broadcast

// # Deploy em testnet
// forge script script/Counter.s.sol:CounterScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast

// # Apenas simular (sem broadcast)
// forge script script/Counter.s.sol:CounterScript

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterScript is Script {
    Counter public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        counter = new Counter();

        vm.stopBroadcast();
    }
}
