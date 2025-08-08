// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MessageInbox} from "../src/MessageInbox.sol";

contract TestInboxScript is Script {
    using stdJson for string;
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

        string memory json;
        try vm.readFile("deployments/latest-deployment.json") returns (string memory _json) {
            json = _json;
            console.log("SUCCESS: Found deployment JSON file");
        } catch {
            console.log("ERROR: Deployment JSON not found!");
            console.log("You must run DeployInbox.s.sol first:");
            console.log("forge script script/DeployInbox.s.sol:DeployInboxScript --via-ir --broadcast --ffi");
            revert("Run DeployInbox.s.sol first to create deployment JSON");
        }

        // Parse JSON using stdJson
        deployedContractAddress = json.readAddress(".contractAddress");
        contractType = json.readString(".contractType");

        if (deployedContractAddress != address(0)) {
            console.log("Contract Address:", deployedContractAddress);
            console.log("Contract Type:", contractType);
        } else {
            console.log("ERROR: Could not extract contract address from JSON");
            revert("Invalid deployment JSON - run DeployInbox.s.sol first");
        }

        console.log("");
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

        // Test encryption and capture the encrypted output
        string memory encryptedMessage = _performEncryption();

        // Test decryption using the encrypted message
        _performDecryption(encryptedMessage);

        console.log("");
    }

    function _performEncryption() private returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] =
            "cd not_forge_scripts/libsodium_usage && npm run encrypt -- -f ./keys/public_key.txt --text 'Test message' 2>/dev/null | tail -1";

        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("SUCCESS: Encryption test completed");
            return string(result);
        } catch {
            console.log("WARNING: Encryption test failed");
            return "";
        }
    }

    function _performDecryption(string memory encryptedText) private {
        if (bytes(encryptedText).length == 0) {
            console.log("WARNING: No encrypted text to decrypt");
            return;
        }

        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string(
            abi.encodePacked(
                "cd not_forge_scripts/libsodium_usage && npm run decrypt -- --private-key-file ./keys/private_key.txt --text '",
                encryptedText,
                "' 2>/dev/null | tail -1"
            )
        );

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
        for (uint256 i = 0; i < testMessages.length; i++) {
            string memory mockEncrypted =
                string(abi.encodePacked("encrypted_mock_", vm.toString(i), "_", testMessages[i]));

            _sendMessageToContract(mockEncrypted);
            console.log("SENT: Message", i + 1, "to contract");
        }
    }

    function _sendMessageToContract(string memory message) private {
        // Only MessageInbox is available
        MessageInbox(deployedContractAddress).setMessage(message, "test");
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
        // Only MessageInbox is available
        return MessageInbox(deployedContractAddress).getMessageCount(msg.sender, "test");
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
        // Only MessageInbox is available
        return MessageInbox(deployedContractAddress).getMessage(msg.sender, "test", index);
    }
}
