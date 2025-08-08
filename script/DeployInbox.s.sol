// # Deploy qualquer versão do MessageInbox
//
// ## IMPORTANTE: Configure sua chave PGP primeiro!
// ## Set PGP_PUBLIC_KEY environment variable or add to .env file
//
// ## Opções de CONTRACT_TYPE:
// - "unsafe"     = MessageInbox (sem validação)
// - "light"      = EncryptedMessageInboxLight (validação leve)
// - "full"       = EncryptedMessageInbox (validação completa)
//
// ## Exemplos de uso:
//
// # Deploy unsafe com chave customizada via env var
// PGP_PUBLIC_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----\nyour_actual_key_here\n-----END PGP PUBLIC KEY BLOCK-----" CONTRACT_TYPE=unsafe forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url http://localhost:8545 --private-key 0x... --broadcast
//
// # Deploy light version em testnet (precisa configurar PGP_PUBLIC_KEY no .env)
// CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
//
// # Deploy full version (padrão) - lê PGP_PUBLIC_KEY do .env
// forge script script/DeployInbox.s.sol:DeployInboxScript

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MessageInbox} from "../src/MessageInbox.sol";
import {EncryptedMessageInbox} from "../src/EncryptedMessageInbox.sol";
import {EncryptedMessageInboxLight} from "../src/EncryptedMessageInboxLight.sol";

contract DeployInboxScript is Script {
    // Fallback public key only used if PGP_PUBLIC_KEY env var is not set
    string public constant FALLBACK_PUBLIC_KEY =
        "-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBGH...fallback_test_key...-----END PGP PUBLIC KEY BLOCK-----";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Get configuration from environment
        string memory contractType;
        try vm.envString("CONTRACT_TYPE") returns (string memory _contractType) {
            contractType = _contractType;
        } catch {
            contractType = "full";
        }

        string memory publicKey;
        try vm.envString("ENCRYPT_PUBLIC_KEY") returns (string memory _publicKey) {
            publicKey = _publicKey;
            console.log("Using PGP public key from environment variable");
        } catch {
            publicKey = FALLBACK_PUBLIC_KEY;
            console.log("WARNING: Using fallback test key. Set ENCRYPT_PUBLIC_KEY environment variable for production!");
        }

        console.log("=== INBOX DEPLOYMENT ===");
        console.log("Contract type:", contractType);
        console.log("Public key source:", publicKey);
        console.log("Deployer:", msg.sender);
        console.log("");

        address deployedContract;

        if (keccak256(abi.encodePacked(contractType)) == keccak256("unsafe")) {
            MessageInbox inbox = new MessageInbox(publicKey);
            deployedContract = address(inbox);
            console.log("MessageInbox deployed at:", deployedContract);
            console.log("Security: NO VALIDATION (fastest, least secure)");
        } else if (keccak256(abi.encodePacked(contractType)) == keccak256("light")) {
            EncryptedMessageInboxLight inbox = new EncryptedMessageInboxLight(publicKey);
            deployedContract = address(inbox);
            console.log("EncryptedMessageInboxLight deployed at:", deployedContract);
            console.log("Security: LIGHT VALIDATION (balanced)");
        } else {
            // Default to full validation
            EncryptedMessageInbox inbox = new EncryptedMessageInbox(publicKey);
            deployedContract = address(inbox);
            console.log("EncryptedMessageInbox deployed at:", deployedContract);
            console.log("Security: FULL VALIDATION (most secure, highest gas)");
        }

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Contract address:", deployedContract);

        vm.stopBroadcast();
    }
}
