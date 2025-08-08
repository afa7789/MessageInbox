// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title EncryptionValidatorLight
 * @dev Gas-optimized version of EncryptionValidator
 * @notice Faster and cheaper validation to check if data appears encrypted
 * @author Arthur Abeilice
 */
library EncryptionValidatorLight {
    /// @notice Minimum length required for encrypted data
    uint256 public constant MIN_ENCRYPTED_LENGTH = 40;

    /**
     * @notice Quick check if a message appears encrypted
     * @dev Uses sampling to drastically reduce gas costs
     * @param message The message string to verify
     * @return isValid Whether the message appears to be encrypted
     */
    function isEncryptedLight(string memory message) internal pure returns (bool isValid) {
        bytes memory data = bytes(message);

        // 1. Check minimum length
        if (data.length < MIN_ENCRYPTED_LENGTH) {
            return false;
        }

        // 2. Quick plain text check (only first bytes)
        if (isQuickPlainText(data)) {
            return false;
        }

        // 3. Simplified entropy check with sampling
        if (!hasBasicEntropy(data)) {
            return false;
        }

        return true;
    }

    /**
     * @dev Quick check if data appears to be plain text
     * @param data Byte array to analyze
     * @return true if appears to be plain text
     * @notice Only checks first 32 bytes for gas savings
     */
    function isQuickPlainText(bytes memory data) internal pure returns (bool) {
        uint256 printableCount = 0;
        uint256 spaceCount = 0;
        uint256 sampleSize = data.length > 32 ? 32 : data.length; // Only 32 bytes!

        for (uint256 i = 0; i < sampleSize; i++) {
            uint8 char = uint8(data[i]);

            if (char >= 32 && char <= 126) {
                printableCount++;
                if (char == 32) spaceCount++; // space
            }
        }

        // If >90% are readable characters AND there are spaces = probably text
        return (printableCount * 100 / sampleSize > 90) && (spaceCount > 0);
    }

    /**
     * @dev Basic entropy check with sampling
     * @param data Byte array to analyze
     * @return true if has sufficient entropy
     * @notice Uses sampling to significantly reduce gas
     */
    function hasBasicEntropy(bytes memory data) internal pure returns (bool) {
        if (data.length == 0) return false;

        // For small data, check all bytes
        if (data.length <= 64) {
            return hasFullEntropy(data);
        }

        // For large data, use sampling of only 64 bytes
        return hasSampledEntropy(data, 64);
    }

    /**
     * @dev Full entropy check for small data
     */
    function hasFullEntropy(bytes memory data) internal pure returns (bool) {
        uint256[256] memory frequency;

        for (uint256 i = 0; i < data.length; i++) {
            frequency[uint8(data[i])]++;
        }

        uint256 uniqueValues = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (frequency[i] > 0) {
                uniqueValues++;
            }
        }

        // For small data, needs at least 60% unique bytes
        return (uniqueValues * 100 / data.length) >= 60;
    }

    /**
     * @dev Sampled entropy check for large data
     */
    function hasSampledEntropy(bytes memory data, uint256 sampleSize) internal pure returns (bool) {
        uint256[256] memory frequency;

        // Uniformly distributed sampling
        for (uint256 i = 0; i < sampleSize; i++) {
            uint256 index = (i * data.length) / sampleSize;
            frequency[uint8(data[index])]++;
        }

        uint256 uniqueValues = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (frequency[i] > 0) {
                uniqueValues++;
            }
        }

        // For sampled data, expects at least 50% unique values
        return (uniqueValues * 100 / sampleSize) >= 50;
    }

    /**
     * @notice Test with detailed feedback (light version)
     */
    function testEncryptionLight(string memory message) internal pure returns (bool isValid, string memory reason) {
        bytes memory data = bytes(message);

        if (data.length < MIN_ENCRYPTED_LENGTH) {
            return (false, "Message too short");
        }

        if (isQuickPlainText(data)) {
            return (false, "Looks like plain text");
        }

        if (!hasBasicEntropy(data)) {
            return (false, "Low entropy - doesn't look encrypted");
        }

        return (true, "Looks encrypted");
    }
}
