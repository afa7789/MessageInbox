// # Deploy any version of MessageInbox
//
// ## IMPORTANT: Configure your encryption key first!
// ## Set ENCRYPT_PUBLIC_KEY environment variable or add to .env file
//
// ## CONTRACT_TYPE options:
// - "unsafe"     = MessageInbox (no validation)
// - "light"      = EncryptedMessageInboxLight (light validation)
// - "full"       = EncryptedMessageInbox (full validation)
//
// ## Usage examples:
//
// # Deploy unsafe with custom key via env var
// ENCRYPT_PUBLIC_KEY="your_base64_key_here" CONTRACT_TYPE=unsafe forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url http://localhost:8545 --private-key 0x... --broadcast
//
// # Deploy light version to testnet (needs ENCRYPT_PUBLIC_KEY in .env)
// CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
//
// # Deploy full version (default) - reads ENCRYPT_PUBLIC_KEY from .env
// forge script script/DeployInbox.s.sol:DeployInboxScript

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MessageInbox} from "../src/MessageInbox.sol";
import {EncryptedMessageInbox} from "../src/EncryptedMessageInbox.sol";
import {EncryptedMessageInboxLight} from "../src/EncryptedMessageInboxLight.sol";

contract DeployInboxScript is Script {
    // Fallback public key only used if PGP_PUBLIC_KEY env var is not set
    string public constant FALLBACK_PUBLIC_KEY = "qpWmc9zu0yUzKbVrkONfTc-EQeCDLawUY_0XNgQwXAk";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Get configuration from environment
        string memory contractType;
        try vm.envString("CONTRACT_TYPE") returns (string memory _contractType) {
            contractType = _contractType;
        } catch {
            contractType = "unsafe";
        }

        string memory publicKey;
        try vm.envString("ENCRYPT_PUBLIC_KEY") returns (string memory _publicKey) {
            publicKey = _publicKey;
            console.log("Using encryption key from environment variable");
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
        string memory contractName;

        if (keccak256(abi.encodePacked(contractType)) == keccak256("unsafe")) {
            MessageInbox inbox = new MessageInbox(publicKey);
            deployedContract = address(inbox);
            contractName = "MessageInbox";
            console.log("MessageInbox deployed at:", deployedContract);
            console.log("Security: NO VALIDATION (fastest, least secure)");
        } else if (keccak256(abi.encodePacked(contractType)) == keccak256("light")) {
            EncryptedMessageInboxLight inbox = new EncryptedMessageInboxLight(publicKey);
            deployedContract = address(inbox);
            contractName = "EncryptedMessageInboxLight";
            console.log("EncryptedMessageInboxLight deployed at:", deployedContract);
            console.log("Security: LIGHT VALIDATION (balanced)");
        } else {
            // Default to full validation
            EncryptedMessageInbox inbox = new EncryptedMessageInbox(publicKey);
            deployedContract = address(inbox);
            contractName = "EncryptedMessageInbox";
            console.log("EncryptedMessageInbox deployed at:", deployedContract);
            console.log("Security: FULL VALIDATION (most secure, highest gas)");
        }

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Contract address:", deployedContract);

        // Save deployment info to JSON file
        saveDeploymentInfo(deployedContract, contractName, contractType, publicKey);

        vm.stopBroadcast();
    }

    function saveDeploymentInfo(
        address contractAddress, 
        string memory contractName,
        string memory contractType,
        string memory publicKey
    ) private {
        string memory deploymentJson = string(abi.encodePacked(
            "{\n",
            '  "contractAddress": "', vm.toString(contractAddress), '",\n',
            '  "contractName": "', contractName, '",\n',
            '  "contractType": "', contractType, '",\n',
            '  "blockNumber": ', vm.toString(block.number), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(msg.sender), '",\n',
            '  "publicKey": "', publicKey, '",\n',
            '  "chainId": ', vm.toString(block.chainid), '\n',
            "}"
        ));

        string[] memory writeCmd = new string[](4);
        writeCmd[0] = "bash";
        writeCmd[1] = "-c";
        writeCmd[2] = string(abi.encodePacked(
            "echo '", deploymentJson, "' > deployments/latest-deployment.json"
        ));
        writeCmd[3] = "";

        // Create deployments directory if it doesn't exist
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "deployments";

        try vm.ffi(mkdirCmd) {} catch {}
        try vm.ffi(writeCmd) {
            console.log("Deployment info saved to: deployments/latest-deployment.json");
        } catch {
            console.log("Warning: Could not save deployment info to file");
        }
    }
}
