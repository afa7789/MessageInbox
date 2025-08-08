// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import "../src/MessageInbox.sol";

/**
 * @title MessageInbox Basic Test Suite
 * @dev Tests for the basic MessageInbox contract without encryption validation
 */
contract MessageInboxBasicTest is Test {
    MessageInbox public inbox;

    // Test accounts with meaningful names
    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    // Constants
    string public constant INITIAL_PUBLIC_KEY = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQENBGH...test key...";
    uint256 public constant INITIAL_BALANCE = 100 ether;

    // Events for testing
    event NewMessage(address indexed from, string topic, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        // Setup test accounts with meaningful names
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Fund accounts with ETH
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
        vm.deal(charlie, INITIAL_BALANCE);

        // Deploy MessageInbox (no encryption validation)
        inbox = new MessageInbox(INITIAL_PUBLIC_KEY);

        // Label addresses for better trace readability
        vm.label(address(inbox), "MessageInbox");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
    }

    // ============ BASIC FUNCTIONALITY TESTS ============

    /**
     * @dev Test contract initialization
     */
    function test_ContractInitialization() public view {
        assertEq(inbox.owner(), owner, "Owner should be set correctly");
        assertEq(inbox.publicKey(), INITIAL_PUBLIC_KEY, "Public key should be set correctly");
    }

    /**
     * @dev Test basic message storage (MessageInbox accepts any string)
     */
    function test_SetMessage_AcceptsAnyString() public {
        string memory plainText = "This is a plain text message";
        string memory topic = "general";

        vm.prank(alice);

        // Expect the NewMessage event
        vm.expectEmit(true, false, false, true);
        emit NewMessage(alice, topic, block.timestamp);

        inbox.setMessage(plainText, topic);

        // Verify message was stored
        assertEq(inbox.getMessageCount(alice, topic), 1, "Message count should be 1");
        assertEq(inbox.getMessage(alice, topic, 0), plainText, "Stored message should match");
    }

    /**
     * @dev Test empty message storage
     */
    function test_SetMessage_EmptyMessage() public {
        string memory emptyMessage = "";
        string memory topic = "empty_test";

        vm.prank(alice);
        inbox.setMessage(emptyMessage, topic);

        assertEq(inbox.getMessageCount(alice, topic), 1, "Should store empty message");
        assertEq(inbox.getMessage(alice, topic, 0), emptyMessage, "Empty message should be stored");
    }

    /**
     * @dev Test very long message storage
     */
    function test_SetMessage_VeryLongMessage() public {
        // Create a very long message (10KB)
        string memory longMessage = _generateLongString(10000);
        string memory topic = "long_message_test";

        vm.prank(alice);
        inbox.setMessage(longMessage, topic);

        assertEq(inbox.getMessageCount(alice, topic), 1, "Should store long message");
        assertEq(inbox.getMessage(alice, topic, 0), longMessage, "Long message should be stored correctly");
    }

    /**
     * @dev Test multiple messages from same user, same topic
     */
    function test_MultipleMessages_SameUserSameTopic() public {
        string memory topic = "general";
        string memory message1 = "First message";
        string memory message2 = "Second message";
        string memory message3 = "Third message";

        vm.startPrank(alice);
        inbox.setMessage(message1, topic);
        inbox.setMessage(message2, topic);
        inbox.setMessage(message3, topic);
        vm.stopPrank();

        // Verify all messages were stored in correct order
        assertEq(inbox.getMessageCount(alice, topic), 3, "Should have 3 messages");
        assertEq(inbox.getMessage(alice, topic, 0), message1, "First message should match");
        assertEq(inbox.getMessage(alice, topic, 1), message2, "Second message should match");
        assertEq(inbox.getMessage(alice, topic, 2), message3, "Third message should match");
    }

    /**
     * @dev Test multiple messages from same user, different topics
     */
    function test_MultipleMessages_SameUserDifferentTopics() public {
        string memory workTopic = "work";
        string memory personalTopic = "personal";
        string memory workMessage = "Work related message";
        string memory personalMessage = "Personal message";

        vm.startPrank(alice);
        inbox.setMessage(workMessage, workTopic);
        inbox.setMessage(personalMessage, personalTopic);
        vm.stopPrank();

        // Verify messages are stored under correct topics
        assertEq(inbox.getMessageCount(alice, workTopic), 1, "Should have 1 message in work topic");
        assertEq(inbox.getMessageCount(alice, personalTopic), 1, "Should have 1 message in personal topic");
        assertEq(inbox.getMessage(alice, workTopic, 0), workMessage, "Work message should match");
        assertEq(inbox.getMessage(alice, personalTopic, 0), personalMessage, "Personal message should match");
    }

    /**
     * @dev Test messages from different users
     */
    function test_MultipleMessages_DifferentUsers() public {
        string memory topic = "general";
        string memory aliceMessage = "Alice's message";
        string memory bobMessage = "Bob's message";
        string memory charlieMessage = "Charlie's message";

        vm.prank(alice);
        inbox.setMessage(aliceMessage, topic);

        vm.prank(bob);
        inbox.setMessage(bobMessage, topic);

        vm.prank(charlie);
        inbox.setMessage(charlieMessage, topic);

        // Verify messages are stored separately by user
        assertEq(inbox.getMessageCount(alice, topic), 1, "Alice should have 1 message");
        assertEq(inbox.getMessageCount(bob, topic), 1, "Bob should have 1 message");
        assertEq(inbox.getMessageCount(charlie, topic), 1, "Charlie should have 1 message");

        assertEq(inbox.getMessage(alice, topic, 0), aliceMessage, "Alice's message should match");
        assertEq(inbox.getMessage(bob, topic, 0), bobMessage, "Bob's message should match");
        assertEq(inbox.getMessage(charlie, topic, 0), charlieMessage, "Charlie's message should match");
    }

    // ============ ERROR HANDLING TESTS ============

    /**
     * @dev Test getMessage with invalid index
     */
    function test_GetMessage_InvalidIndex() public {
        string memory topic = "general";

        // Try to get message when no messages exist
        vm.expectRevert("Message index out of bounds");
        inbox.getMessage(alice, topic, 0);

        // Store one message
        string memory message = "Test message";
        vm.prank(alice);
        inbox.setMessage(message, topic);

        // Try to get message at index 1 when only index 0 exists
        vm.expectRevert("Message index out of bounds");
        inbox.getMessage(alice, topic, 1);
    }

    /**
     * @dev Test getMessageCount for empty topic
     */
    function test_GetMessageCount_EmptyTopic() public view {
        uint256 count = inbox.getMessageCount(alice, "nonexistent");
        assertEq(count, 0, "Count should be 0 for empty topic");
    }

    // ============ OWNERSHIP TESTS ============

    /**
     * @dev Test public key management - only owner
     */
    function test_SetPublicKey_OnlyOwner() public {
        string memory newKey = "-----BEGIN PGP PUBLIC KEY BLOCK-----\nnew key content...";

        // Owner can set public key
        inbox.setPublicKey(newKey);
        assertEq(inbox.publicKey(), newKey, "Public key should be updated");

        // Non-owner cannot set public key
        vm.prank(alice);
        vm.expectRevert("Only owner can call this function");
        inbox.setPublicKey("unauthorized key");
    }

    /**
     * @dev Test ownership transfer
     */
    function test_TransferOwnership() public {
        address newOwner = alice;

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

    /**
     * @dev Test ownership transfer to zero address
     */
    function test_TransferOwnership_ZeroAddress() public {
        vm.expectRevert("New owner cannot be zero address");
        inbox.transferOwnership(address(0));
    }

    /**
     * @dev Test ownership transfer - only owner
     */
    function test_TransferOwnership_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Only owner can call this function");
        inbox.transferOwnership(bob);
    }

    // ============ EVENT TESTS ============

    /**
     * @dev Test NewMessage event emission
     */
    function test_NewMessageEvent() public {
        string memory message = "Test message for event";
        string memory topic = "event_test";

        vm.prank(alice);

        vm.expectEmit(true, false, false, true);
        emit NewMessage(alice, topic, block.timestamp);

        inbox.setMessage(message, topic);
    }

    /**
     * @dev Test event emission with different topics
     */
    function test_NewMessageEvent_DifferentTopics() public {
        string memory message = "Test message";
        string[] memory topics = new string[](3);
        topics[0] = "work";
        topics[1] = "personal";
        topics[2] = "general";

        vm.startPrank(alice);

        for (uint256 i = 0; i < topics.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit NewMessage(alice, topics[i], block.timestamp);
            inbox.setMessage(message, topics[i]);
        }

        vm.stopPrank();
    }

    // ============ EDGE CASE TESTS ============

    /**
     * @dev Test with empty topic string
     */
    function test_SetMessage_EmptyTopic() public {
        string memory message = "Message with empty topic";
        string memory emptyTopic = "";

        vm.prank(alice);
        inbox.setMessage(message, emptyTopic);

        assertEq(inbox.getMessageCount(alice, emptyTopic), 1, "Should work with empty topic");
        assertEq(inbox.getMessage(alice, emptyTopic, 0), message, "Message should be stored");
    }

    /**
     * @dev Test with very long topic string
     */
    function test_SetMessage_LongTopic() public {
        string memory message = "Message with long topic";
        string memory longTopic = _generateLongString(1000); // 1KB topic name

        vm.prank(alice);
        inbox.setMessage(message, longTopic);

        assertEq(inbox.getMessageCount(alice, longTopic), 1, "Should work with long topic");
        assertEq(inbox.getMessage(alice, longTopic, 0), message, "Message should be stored");
    }

    /**
     * @dev Test special characters in messages and topics
     */
    function test_SetMessage_SpecialCharacters() public {
        string memory message = "Message with special chars: !@#$%^&*()_+-=[]{}|;:,.<>?";
        string memory topic = "topic_with_special_chars_!@#$%";

        vm.prank(alice);
        inbox.setMessage(message, topic);

        assertEq(inbox.getMessageCount(alice, topic), 1, "Should handle special characters");
        assertEq(inbox.getMessage(alice, topic, 0), message, "Special characters should be preserved");
    }

    // ============ GAS OPTIMIZATION TESTS ============

    /**
     * @dev Test gas usage for message storage
     */
    function test_GasUsage_MessageStorage() public {
        string memory message = "Standard length message for gas testing purposes";
        string memory topic = "gas_test";

        vm.prank(alice);

        uint256 gasBefore = gasleft();
        inbox.setMessage(message, topic);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for basic message storage", gasUsed);

        // Basic MessageInbox should use less gas (no encryption validation)
        assertLt(gasUsed, 100000, "Basic inbox should use minimal gas");
    }

    /**
     * @dev Test gas usage comparison for different message sizes
     */
    function test_GasUsage_DifferentSizes() public {
        uint256[] memory sizes = new uint256[](4);
        sizes[0] = 50; // Small message
        sizes[1] = 200; // Medium message
        sizes[2] = 500; // Large message
        sizes[3] = 1000; // Very large message

        emit log_string("=== GAS USAGE BY MESSAGE SIZE (Basic MessageInbox) ===");

        for (uint256 i = 0; i < sizes.length; i++) {
            string memory message = _generateLongString(sizes[i]);
            string memory topic = string(abi.encodePacked("gas_test_", i));

            vm.prank(alice);
            uint256 gasBefore = gasleft();
            inbox.setMessage(message, topic);
            uint256 gasUsed = gasBefore - gasleft();

            emit log_named_uint("Message size (bytes)", sizes[i]);
            emit log_named_uint("Gas used", gasUsed);
            emit log_named_uint("Gas per byte", gasUsed / sizes[i]);
            emit log_string("---");
        }
    }

    // ============ FUZZING TESTS ============

    /**
     * @dev Fuzz test with various message lengths (with proper bounds)
     */
    function testFuzz_MessageStorage(uint256 seed, uint16 messageLength, uint8 topicLength, uint8 userIndex) public {
        // Use bound to ensure reasonable inputs and prevent overflow
        messageLength = uint16(bound(messageLength, 0, 1000)); // Reduced from 2000 to 1000
        topicLength = uint8(bound(topicLength, 0, 50)); // Reduced from 100 to 50
        userIndex = uint8(bound(userIndex, 0, 2)); // 0=alice, 1=bob, 2=charlie

        // Bound the seed to prevent extremely large values
        seed = bound(seed, 0, type(uint128).max);

        // Generate deterministic user, message, and topic
        address user = userIndex == 0 ? alice : userIndex == 1 ? bob : charlie;
        string memory message = _generateDeterministicString(seed, messageLength);
        string memory topic = _generateDeterministicString(seed + 1, topicLength);

        // Store initial count
        uint256 initialCount = inbox.getMessageCount(user, topic);

        // Send message
        vm.prank(user);
        inbox.setMessage(message, topic);

        // Verify storage
        assertEq(inbox.getMessageCount(user, topic), initialCount + 1, "Count should increment");
        assertEq(inbox.getMessage(user, topic, initialCount), message, "Message should match");
    }

    /**
     * @dev Fuzz test with random topics and users
     */
    function testFuzz_MultipleUsersAndTopics(bytes32 messageSeed, bytes32 topicSeed, uint8 userSeed) public {
        // Generate deterministic inputs
        address user = address(uint160(uint256(keccak256(abi.encode(userSeed)))));
        string memory message = string(abi.encodePacked("Message_", uint256(messageSeed)));
        string memory topic = string(abi.encodePacked("Topic_", uint256(topicSeed)));

        // Fund the user
        vm.deal(user, 1 ether);

        // Store message
        vm.prank(user);
        inbox.setMessage(message, topic);

        // Verify
        assertEq(inbox.getMessageCount(user, topic), 1, "Should store message for any user/topic");
        assertEq(inbox.getMessage(user, topic, 0), message, "Message should be retrievable");
    }

    // ============ COMPLEX WORKFLOW TESTS ============

    /**
     * @dev Test complex multi-user, multi-topic workflow
     */
    function test_ComplexWorkflow() public {
        // Setup different topics
        string memory workTopic = "work";
        string memory personalTopic = "personal";
        string memory publicTopic = "public";

        // Alice sends work and personal messages
        vm.startPrank(alice);
        inbox.setMessage("Alice work message 1", workTopic);
        inbox.setMessage("Alice work message 2", workTopic);
        inbox.setMessage("Alice personal message", personalTopic);
        vm.stopPrank();

        // Bob sends work and public messages
        vm.startPrank(bob);
        inbox.setMessage("Bob work message", workTopic);
        inbox.setMessage("Bob public message", publicTopic);
        vm.stopPrank();

        // Charlie sends messages to all topics
        vm.startPrank(charlie);
        inbox.setMessage("Charlie work message", workTopic);
        inbox.setMessage("Charlie personal message", personalTopic);
        inbox.setMessage("Charlie public message", publicTopic);
        vm.stopPrank();

        // Verify message counts
        assertEq(inbox.getMessageCount(alice, workTopic), 2, "Alice should have 2 work messages");
        assertEq(inbox.getMessageCount(alice, personalTopic), 1, "Alice should have 1 personal message");
        assertEq(inbox.getMessageCount(alice, publicTopic), 0, "Alice should have 0 public messages");

        assertEq(inbox.getMessageCount(bob, workTopic), 1, "Bob should have 1 work message");
        assertEq(inbox.getMessageCount(bob, personalTopic), 0, "Bob should have 0 personal messages");
        assertEq(inbox.getMessageCount(bob, publicTopic), 1, "Bob should have 1 public message");

        assertEq(inbox.getMessageCount(charlie, workTopic), 1, "Charlie should have 1 work message");
        assertEq(inbox.getMessageCount(charlie, personalTopic), 1, "Charlie should have 1 personal message");
        assertEq(inbox.getMessageCount(charlie, publicTopic), 1, "Charlie should have 1 public message");

        // Transfer ownership and update public key
        inbox.transferOwnership(alice);
        vm.prank(alice);
        inbox.setPublicKey("new public key after ownership transfer");

        assertEq(
            inbox.publicKey(), "new public key after ownership transfer", "Public key should be updated by new owner"
        );
    }

    // ============ HELPER FUNCTIONS ============

    /**
     * @dev Generate a long string of specified length
     */
    function _generateLongString(uint256 length) internal pure returns (string memory) {
        if (length == 0) return "";

        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            // Create repeating pattern: A-Z, a-z, 0-9
            uint256 charIndex = i % 62;
            if (charIndex < 26) {
                result[i] = bytes1(uint8(65 + charIndex)); // A-Z
            } else if (charIndex < 52) {
                result[i] = bytes1(uint8(97 + charIndex - 26)); // a-z
            } else {
                result[i] = bytes1(uint8(48 + charIndex - 52)); // 0-9
            }
        }
        return string(result);
    }

    /**
     * @dev Generate deterministic string based on seed and length
     */
    function _generateDeterministicString(uint256 seed, uint256 length) internal pure returns (string memory) {
        if (length == 0) return "";

        // Prevent overflow by limiting length to reasonable bounds
        if (length > 10000) length = 10000;

        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            uint256 charCode = uint256(keccak256(abi.encode(seed, i))) % 94 + 33; // Printable ASCII chars
            result[i] = bytes1(uint8(charCode));
        }
        return string(result);
    }
}
