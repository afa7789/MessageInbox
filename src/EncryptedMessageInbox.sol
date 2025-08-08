// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./EncryptionValidator.sol";

/**
 * @title MessageInbox
 * @dev Contract for storing encrypted messages organized by topics
 * @notice This contract requires all messages to be encrypted before storage
 * @author Arthur Abeilice
 */
contract EncryptedMessageInbox {
    using EncryptionValidator for string;

    /// @notice Public key used for encrypting messages sent to this inbox
    /// @dev This key should be in PGP format or similar
    string public publicKey;

    /// @notice Address of the contract owner who can manage the public key
    address public owner;

    /// @dev Mapping from sender address to topic to array of encrypted messages
    /// @notice Format: messagesFromUsers[sender][topic][messageIndex]
    mapping(address => mapping(string => string[])) messagesFromUsers;

    /// @notice Emitted when a new encrypted message is successfully stored
    /// @param from Address of the message sender
    /// @param topic Topic/category of the message
    /// @param timestamp Block timestamp when message was stored
    event NewMessage(address indexed from, string topic, uint256 timestamp);

    /// @notice Emitted when a message is rejected due to validation failure
    /// @param from Address of the message sender
    /// @param topic Topic/category of the attempted message
    /// @param timestamp Block timestamp when rejection occurred
    /// @param reason Human-readable reason for rejection
    event MessageRejected(address indexed from, string topic, uint256 timestamp, string reason);

    /**
     * @notice Constructor to initialize the contract with a public key
     * @dev Sets the deployer as the owner and stores the initial public key
     * @param _publicKey The public key string to be used for message encryption
     */
    constructor(string memory _publicKey) {
        publicKey = _publicKey;
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to contract owner only
     * @notice Reverts if caller is not the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @notice Store an encrypted message under a specific topic
     * @dev Message must pass encryption validation checks using EncryptionValidator library
     * @param newMessage The encrypted message string to store
     * @param topic The topic/category under which to store the message
     * @custom:throws "Message must be encrypted" if validation fails
     */
    function setMessage(string calldata newMessage, string calldata topic) public {
        require(newMessage.isEncrypted(), "Message must be encrypted");

        emit NewMessage(msg.sender, topic, block.timestamp);
        messagesFromUsers[msg.sender][topic].push(newMessage);
    }

    /**
     * @notice Get the number of messages sent by a user under a specific topic
     * @param user Address of the message sender
     * @param topic Topic/category to query
     * @return Number of messages stored under the specified user and topic
     */
    function getMessageCount(address user, string calldata topic) external view returns (uint256) {
        return messagesFromUsers[user][topic].length;
    }

    /**
     * @notice Retrieve a specific message by user, topic, and index
     * @dev Messages are stored in chronological order (index 0 = oldest)
     * @param user Address of the message sender
     * @param topic Topic/category of the message
     * @param index Index of the message in the array (0-based)
     * @return The encrypted message string at the specified index
     * @custom:throws "Message index out of bounds" if index is invalid
     */
    function getMessage(address user, string calldata topic, uint256 index) external view returns (string memory) {
        require(index < messagesFromUsers[user][topic].length, "Message index out of bounds");
        return messagesFromUsers[user][topic][index];
    }

    /**
     * @notice Update the public key used for message encryption
     * @dev Only the contract owner can call this function
     * @param _publicKey New public key string (should be in PGP format or similar)
     * @custom:access Restricted to contract owner only
     */
    function setPublicKey(string calldata _publicKey) external onlyOwner {
        publicKey = _publicKey;
    }

    /**
     * @notice Transfer ownership of the contract to a new address
     * @dev Only the current owner can call this function
     * @param newOwner Address of the new owner
     * @custom:throws "New owner cannot be zero address" if newOwner is address(0)
     * @custom:access Restricted to current owner only
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
