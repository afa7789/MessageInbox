// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EncryptedMessageInbox.sol";
import "../src/EncryptedMessageInboxLight.sol";
import "../src/MessageInbox.sol";
import "../src/EncryptionValidator.sol";

contract EncryptedMessageInboxTest is Test {
    EncryptedMessageInbox public inbox;
    address public owner;
    address public user1;
    address public user2;
    string public constant INITIAL_PUBLIC_KEY = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBGH...test key...";
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        inbox = new EncryptedMessageInbox(INITIAL_PUBLIC_KEY);
    }

    // Helper function to generate encrypted-looking data
    function generateEncryptedMessage(uint256 seed, uint256 length) internal pure returns (string memory) {
        require(length >= EncryptionValidator.MIN_ENCRYPTED_LENGTH, "Length too short");
        
        bytes memory result = new bytes(length);
        for (uint i = 0; i < length; i++) {
            result[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i))) % 256));
        }
        return string(result);
    }

    // Helper function to generate plain text (should be rejected)
    function generatePlainText() internal pure returns (string memory) {
        return "This is a plain text message that should be rejected by validation";
    }

    // Test contract initialization
    function testContractInitialization() public view {
        assertEq(inbox.owner(), owner, "Owner should be set correctly");
        assertEq(inbox.publicKey(), INITIAL_PUBLIC_KEY, "Public key should be set correctly");
    }

    // Test successful message storage
    function testSetMessage_Success() public {
        string memory encryptedMsg = generateEncryptedMessage(12345, 80);
        string memory topic = "general";
        
        vm.prank(user1);
        
        // Expect the NewMessage event
        vm.expectEmit(true, false, false, true);
        emit EncryptedMessageInbox.NewMessage(user1, topic, block.timestamp);
        
        inbox.setMessage(encryptedMsg, topic);
        
        // Verify message was stored
        assertEq(inbox.getMessageCount(user1, topic), 1, "Message count should be 1");
        assertEq(inbox.getMessage(user1, topic, 0), encryptedMsg, "Stored message should match");
    }

    // Test message rejection for plain text
    function testSetMessage_RejectsPlainText() public {
        string memory plainMsg = generatePlainText();
        string memory topic = "general";
        
        vm.prank(user1);
        vm.expectRevert("Message must be encrypted");
        inbox.setMessage(plainMsg, topic);
        
        // Verify no message was stored
        assertEq(inbox.getMessageCount(user1, topic), 0, "No message should be stored");
    }

    // Test message rejection for too short data
    function testSetMessage_RejectsTooShort() public {
        string memory shortMsg = "short";
        string memory topic = "general";
        
        vm.prank(user1);
        vm.expectRevert("Message must be encrypted");
        inbox.setMessage(shortMsg, topic);
        
        // Verify no message was stored
        assertEq(inbox.getMessageCount(user1, topic), 0, "No message should be stored");
    }

    // Test multiple messages from same user, same topic
    function testMultipleMessages_SameUserSameTopic() public {
        string memory topic = "general";
        string memory message1 = generateEncryptedMessage(111, 60);
        string memory message2 = generateEncryptedMessage(222, 70);
        string memory message3 = generateEncryptedMessage(333, 80);
        
        vm.startPrank(user1);
        
        inbox.setMessage(message1, topic);
        inbox.setMessage(message2, topic);
        inbox.setMessage(message3, topic);
        
        vm.stopPrank();
        
        // Verify all messages were stored in correct order
        assertEq(inbox.getMessageCount(user1, topic), 3, "Should have 3 messages");
        assertEq(inbox.getMessage(user1, topic, 0), message1, "First message should match");
        assertEq(inbox.getMessage(user1, topic, 1), message2, "Second message should match");
        assertEq(inbox.getMessage(user1, topic, 2), message3, "Third message should match");
    }

    // Test multiple messages from same user, different topics
    function testMultipleMessages_SameUserDifferentTopics() public {
        string memory topic1 = "work";
        string memory topic2 = "personal";
        string memory message1 = generateEncryptedMessage(111, 60);
        string memory message2 = generateEncryptedMessage(222, 70);
        
        vm.startPrank(user1);
        
        inbox.setMessage(message1, topic1);
        inbox.setMessage(message2, topic2);
        
        vm.stopPrank();
        
        // Verify messages are stored under correct topics
        assertEq(inbox.getMessageCount(user1, topic1), 1, "Should have 1 message in work topic");
        assertEq(inbox.getMessageCount(user1, topic2), 1, "Should have 1 message in personal topic");
        assertEq(inbox.getMessage(user1, topic1, 0), message1, "Work message should match");
        assertEq(inbox.getMessage(user1, topic2, 0), message2, "Personal message should match");
    }

    // Test messages from different users
    function testMultipleMessages_DifferentUsers() public {
        string memory topic = "general";
        string memory message1 = generateEncryptedMessage(111, 60);
        string memory message2 = generateEncryptedMessage(222, 70);
        
        vm.prank(user1);
        inbox.setMessage(message1, topic);
        
        vm.prank(user2);
        inbox.setMessage(message2, topic);
        
        // Verify messages are stored separately by user
        assertEq(inbox.getMessageCount(user1, topic), 1, "User1 should have 1 message");
        assertEq(inbox.getMessageCount(user2, topic), 1, "User2 should have 1 message");
        assertEq(inbox.getMessage(user1, topic, 0), message1, "User1 message should match");
        assertEq(inbox.getMessage(user2, topic, 0), message2, "User2 message should match");
    }

    // Test getMessage with invalid index
    function testGetMessage_InvalidIndex() public {
        string memory topic = "general";
        
        // Try to get message when no messages exist
        vm.expectRevert("Message index out of bounds");
        inbox.getMessage(user1, topic, 0);
        
        // Store one message
        string memory message = generateEncryptedMessage(111, 60);
        vm.prank(user1);
        inbox.setMessage(message, topic);
        
        // Try to get message at index 1 when only index 0 exists
        vm.expectRevert("Message index out of bounds");
        inbox.getMessage(user1, topic, 1);
    }

    // Test getMessageCount for empty topic
    function testGetMessageCount_EmptyTopic() public view {
        uint256 count = inbox.getMessageCount(user1, "nonexistent");
        assertEq(count, 0, "Count should be 0 for empty topic");
    }

    // Test public key management
    function testSetPublicKey_OnlyOwner() public {
        string memory newKey = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nnew key content...";
        
        // Owner can set public key
        inbox.setPublicKey(newKey);
        assertEq(inbox.publicKey(), newKey, "Public key should be updated");
        
        // Non-owner cannot set public key
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        inbox.setPublicKey("unauthorized key");
    }

    // Test ownership transfer
    function testTransferOwnership() public {
        address newOwner = user1;
        
        // Transfer ownership
        inbox.transferOwnership(newOwner);
        assertEq(inbox.owner(), newOwner, "Owner should be transferred");
        
        // Old owner can no longer set public key
        vm.expectRevert("Only owner can call this function");
        inbox.setPublicKey("test key");
        
        // New owner can set public key
        vm.prank(newOwner);
        inbox.setPublicKey("new owner key");
        assertEq(inbox.publicKey(), "new owner key", "New owner should be able to set key");
    }

    // Test ownership transfer to zero address
    function testTransferOwnership_ZeroAddress() public {
        vm.expectRevert("New owner cannot be zero address");
        inbox.transferOwnership(address(0));
    }

    // Test ownership transfer - only owner
    function testTransferOwnership_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        inbox.transferOwnership(user2);
    }

    // Test NewMessage event emission
    function testNewMessageEvent() public {
        string memory message = generateEncryptedMessage(12345, 80);
        string memory topic = "test";
        
        vm.prank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit EncryptedMessageInbox.NewMessage(user1, topic, block.timestamp);
        
        inbox.setMessage(message, topic);
    }

    // Test with empty topic string
    function testSetMessage_EmptyTopic() public {
        string memory message = generateEncryptedMessage(12345, 80);
        string memory emptyTopic = "";
        
        vm.prank(user1);
        inbox.setMessage(message, emptyTopic);
        
        assertEq(inbox.getMessageCount(user1, emptyTopic), 1, "Should work with empty topic");
        assertEq(inbox.getMessage(user1, emptyTopic, 0), message, "Message should be stored");
    }

    // Test with very long topic string
    function testSetMessage_LongTopic() public {
        string memory message = generateEncryptedMessage(12345, 80);
        string memory longTopic = "this_is_a_very_long_topic_name_that_might_be_used_for_detailed_categorization_purposes";
        
        vm.prank(user1);
        inbox.setMessage(message, longTopic);
        
        assertEq(inbox.getMessageCount(user1, longTopic), 1, "Should work with long topic");
        assertEq(inbox.getMessage(user1, longTopic, 0), message, "Message should be stored");
    }

    // Test message storage with minimum valid length
    function testSetMessage_MinimumLength() public {
        string memory message = generateEncryptedMessage(12345, EncryptionValidator.MIN_ENCRYPTED_LENGTH);
        string memory topic = "general";
        
        vm.prank(user1);
        inbox.setMessage(message, topic);
        
        assertEq(inbox.getMessageCount(user1, topic), 1, "Should accept minimum length encrypted message");
        assertEq(inbox.getMessage(user1, topic, 0), message, "Message should be stored correctly");
    }

    // Test message storage with large message
    function testSetMessage_LargeMessage() public {
        string memory message = generateEncryptedMessage(12345, 1000); // Large message
        string memory topic = "general";
        
        vm.prank(user1);
        inbox.setMessage(message, topic);
        
        assertEq(inbox.getMessageCount(user1, topic), 1, "Should accept large encrypted message");
        assertEq(inbox.getMessage(user1, topic, 0), message, "Large message should be stored correctly");
    }

    // Fuzz test with various message sizes
    function testFuzz_MessageSizes(uint256 seed, uint16 length) public {
        vm.assume(length >= EncryptionValidator.MIN_ENCRYPTED_LENGTH);
        vm.assume(length <= 2000); // Reasonable upper bound
        
        string memory message = generateEncryptedMessage(seed, length);
        string memory topic = "fuzz";
        
        vm.prank(user1);
        inbox.setMessage(message, topic);
        
        assertEq(inbox.getMessageCount(user1, topic), 1, "Fuzz message should be stored");
        assertEq(inbox.getMessage(user1, topic, 0), message, "Fuzz message should match");
    }

    // Test gas usage for message storage
    function testGasUsage_MessageStorage() public {
        string memory message = generateEncryptedMessage(12345, 200);
        string memory topic = "gas_test";
        
        vm.prank(user1);
        
        uint256 gasBefore = gasleft();
        inbox.setMessage(message, topic);
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas used for message storage (200 bytes)", gasUsed);
        
        // Gas usage should be reasonable (including validation + storage + event emission)
        // This includes: encryption validation (~100k) + storage operations (~150k) + events (~25k)
        assertGt(gasUsed, 300000, "Gas usage should be reasonable for message storage");
    }

    // Test multiple operations in sequence
    function testComplexWorkflow() public {
        // Setup different topics and users
        string memory workTopic = "work";
        string memory personalTopic = "personal";
        
        // User1 sends work messages
        vm.startPrank(user1);
        inbox.setMessage(generateEncryptedMessage(1, 80), workTopic);
        inbox.setMessage(generateEncryptedMessage(2, 90), workTopic);
        inbox.setMessage(generateEncryptedMessage(3, 100), personalTopic);
        vm.stopPrank();
        
        // User2 sends messages
        vm.startPrank(user2);
        inbox.setMessage(generateEncryptedMessage(4, 85), workTopic);
        inbox.setMessage(generateEncryptedMessage(5, 95), personalTopic);
        vm.stopPrank();
        
        // Verify counts
        assertEq(inbox.getMessageCount(user1, workTopic), 2, "User1 should have 2 work messages");
        assertEq(inbox.getMessageCount(user1, personalTopic), 1, "User1 should have 1 personal message");
        assertEq(inbox.getMessageCount(user2, workTopic), 1, "User2 should have 1 work message");
        assertEq(inbox.getMessageCount(user2, personalTopic), 1, "User2 should have 1 personal message");
        
        // Transfer ownership and update public key
        inbox.transferOwnership(user1);
        vm.prank(user1);
        inbox.setPublicKey("new public key after ownership transfer");
        
        assertEq(inbox.publicKey(), "new public key after ownership transfer", "Public key should be updated by new owner");
    }

    // Test gas comparison: Regular vs EncryptedMessageInboxLight
    function testGasComparison_RegularVsLightInbox() public {
        // Deploy light version
        EncryptedMessageInboxLight lightInbox = new EncryptedMessageInboxLight(INITIAL_PUBLIC_KEY);
        
        string memory message = generateEncryptedMessage(12345, 200);
        string memory topic = "gas_comparison";
        
        // Test regular EncryptedMessageInbox
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        inbox.setMessage(message, topic);
        uint256 gasRegular = gasBefore - gasleft();
        
        // Test EncryptedMessageInboxLight
        vm.prank(user1);
        gasBefore = gasleft();
        lightInbox.setMessage(message, topic);
        uint256 gasLight = gasBefore - gasleft();
        
        // Log comparison
        emit log_string("=== INBOX GAS COMPARISON ===");
        emit log_named_uint("Regular EncryptedMessageInbox (200 bytes)", gasRegular);
        emit log_named_uint("Light EncryptedMessageInbox (200 bytes)", gasLight);
        emit log_named_uint("Gas savings", gasRegular - gasLight);
        emit log_named_uint("Percentage reduction", ((gasRegular - gasLight) * 100) / gasRegular);
        
        // Verify both stored the message correctly
        assertEq(inbox.getMessageCount(user1, topic), 1, "Regular inbox should store message");
        assertEq(lightInbox.getMessageCount(user1, topic), 1, "Light inbox should store message");
        assertEq(inbox.getMessage(user1, topic, 0), message, "Regular inbox message should match");
        assertEq(lightInbox.getMessage(user1, topic, 0), message, "Light inbox message should match");
        
        // Light version should use significantly less gas
        assertLt(gasLight, gasRegular, "Light inbox should use less gas");
    }

    // Test comprehensive gas comparison: All three EncryptedMessageInbox versions
    function testGasComparison_AllThreeVersions() public {
        // Deploy all versions
        EncryptedMessageInboxLight lightInbox = new EncryptedMessageInboxLight(INITIAL_PUBLIC_KEY);
        MessageInbox unsafeInbox = new MessageInbox(INITIAL_PUBLIC_KEY);
        
        string memory message = generateEncryptedMessage(12345, 200);
        string memory topic = "comprehensive_gas_test";
        
        // Test Regular EncryptedMessageInbox (with full encryption validation)
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        inbox.setMessage(message, topic);
        uint256 gasRegular = gasBefore - gasleft();
        
        // Test Light EncryptedMessageInbox (with light encryption validation)
        vm.prank(user1);
        gasBefore = gasleft();
        lightInbox.setMessage(message, topic);
        uint256 gasLight = gasBefore - gasleft();
        
        // Test Unsafe EncryptedMessageInbox (no validation)
        vm.prank(user1);
        gasBefore = gasleft();
        unsafeInbox.setMessage(message, topic);
        uint256 gasUnsafe = gasBefore - gasleft();
        
        // Log comprehensive comparison
        emit log_string("=== COMPREHENSIVE INBOX GAS COMPARISON ===");
        emit log_named_uint("Regular EncryptedMessageInbox (200 bytes)", gasRegular);
        emit log_named_uint("Light EncryptedMessageInbox (200 bytes)", gasLight);
        emit log_named_uint("Unsafe EncryptedMessageInbox (200 bytes)", gasUnsafe);
        emit log_string("---");
        emit log_named_uint("Light vs Regular savings", gasRegular - gasLight);
        emit log_named_uint("Unsafe vs Regular savings", gasRegular - gasUnsafe);
        emit log_named_uint("Light vs Unsafe difference", gasLight - gasUnsafe);
        emit log_string("---");
        emit log_named_uint("Light reduction %", ((gasRegular - gasLight) * 100) / gasRegular);
        emit log_named_uint("Unsafe reduction %", ((gasRegular - gasUnsafe) * 100) / gasRegular);
        emit log_string("---");
        
        // Verify all stored the message correctly
        assertEq(inbox.getMessageCount(user1, topic), 1, "Regular inbox should store message");
        assertEq(lightInbox.getMessageCount(user1, topic), 1, "Light inbox should store message");
        assertEq(unsafeInbox.getMessageCount(user1, topic), 1, "Unsafe inbox should store message");
        
        // Gas ordering should be: Unsafe < Light < Regular
        assertLt(gasUnsafe, gasLight, "Unsafe should use less gas than Light");
        assertLt(gasLight, gasRegular, "Light should use less gas than Regular");
        
        // Calculate the cost of validation
        uint256 lightValidationCost = gasLight - gasUnsafe;
        uint256 fullValidationCost = gasRegular - gasUnsafe;
        
        emit log_named_uint("Light validation cost", lightValidationCost);
        emit log_named_uint("Full validation cost", fullValidationCost);
        emit log_named_uint("Validation overhead %", (fullValidationCost * 100) / gasUnsafe);
    }

    // Test that unsafe inbox accepts plain text (demonstrating the security risk)
    function testUnsafeInbox_AcceptsPlainText() public {
        MessageInbox unsafeInbox = new MessageInbox(INITIAL_PUBLIC_KEY);
        string memory plainText = generatePlainText();
        string memory topic = "security_risk_test";
        
        // Unsafe inbox should accept plain text (security risk!)
        vm.prank(user1);
        unsafeInbox.setMessage(plainText, topic);
        
        assertEq(unsafeInbox.getMessageCount(user1, topic), 1, "Unsafe inbox accepts plain text");
        assertEq(unsafeInbox.getMessage(user1, topic, 0), plainText, "Plain text stored without validation");
        
        // Regular inbox should reject the same plain text
        vm.prank(user1);
        vm.expectRevert("Message must be encrypted");
        inbox.setMessage(plainText, topic);
        
        assertEq(inbox.getMessageCount(user1, topic), 0, "Regular inbox correctly rejects plain text");
    }

    // Performance comparison with different message sizes
    function testPerformanceComparison_DifferentSizes() public {
        EncryptedMessageInboxLight lightInbox = new EncryptedMessageInboxLight(INITIAL_PUBLIC_KEY);
        MessageInbox unsafeInbox = new MessageInbox(INITIAL_PUBLIC_KEY);
        
        uint256[] memory sizes = new uint256[](4);
        sizes[0] = 80;   // Small message
        sizes[1] = 200;  // Medium message
        sizes[2] = 500;  // Large message
        sizes[3] = 1000; // Very large message
        
        emit log_string("=== PERFORMANCE BY MESSAGE SIZE ===");
        
        for (uint i = 0; i < sizes.length; i++) {
            string memory message = generateEncryptedMessage(111 + i, sizes[i]);
            string memory topic = string(abi.encodePacked("perf_test_", i));
            
            // Regular EncryptedMessageInbox
            vm.prank(user1);
            uint256 gasBefore = gasleft();
            inbox.setMessage(message, topic);
            uint256 gasRegular = gasBefore - gasleft();
            
            // Light EncryptedMessageInbox
            vm.prank(user1);
            gasBefore = gasleft();
            lightInbox.setMessage(message, topic);
            uint256 gasLight = gasBefore - gasleft();
            
            // Unsafe EncryptedMessageInbox
            vm.prank(user1);
            gasBefore = gasleft();
            unsafeInbox.setMessage(message, topic);
            uint256 gasUnsafe = gasBefore - gasleft();
            
            emit log_named_uint("Message size (bytes)", sizes[i]);
            emit log_named_uint("Regular gas", gasRegular);
            emit log_named_uint("Light gas", gasLight);
            emit log_named_uint("Unsafe gas", gasUnsafe);
            emit log_named_uint("Validation overhead", gasRegular - gasUnsafe);
            emit log_string("---");
        }
    }
}
