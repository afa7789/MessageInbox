// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title EncryptionValidator
 * @dev Library for validating if data appears to be encrypted
 * @notice Provides utilities to check encryption characteristics of byte data
 * @author Arthur Abeilice
 */
library EncryptionValidator {
    /// @notice Minimum length required for encrypted data
    /// @dev Based on typical encryption overhead (e.g., libsodium adds ~40 bytes)
    uint256 public constant MIN_ENCRYPTED_LENGTH = 40;

    /// @notice Minimum entropy threshold for encryption validation
    /// @dev Percentage value used to determine if data appears encrypted
    uint256 public constant MIN_ENTROPY_THRESHOLD = 60; // Percentage

    /**
     * @notice Check if a message appears to be encrypted
     * @dev Performs multiple checks: length, entropy, and plain text detection
     * @param message The message string to be verified
     * @return isValid Whether the message appears to be encrypted
     */
    function isEncrypted(string memory message) internal pure returns (bool isValid) {
        bytes memory data = bytes(message);

        // 1. Check minimum length
        if (data.length < MIN_ENCRYPTED_LENGTH) {
            return false;
        }

        // 2. Check if it contains only printable characters (possible plain text)
        if (isProbablyPlainText(data)) {
            return false;
        }

        // 3. Check for high entropy
        if (!hasHighEntropy(data)) {
            return false;
        }

        return true;
    }

    /**
     * @notice Test encryption with detailed feedback
     * @dev Useful for testing and frontend validation
     * @param message The message string to test for encryption validity
     * @return isValid Whether the message appears to be encrypted
     * @return reason Human-readable explanation of the validation result
     */
    function testEncryption(string memory message) internal pure returns (bool isValid, string memory reason) {
        bytes memory data = bytes(message);

        if (data.length < MIN_ENCRYPTED_LENGTH) {
            return (false, "Message too short");
        }

        if (isProbablyPlainText(data)) {
            return (false, "Looks like plain text");
        }

        if (!hasHighEntropy(data)) {
            return (false, "Low entropy - doesn't look encrypted");
        }

        return (true, "Looks encrypted");
    }

    /**
     * @dev Check if data appears to be plain text
     * @param data Byte array to analyze for plain text characteristics
     * @return true if data appears to be plain text, false otherwise
     * @notice Checks for high ratio of printable ASCII characters and spaces
     */
    function isProbablyPlainText(bytes memory data) internal pure returns (bool) {
        uint256 printableCount = 0;
        uint256 spaceCount = 0;

        for (uint256 i = 0; i < data.length && i < 100; i++) {
            // Check only first 100 chars
            uint8 char = uint8(data[i]);

            // Count printable ASCII characters
            if ((char >= 32 && char <= 126)) {
                printableCount++;
                if (char == 32) {
                    // space
                    spaceCount++;
                }
            }
        }

        uint256 sampleSize = data.length > 100 ? 100 : data.length;

        // If >90% are printable characters AND there are spaces, probably text
        return (printableCount * 100 / sampleSize > 90) && (spaceCount > 0);
    }

    /**
     * @dev Calculate if data has high entropy (appears random)
     * @param data Byte array to analyze for entropy
     * @return true if data has high entropy (appears encrypted), false otherwise
     * @notice Uses improved byte distribution analysis to estimate randomness
     */
    function hasHighEntropy(bytes memory data) internal pure returns (bool) {
        if (data.length == 0) return false;

        uint256[256] memory frequency;

        // Count frequency of each byte
        for (uint256 i = 0; i < data.length; i++) {
            frequency[uint8(data[i])]++;
        }

        // Count unique values
        uint256 uniqueValues = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (frequency[i] > 0) {
                uniqueValues++;
            }
        }

        // Improved entropy calculation
        uint256 entropyPercentage;
        if (data.length <= 256) {
            // For short data, expect high ratio of unique bytes
            entropyPercentage = (uniqueValues * 100) / data.length;
        } else {
            // For long data, expect most possible byte values to appear
            entropyPercentage = (uniqueValues * 100) / 256;
        }

        return entropyPercentage >= MIN_ENTROPY_THRESHOLD;
    }
}
