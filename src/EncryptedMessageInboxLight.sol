// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./EncryptionValidator.sol";
import "./EncryptionValidatorLight.sol";

/**
 * @title EncryptedMessageInboxLight
 * @dev Gas-optimized version of MessageInbox using EncryptionValidatorLight
 * @notice This contract uses faster encryption validation for lower gas costs
 * @author Arthur Abeilice
 */
contract EncryptedMessageInboxLight {
    /// @notice Public key used for encrypting messages sent to this inbox
    string public publicKey;

    /// @notice Address of the contract owner who can manage the public key
    address public owner;

    /// @dev Mapping from sender address to topic to array of encrypted messages
    mapping(address => mapping(string => string[])) messagesFromUsers;

    /// @notice Emitted when a new encrypted message is successfully stored
    event NewMessage(address indexed from, string topic, uint256 timestamp);

    /**
     * @notice Constructor to initialize the contract with a public key
     * @param _publicKey The public key string to be used for message encryption
     */
    constructor(string memory _publicKey) {
        publicKey = _publicKey;
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to contract owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @notice Store an encrypted message under a specific topic (gas-optimized)
     * @dev Uses EncryptionValidatorLight for faster validation
     * @param newMessage The encrypted message string to store
     * @param topic The topic/category under which to store the message
     */
    function setMessage(string calldata newMessage, string calldata topic) public {
        require(EncryptionValidatorLight.isEncryptedLight(newMessage), "Message must be encrypted");

        emit NewMessage(msg.sender, topic, block.timestamp);
        messagesFromUsers[msg.sender][topic].push(newMessage);
    }

    /**
     * @notice Get the number of messages sent by a user under a specific topic
     */
    function getMessageCount(address user, string calldata topic) external view returns (uint256) {
        return messagesFromUsers[user][topic].length;
    }

    /**
     * @notice Retrieve a specific message by user, topic, and index
     */
    function getMessage(address user, string calldata topic, uint256 index) external view returns (string memory) {
        require(index < messagesFromUsers[user][topic].length, "Message index out of bounds");
        return messagesFromUsers[user][topic][index];
    }

    /**
     * @notice Update the public key used for message encryption
     */
    function setPublicKey(string calldata _publicKey) external onlyOwner {
        publicKey = _publicKey;
    }

    /**
     * @notice Transfer ownership of the contract to a new address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
