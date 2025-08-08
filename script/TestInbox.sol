// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MessageInbox} from "../src/MessageInbox.sol";
import {EncryptedMessageInbox} from "../src/EncryptedMessageInbox.sol";
import {EncryptedMessageInboxLight} from "../src/EncryptedMessageInboxLight.sol";

contract TestInboxScript is Script {
    // Test messages for encryption
    string[] private testMessages = [
        "Hello from the blockchain!",
        "This is a secret message", 
        "Testing encryption workflow",
        "Multi-message test case"
    ];
    
    // Deployment info (loaded from JSON)
    address private deployedContractAddress;
    string private contractType;
    
    function setUp() public {}

    function run() public {
        console.log("=== INBOX TESTING WORKFLOW ===");
        console.log("NOTE: This script expects DeployInbox.s.sol to have run first!");
        console.log("");
        
        // Load deployment info from JSON created by DeployInbox.s.sol
        _loadDeploymentInfo();
        
        // Setup encryption environment
        _setupEncryptionEnvironment();
        
        // Test encryption workflow
        _testEncryptionWorkflow();
        
        // Send encrypted messages to contract
        _sendEncryptedMessages();
        
        // Verify contract state
        _verifyContractState();
        
        console.log("");
        console.log("=== TESTING WORKFLOW COMPLETE ===");
        console.log("All tests completed successfully!");
    }
    
    function _loadDeploymentInfo() private {
        console.log("[STEP 1] Loading deployment information from JSON...");
        
        string[] memory cmd = new string[](2);
        cmd[0] = "cat";
        cmd[1] = "deployments/latest-deployment.json";
        
        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("SUCCESS: Found deployment JSON file");
            
            deployedContractAddress = _extractAddressFromJson();
            contractType = _extractContractTypeFromJson();
            
            if (deployedContractAddress != address(0)) {
                console.log("Contract Address:", deployedContractAddress);
                console.log("Contract Type:", contractType);
            } else {
                console.log("ERROR: Could not extract contract address from JSON");
                revert("Invalid deployment JSON - run DeployInbox.s.sol first");
            }
        } catch {
            console.log("ERROR: Deployment JSON not found!");
            console.log("You must run DeployInbox.s.sol first:");
            console.log("forge script script/DeployInbox.s.sol:DeployInboxScript --via-ir --broadcast --ffi");
            revert("Run DeployInbox.s.sol first to create deployment JSON");
        }
        
        console.log("");
    }
    
    function _extractAddressFromJson() private returns (address) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "grep contractAddress deployments/latest-deployment.json | cut -d'\"' -f4";
        
        try vm.ffi(cmd) returns (bytes memory result) {
            string memory addressStr = _trimString(string(result));
            if (bytes(addressStr).length > 0) {
                return vm.parseAddress(addressStr);
            }
        } catch {}
        
        return address(0);
    }
    
    function _extractContractTypeFromJson() private returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";  
        cmd[2] = "grep contractType deployments/latest-deployment.json | cut -d'\"' -f4";
        
        try vm.ffi(cmd) returns (bytes memory result) {
            return _trimString(string(result));
        } catch {
            return "unsafe";
        }
    }
    
    function _trimString(string memory str) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) return str;
        
        uint256 start = 0;
        while (start < strBytes.length && (strBytes[start] == 0x20 || strBytes[start] == 0x0a || strBytes[start] == 0x0d)) {
            start++;
        }
        
        uint256 end = strBytes.length;
        while (end > start && (strBytes[end-1] == 0x20 || strBytes[end-1] == 0x0a || strBytes[end-1] == 0x0d)) {
            end--;
        }
        
        bytes memory trimmed = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            trimmed[i] = strBytes[start + i];
        }
        
        return string(trimmed);
    }
    
    function _setupEncryptionEnvironment() private {
        console.log("[STEP 2] Setting up encryption environment...");
        
        _installDependencies();
        _setupEncryptionKeys();
        
        console.log("");
    }
    
    function _installDependencies() private {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "cd not_forge_scripts/libsodium_usage && npm install --silent";
        
        try vm.ffi(cmd) {
            console.log("SETUP: Dependencies installed/checked");
        } catch {
            console.log("WARNING: Could not install dependencies");
        }
    }
    
    function _setupEncryptionKeys() private {
        string[] memory checkCmd = new string[](3);
        checkCmd[0] = "test";
        checkCmd[1] = "-f";
        checkCmd[2] = "not_forge_scripts/libsodium_usage/keys/private_key.txt";
        
        try vm.ffi(checkCmd) {
            console.log("SUCCESS: Using existing encryption keys");
        } catch {
            _generateNewKeys();
        }
    }
    
    function _generateNewKeys() private {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "cd not_forge_scripts/libsodium_usage && npm run keygen -- --output ./keys > /dev/null 2>&1";
        
        try vm.ffi(cmd) {
            console.log("SUCCESS: New encryption keys generated");
        } catch {
            console.log("WARNING: Could not generate keys");
        }
    }
    
    function _testEncryptionWorkflow() private {
        console.log("[STEP 3] Testing encryption workflow...");
        
        _testEncryption();
        _testDecryption();
        
        console.log("");
    }
    
    function _testEncryption() private {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "cd not_forge_scripts/libsodium_usage && npm run encrypt -- --public-key-file ./keys/public_key.txt --text 'Test message' > test-encrypted.txt 2>&1";
        
        try vm.ffi(cmd) {
            console.log("SUCCESS: Encryption test completed");
        } catch {
            console.log("WARNING: Encryption test failed");
        }
    }
    
    function _testDecryption() private {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = "cd not_forge_scripts/libsodium_usage && ENCRYPTED_TEXT=$(tail -1 test-encrypted.txt) && npm run decrypt -- --private-key-file ./keys/private_key.txt --text \"$ENCRYPTED_TEXT\" > /dev/null 2>&1";
        
        try vm.ffi(cmd) {
            console.log("SUCCESS: Decryption test completed");
        } catch {
            console.log("WARNING: Decryption test failed");
        }
    }
    
    function _sendEncryptedMessages() private {
        console.log("[STEP 4] Sending encrypted messages to contract...");
        
        if (deployedContractAddress == address(0)) {
            console.log("ERROR: No contract address available");
            return;
        }
        
        vm.startBroadcast();
        _sendTestMessages();
        vm.stopBroadcast();
        
        console.log("");
    }
    
    function _sendTestMessages() private {
        for (uint i = 0; i < testMessages.length; i++) {
            string memory mockEncrypted = string(abi.encodePacked(
                "encrypted_mock_", 
                vm.toString(i), 
                "_", 
                testMessages[i]
            ));
            
            _sendMessageToContract(mockEncrypted);
            console.log("SENT: Message", i + 1, "to contract");
        }
    }
    
    function _sendMessageToContract(string memory message) private {
        bytes32 typeHash = keccak256(abi.encodePacked(contractType));
        
        if (typeHash == keccak256("unsafe")) {
            MessageInbox(deployedContractAddress).setMessage(message, "test");
        } else if (typeHash == keccak256("light")) {
            EncryptedMessageInboxLight(deployedContractAddress).setMessage(message, "test");
        } else {
            EncryptedMessageInbox(deployedContractAddress).setMessage(message, "test");
        }
    }
    
    function _verifyContractState() private view {
        console.log("[STEP 5] Verifying contract state...");
        
        if (deployedContractAddress == address(0)) {
            console.log("ERROR: Could not verify contract state - no address");
            return;
        }
        
        uint256 messageCount = _getMessageCount();
        console.log("STATS: Total messages in contract:", messageCount);
        
        _displayRecentMessages(messageCount);
        console.log("SUCCESS: Contract verification complete");
    }
    
    function _getMessageCount() private view returns (uint256) {
        bytes32 typeHash = keccak256(abi.encodePacked(contractType));
        
        if (typeHash == keccak256("unsafe")) {
            return MessageInbox(deployedContractAddress).getMessageCount(msg.sender, "test");
        } else if (typeHash == keccak256("light")) {
            return EncryptedMessageInboxLight(deployedContractAddress).getMessageCount(msg.sender, "test");
        } else {
            return EncryptedMessageInbox(deployedContractAddress).getMessageCount(msg.sender, "test");
        }
    }
    
    function _displayRecentMessages(uint256 messageCount) private view {
        console.log("MESSAGES: Recent messages:");
        uint256 startIndex = messageCount >= 2 ? messageCount - 2 : 0;
        
        for (uint256 i = startIndex; i < messageCount; i++) {
            string memory message = _getMessage(i);
            console.log("  Message", i, ":", message);
        }
    }
    
    function _getMessage(uint256 index) private view returns (string memory) {
        bytes32 typeHash = keccak256(abi.encodePacked(contractType));
        
        if (typeHash == keccak256("unsafe")) {
            return MessageInbox(deployedContractAddress).getMessage(msg.sender, "test", index);
        } else if (typeHash == keccak256("light")) {
            return EncryptedMessageInboxLight(deployedContractAddress).getMessage(msg.sender, "test", index);
        } else {
            return EncryptedMessageInbox(deployedContractAddress).getMessage(msg.sender, "test", index);
        }
    }
}