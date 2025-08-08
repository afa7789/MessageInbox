// # Deploy MessageInbox Contract
//
// ## IMPORTANT: Configure your encryption key first!
// ## Set ENCRYPT_PUBLIC_KEY environment variable or add to .env file
//
// ## Usage examples:
//
// # Deploy with custom key via env var
// ENCRYPT_PUBLIC_KEY="your_base64_key_here" forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url http://localhost:8545 --private-key 0x... --broadcast --via-ir
//
// # Deploy to testnet (needs ENCRYPT_PUBLIC_KEY in .env)
// forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --via-ir
//
// # Deploy with default settings - reads ENCRYPT_PUBLIC_KEY from .env
// forge script script/DeployInbox.s.sol:DeployInboxScript --via-ir

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MessageInbox} from "../src/MessageInbox.sol";

contract DeployInboxScript is Script {
    // Fallback public key only used if PGP_PUBLIC_KEY env var is not set
    string public constant FALLBACK_PUBLIC_KEY = "qpWmc9zu0yUzKbVrkONfTc-EQeCDLawUY_0XNgQwXAk";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Get public key from environment
        string memory publicKey = _getPublicKey();

        console.log("=== INBOX DEPLOYMENT ===");
        console.log("Contract type: MessageInbox");
        console.log("Public key source:", publicKey);
        console.log("Deployer:", msg.sender);
        console.log("");

        (address deployedContract, string memory contractName) = _deployContract(publicKey);

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Contract address:", deployedContract);

        // Save deployment info to JSON file
        _saveDeploymentInfo(deployedContract, contractName, "MessageInbox", publicKey);

        vm.stopBroadcast();
    }

    function _getPublicKey() private view returns (string memory) {
        try vm.envString("ENCRYPT_PUBLIC_KEY") returns (string memory _publicKey) {
            console.log("Using encryption key from environment variable");
            return _publicKey;
        } catch {
            console.log("WARNING: Using fallback test key. Set ENCRYPT_PUBLIC_KEY environment variable for production!");
            return FALLBACK_PUBLIC_KEY;
        }
    }

    function _deployContract(string memory publicKey)
        private
        returns (address deployedContract, string memory contractName)
    {
        // Only MessageInbox is available, so deploy it
        MessageInbox inbox = new MessageInbox(publicKey);
        deployedContract = address(inbox);
        contractName = "MessageInbox";
        console.log("MessageInbox deployed at:", deployedContract);
        console.log("Security: NO VALIDATION (fastest, least secure)");
    }

    function _saveDeploymentInfo(
        address contractAddress,
        string memory contractName,
        string memory contractType,
        string memory publicKey
    ) private {
        // Create deployments directory first
        _createDeploymentsDirectory();

        // Create simplified JSON to avoid stack too deep
        _writeDeploymentJson(contractAddress, contractName, contractType, publicKey);
    }

    function _createDeploymentsDirectory() private {
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "deployments";

        try vm.ffi(mkdirCmd) {} catch {}
    }

    function _writeDeploymentJson(
        address contractAddress,
        string memory contractName,
        string memory contractType,
        string memory publicKey
    ) private {
        // Simplified approach to avoid stack too deep
        string memory addressStr = vm.toString(contractAddress);
        string memory blockNumberStr = vm.toString(block.number);
        string memory timestampStr = vm.toString(block.timestamp);
        string memory deployerStr = vm.toString(msg.sender);
        string memory chainIdStr = vm.toString(block.chainid);

        // Build JSON in parts to avoid stack issues
        string memory part1 = string(
            abi.encodePacked(
                "{\n", '  "contractAddress": "', addressStr, '",\n', '  "contractName": "', contractName, '",\n'
            )
        );

        string memory part2 = string(
            abi.encodePacked('  "contractType": "', contractType, '",\n', '  "blockNumber": ', blockNumberStr, ",\n")
        );

        string memory part3 =
            string(abi.encodePacked('  "timestamp": ', timestampStr, ",\n", '  "deployer": "', deployerStr, '",\n'));

        string memory part4 =
            string(abi.encodePacked('  "publicKey": "', publicKey, '",\n', '  "chainId": ', chainIdStr, "\n", "}"));

        string memory fullJson = string(abi.encodePacked(part1, part2, part3, part4));

        string[] memory writeCmd = new string[](3);
        writeCmd[0] = "bash";
        writeCmd[1] = "-c";
        writeCmd[2] = string(abi.encodePacked("echo '", fullJson, "' > deployments/latest-deployment.json"));

        try vm.ffi(writeCmd) {
            console.log("Deployment info saved to: deployments/latest-deployment.json");
        } catch {
            console.log("Warning: Could not save deployment info to file");
        }
    }
}
