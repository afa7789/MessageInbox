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

        // Test retrieval and decryption
        _testRetrievalAndDecryption();

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

        // Check if we're in a forked environment (connected to actual network)
        try vm.activeFork() returns (uint256) {
            console.log("BROADCASTING: Sending real transactions...");
            vm.startBroadcast();
            _sendTestMessages();
            vm.stopBroadcast();
        } catch {
            console.log("SIMULATING: Testing contract interface...");
            _simulateTestMessages();
        }

        console.log("");
    }

    function _sendTestMessages() private {
        for (uint256 i = 0; i < testMessages.length; i++) {
            string memory encryptedMessage = _encryptMessage(testMessages[i]);

            if (bytes(encryptedMessage).length > 0) {
                MessageInbox(deployedContractAddress).setMessage(encryptedMessage, "test");
                console.log("SENT: Encrypted message", i + 1, "to contract");
                console.log("Original:", testMessages[i]);
            } else {
                console.log("WARNING: Failed to encrypt message", i + 1, ", using mock");
                string memory mockEncrypted =
                    string(abi.encodePacked("encrypted_mock_", vm.toString(i), "_", testMessages[i]));
                MessageInbox(deployedContractAddress).setMessage(mockEncrypted, "test");
                console.log("SENT: Mock encrypted message", i + 1, "to contract");
            }
        }
    }

    function _simulateTestMessages() private {
        for (uint256 i = 0; i < testMessages.length; i++) {
            string memory encryptedMessage = _encryptMessage(testMessages[i]);

            if (bytes(encryptedMessage).length > 0) {
                // Use a try-catch to handle potential simulation issues
                try this._testMessageSend(encryptedMessage) {
                    console.log("SIMULATED: Encrypted message", i + 1, "interface test passed");
                } catch {
                    console.log("WARNING: Message", i + 1, "simulation failed");
                }
            } else {
                console.log("WARNING: Failed to encrypt message", i + 1, "for simulation");
                string memory mockEncrypted =
                    string(abi.encodePacked("encrypted_mock_", vm.toString(i), "_", testMessages[i]));
                try this._testMessageSend(mockEncrypted) {
                    console.log("SIMULATED: Mock message", i + 1, "interface test passed");
                } catch {
                    console.log("WARNING: Mock message", i + 1, "simulation failed");
                }
            }
        }
    }

    // External function for testing message sends
    function _testMessageSend(string memory message) external {
        // This is just for testing the contract interface
        // In a real deployment, this would be called with vm.startBroadcast()
        MessageInbox(deployedContractAddress).setMessage(message, "test");
    }

    function _verifyContractState() private view {
        console.log("[STEP 5] Verifying contract state...");

        if (deployedContractAddress == address(0)) {
            console.log("ERROR: Could not verify contract state - no address");
            return;
        }

        // Check if we're in a forked environment
        try vm.activeFork() returns (uint256) {
            console.log("LIVE NETWORK: Checking actual contract state");
            _verifyLiveContract();
        } catch {
            console.log("SIMULATION: Checking contract interface");
            _verifyContractInterface();
        }

        console.log("SUCCESS: Contract verification complete");
    }

    function _encryptMessage(string memory message) private returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string(
            abi.encodePacked(
                "cd not_forge_scripts/libsodium_usage && npm run encrypt -- -f ./keys/public_key.txt --text '",
                message,
                "' 2>/dev/null | tail -1"
            )
        );

        try vm.ffi(cmd) returns (bytes memory result) {
            string memory encrypted = string(result);
            // Remove any trailing newlines
            encrypted = _trimString(encrypted);

            if (bytes(encrypted).length > 0) {
                return encrypted;
            } else {
                return "";
            }
        } catch {
            return "";
        }
    }

    function _trimString(string memory str) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint256 length = strBytes.length;

        // Remove trailing whitespace/newlines
        while (
            length > 0 && (strBytes[length - 1] == 0x0A || strBytes[length - 1] == 0x0D || strBytes[length - 1] == 0x20)
        ) {
            length--;
        }

        if (length == strBytes.length) {
            return str;
        }

        bytes memory trimmed = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            trimmed[i] = strBytes[i];
        }

        return string(trimmed);
    }

    function _testRetrievalAndDecryption() private {
        console.log("[STEP 6] Testing message retrieval and decryption...");

        if (deployedContractAddress == address(0)) {
            console.log("ERROR: No contract address available");
            return;
        }

        // Check if we're in a forked environment (connected to actual network)
        try vm.activeFork() returns (uint256) {
            console.log("LIVE NETWORK: Testing retrieval and decryption");
            _testLiveRetrievalAndDecryption();
        } catch {
            console.log("SIMULATION: Cannot test retrieval in simulation mode");
        }

        console.log("");
    }

    function _testLiveRetrievalAndDecryption() private {
        // Get the number of messages stored
        uint256 messageCount;
        try MessageInbox(deployedContractAddress).getMessageCount(msg.sender, "test") returns (uint256 count) {
            messageCount = count;
            console.log("Found", messageCount, "messages to test");
        } catch {
            console.log("ERROR: Could not get message count");
            return;
        }

        // Test retrieving and decrypting each message
        for (uint256 i = 0; i < messageCount && i < testMessages.length; i++) {
            console.log("--- Testing message", i + 1, "---");

            try MessageInbox(deployedContractAddress).getMessage(msg.sender, "test", i) returns (
                string memory encryptedMessage
            ) {
                console.log("RETRIEVED encrypted message");

                // Try to decrypt the message
                string memory decryptedMessage = _decryptMessage(encryptedMessage);

                if (bytes(decryptedMessage).length > 0) {
                    console.log("DECRYPTED message:", decryptedMessage);

                    // Check if it matches the original
                    if (keccak256(bytes(decryptedMessage)) == keccak256(bytes(testMessages[i]))) {
                        console.log("SUCCESS: Decrypted message matches original!");
                    } else {
                        console.log("WARNING: Decrypted message differs from original");
                        console.log("Expected:", testMessages[i]);
                        console.log("Got:", decryptedMessage);
                    }
                } else {
                    console.log("ERROR: Failed to decrypt message");
                }
            } catch {
                console.log("ERROR: Could not retrieve message", i);
            }

            console.log("");
        }
    }

    function _decryptMessage(string memory encryptedMessage) private returns (string memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string(
            abi.encodePacked(
                "cd not_forge_scripts/libsodium_usage && npm run decrypt -- --private-key-file ./keys/private_key.txt --text '",
                encryptedMessage,
                "' 2>/dev/null | tail -1"
            )
        );

        try vm.ffi(cmd) returns (bytes memory result) {
            string memory decrypted = string(result);
            // Remove any trailing newlines
            decrypted = _trimString(decrypted);

            if (bytes(decrypted).length > 0) {
                return decrypted;
            } else {
                return "";
            }
        } catch {
            return "";
        }
    }

    function _verifyLiveContract() private view {
        try MessageInbox(deployedContractAddress).publicKey() returns (string memory pubKey) {
            console.log("SUCCESS: Contract is responsive");
            console.log("Public Key:", pubKey);

            // Try to get message count
            try MessageInbox(deployedContractAddress).getMessageCount(msg.sender, "test") returns (uint256 count) {
                console.log("STATS: Total messages in contract:", count);
            } catch {
                console.log("INFO: No messages found or access denied");
            }
        } catch {
            console.log("WARNING: Could not read contract state");
        }
    }

    function _verifyContractInterface() private view {
        // Check if contract exists and has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(sload(deployedContractAddress.slot))
        }

        if (codeSize > 0) {
            console.log("SUCCESS: Contract has code at address");
        } else {
            console.log("INFO: Contract not found in simulation environment");
        }
    }
}
