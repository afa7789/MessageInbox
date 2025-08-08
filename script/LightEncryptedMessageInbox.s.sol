// # Deploy em rede local (Anvil) com chave pública customizada
// PGP_PUBLIC_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----..." forge script script/LightEncryptedMessageInbox.s.sol:LightEncryptedMessageInboxScript --rpc-url http://localhost:8545 --private-key 0x... --broadcast

// # Deploy em testnet com chave do .env
// forge script script/LightEncryptedMessageInbox.s.sol:LightEncryptedMessageInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast

// # Apenas simular (sem broadcast)
// forge script script/LightEncryptedMessageInbox.s.sol:LightEncryptedMessageInboxScript

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EncryptedMessageInboxLight} from "../src/EncryptedMessageInboxLight.sol";

contract LightEncryptedMessageInboxScript is Script {
    EncryptedMessageInboxLight public lightInbox;

    // Default fallback public key
    string public constant DEFAULT_PUBLIC_KEY = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBGH...test key...";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Get public key from environment variable or use default
        string memory publicKey;
        try vm.envString("ENCRYPT_PUBLIC_KEY") returns (string memory _publicKey) {
            publicKey = _publicKey;
        } catch {
            publicKey = DEFAULT_PUBLIC_KEY;
        }

        // Deploy do contrato EncryptedMessageInboxLight com validação otimizada
        lightInbox = new EncryptedMessageInboxLight(publicKey);

        console.log("EncryptedMessageInboxLight deployed at:", address(lightInbox));
        console.log("Owner:", lightInbox.owner());
        console.log("Public key:", publicKey);
        console.log("Encryption validation: LIGHT (balanced security and gas)");

        vm.stopBroadcast();
    }
}
