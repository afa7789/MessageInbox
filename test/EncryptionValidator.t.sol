// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EncryptionValidator.sol";
import "../src/EncryptionValidatorLight.sol";

contract EncryptionValidatorTest is Test {
    using EncryptionValidator for string;
    using EncryptionValidatorLight for string;

    function setUp() public {
        // Setup if needed
    }

    // Helper function to generate truly random-looking data
    function generateRandomBytes(uint256 length, uint256 seed) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i))) % 256));
        }
        return result;
    }

    // Test basic isEncrypted functionality
    function testIsEncrypted_ValidEncryptedData() public pure {
        // Generate truly high-entropy data
        bytes memory encryptedData = generateRandomBytes(72, 12345);
        string memory testData = string(encryptedData);

        assertTrue(testData.isEncrypted(), "Should detect as encrypted");
    }

    function testIsEncrypted_PlainTextRejected() public pure {
        string memory plainText = "This is a simple plain text message that should be rejected";

        assertFalse(plainText.isEncrypted(), "Should reject plain text");
    }

    function testIsEncrypted_TooShort() public pure {
        string memory shortData = "short";

        assertFalse(shortData.isEncrypted(), "Should reject data shorter than MIN_ENCRYPTED_LENGTH");
    }

    function testIsEncrypted_MinimumLength() public pure {
        // Create data exactly at minimum length (40 bytes) with high entropy
        bytes memory data = generateRandomBytes(40, 54321);
        string memory testData = string(data);

        assertTrue(testData.isEncrypted(), "Should accept data at minimum length with high entropy");
    }

    // Test testEncryption function with detailed feedback
    function testTestEncryption_ValidData() public pure {
        // High entropy data using improved generator
        bytes memory encryptedData = generateRandomBytes(72, 98765);
        string memory testData = string(encryptedData);

        (bool isValid, string memory reason) = EncryptionValidator.testEncryption(testData);

        assertTrue(isValid, "Should be valid");
        assertEq(reason, "Looks encrypted", "Should return correct reason");
    }

    function testTestEncryption_TooShort() public pure {
        string memory shortData = "short";

        (bool isValid, string memory reason) = EncryptionValidator.testEncryption(shortData);

        assertFalse(isValid, "Should be invalid");
        assertEq(reason, "Message too short", "Should return correct reason");
    }

    function testTestEncryption_PlainText() public pure {
        string memory plainText = "This is clearly a plain text message with spaces and readable content";

        (bool isValid, string memory reason) = EncryptionValidator.testEncryption(plainText);

        assertFalse(isValid, "Should be invalid");
        assertEq(reason, "Looks like plain text", "Should return correct reason");
    }

    function testTestEncryption_LowEntropy() public pure {
        // Create data with low entropy (repeated pattern)
        bytes memory lowEntropyData = new bytes(50);
        for (uint256 i = 0; i < 50; i++) {
            lowEntropyData[i] = bytes1(uint8(65)); // All 'A' characters
        }
        string memory testData = string(lowEntropyData);

        (bool isValid, string memory reason) = EncryptionValidator.testEncryption(testData);

        assertFalse(isValid, "Should be invalid");
        assertEq(reason, "Low entropy - doesn't look encrypted", "Should return correct reason");
    }

    // Test isProbablyPlainText internal logic
    function testIsProbablyPlainText_DetectsPlainText() public pure {
        string memory plainText = "Hello world, this is a normal sentence with spaces and punctuation!";

        // We can't call internal functions directly, so test through isEncrypted
        assertFalse(plainText.isEncrypted(), "Plain text should be detected");
    }

    function testIsProbablyPlainText_IgnoresHighEntropy() public pure {
        // Generate truly random data that doesn't look like plain text
        bytes memory randomData = generateRandomBytes(64, 11111);
        string memory testData = string(randomData);

        assertTrue(testData.isEncrypted(), "Random data should pass");
    }

    // Test hasHighEntropy internal logic
    function testHasHighEntropy_RejectsLowEntropy() public pure {
        // Create data with very low entropy (all same byte)
        bytes memory lowEntropyData = new bytes(100);
        for (uint256 i = 0; i < 100; i++) {
            lowEntropyData[i] = bytes1(uint8(255)); // All same byte
        }
        string memory testData = string(lowEntropyData);

        assertFalse(testData.isEncrypted(), "Low entropy data should be rejected");
    }

    function testHasHighEntropy_AcceptsHighEntropy() public pure {
        // Create data with high entropy using improved generator
        bytes memory highEntropyData = generateRandomBytes(100, 22222);
        string memory testData = string(highEntropyData);

        assertTrue(testData.isEncrypted(), "High entropy data should be accepted");
    }

    // Edge cases
    function testEdgeCase_EmptyString() public pure {
        string memory empty = "";

        assertFalse(empty.isEncrypted(), "Empty string should be rejected");
    }

    function testEdgeCase_ExactlyMinLength() public pure {
        // Create exactly 40 bytes of high entropy data
        bytes memory data = generateRandomBytes(EncryptionValidator.MIN_ENCRYPTED_LENGTH, 33333);
        string memory testData = string(data);

        assertTrue(testData.isEncrypted(), "Data at exact minimum length should pass if high entropy");
    }

    function testEdgeCase_JustBelowMinLength() public pure {
        // Create 39 bytes (just below minimum)
        bytes memory data = generateRandomBytes(EncryptionValidator.MIN_ENCRYPTED_LENGTH - 1, 44444);
        string memory testData = string(data);

        assertFalse(testData.isEncrypted(), "Data below minimum length should be rejected");
    }

    // Fuzz testing
    function testFuzz_RandomData(bytes memory randomBytes) public pure {
        vm.assume(randomBytes.length >= EncryptionValidator.MIN_ENCRYPTED_LENGTH);
        vm.assume(randomBytes.length <= 1000); // Reasonable upper bound

        string memory testData = string(randomBytes);

        // The result can be either true or false, but shouldn't revert
        // This tests that the function handles all possible input gracefully
        bool result = testData.isEncrypted();

        // If it's detected as encrypted, testEncryption should also say it's valid
        if (result) {
            (bool isValid,) = EncryptionValidator.testEncryption(testData);
            assertTrue(isValid, "If isEncrypted returns true, testEncryption should also return true");
        }
    }

    function testFuzz_PlainTextAlwaysRejected(uint256 seed) public pure {
        // Generate structured plain text instead of assuming random strings are plain text
        string memory plainText = generatePlainText(seed);
        vm.assume(bytes(plainText).length >= EncryptionValidator.MIN_ENCRYPTED_LENGTH);

        assertFalse(plainText.isEncrypted(), "Generated plain text should always be rejected");
    }

    // Helper function to generate realistic plain text
    function generatePlainText(uint256 seed) internal pure returns (string memory) {
        uint256 length = 50 + (seed % 100); // 50-149 characters
        bytes memory text = new bytes(length);

        for (uint256 i = 0; i < length; i++) {
            uint256 charSeed = uint256(keccak256(abi.encode(seed, i)));
            uint8 char;

            if (charSeed % 6 == 0) {
                char = 32; // Space (common in plain text)
            } else if (charSeed % 3 == 0) {
                char = uint8(97 + (charSeed % 26)); // lowercase a-z
            } else {
                char = uint8(65 + (charSeed % 26)); // uppercase A-Z
            }

            text[i] = bytes1(char);
        }

        return string(text);
    }

    // Test constants
    function testConstants() public pure {
        assertEq(EncryptionValidator.MIN_ENCRYPTED_LENGTH, 40, "MIN_ENCRYPTED_LENGTH should be 40");
        assertEq(EncryptionValidator.MIN_ENTROPY_THRESHOLD, 60, "MIN_ENTROPY_THRESHOLD should be 60");
    }

    // Performance test (optimized)
    function testPerformance_LargeData() public {
        // Test with larger data to ensure reasonable gas usage
        bytes memory largeData = generateRandomBytes(500, 55555); // Reduced size for better gas usage
        string memory testData = string(largeData);

        uint256 gasBefore = gasleft();
        bool result = testData.isEncrypted();
        uint256 gasUsed = gasBefore - gasleft();

        // Should complete without running out of gas
        assertTrue(result, "Large high-entropy data should be detected as encrypted");

        // Log gas usage for reference (should be reasonable)
        emit log_named_uint("Gas used for 500-byte validation", gasUsed);

        // Adjusted gas check - entropy calculation for 500 bytes requires more gas
        // This includes one pass through data (500 iterations) + frequency analysis (256 iterations)
        assertLt(gasUsed, 200000, "Gas usage should be reasonable for large data");
    }

    // Test gas usage for different data sizes
    function testGasCosts_DifferentSizes() public {
        // Test realistic message sizes
        uint256[] memory sizes = new uint256[](5);
        sizes[0] = 50; // Small message
        sizes[1] = 100; // Medium message
        sizes[2] = 200; // Large message
        sizes[3] = 500; // Very large message
        sizes[4] = 1000; // Huge message

        for (uint256 i = 0; i < sizes.length; i++) {
            bytes memory data = generateRandomBytes(sizes[i], 12345 + i);
            string memory testData = string(data);

            uint256 gasBefore = gasleft();
            bool result = testData.isEncrypted();
            uint256 gasUsed = gasBefore - gasleft();

            assertTrue(result, "Should detect as encrypted");

            // Detailed cost logging
            emit log_named_uint("Bytes", sizes[i]);
            emit log_named_uint("Gas used", gasUsed);
            emit log_named_uint("Gas per byte", gasUsed / sizes[i]);
            emit log_string("---");
        }
    }

    // Comparação de performance: Versão completa vs Light
    function testGasComparison_FullVsLight() public {
        bytes memory testData = generateRandomBytes(500, 99999);
        string memory message = string(testData);

        // Teste versão completa
        uint256 gasBefore = gasleft();
        bool resultFull = message.isEncrypted();
        uint256 gasFullVersion = gasBefore - gasleft();

        // Teste versão light
        gasBefore = gasleft();
        bool resultLight = EncryptionValidatorLight.isEncryptedLight(message);
        uint256 gasLightVersion = gasBefore - gasleft();

        // Ambos devem dar o mesmo resultado para dados aleatórios
        assertEq(resultFull, resultLight, "Both versions should agree on random data");

        // Log comparison
        emit log_string("=== GAS COMPARISON ===");
        emit log_named_uint("FULL version (500 bytes)", gasFullVersion);
        emit log_named_uint("LIGHT version (500 bytes)", gasLightVersion);
        emit log_named_uint("Gas savings", gasFullVersion - gasLightVersion);
        emit log_named_uint("Percentage reduction", ((gasFullVersion - gasLightVersion) * 100) / gasFullVersion);

        // A versão light deve usar significativamente menos gas
        assertLt(gasLightVersion, gasFullVersion / 2, "Light version should use less than half the gas");
    }

    // Test gas costs for small messages (real world usage)
    function testRealWorldGasCosts() public {
        // Typical PGP message sizes
        uint256[] memory sizes = new uint256[](3);
        sizes[0] = 80; // Typical small message
        sizes[1] = 150; // Typical medium message
        sizes[2] = 300; // Typical large message

        emit log_string("=== REAL WORLD GAS COSTS ===");

        for (uint256 i = 0; i < sizes.length; i++) {
            bytes memory data = generateRandomBytes(sizes[i], 11111 + i);
            string memory message = string(data);

            // Full version
            uint256 gasBefore = gasleft();
            bool resultFull = message.isEncrypted();
            uint256 gasFull = gasBefore - gasleft();

            // Light version
            gasBefore = gasleft();
            bool resultLight = EncryptionValidatorLight.isEncryptedLight(message);
            uint256 gasLight = gasBefore - gasleft();

            assertTrue(resultFull && resultLight, "Both should detect encryption");

            emit log_named_uint("Size (bytes)", sizes[i]);
            emit log_named_uint("Gas FULL", gasFull);
            emit log_named_uint("Gas LIGHT", gasLight);
            emit log_named_uint("Savings", gasFull - gasLight);
            emit log_string("---");
        }
    }

    // Test different entropy scenarios
    function testEntropy_ShortVsLongData() public pure {
        // Short data (40 bytes) - needs high percentage of unique bytes
        bytes memory shortData = generateRandomBytes(40, 66666);
        string memory shortTest = string(shortData);
        assertTrue(shortTest.isEncrypted(), "Short random data should pass");

        // Long data (300 bytes) - needs good byte variety
        bytes memory longData = generateRandomBytes(300, 77777);
        string memory longTest = string(longData);
        assertTrue(longTest.isEncrypted(), "Long random data should pass");
    }

    // Test boundary conditions for entropy
    function testEntropy_BoundaryConditions() public pure {
        // Test data with exactly 60% entropy (should pass)
        bytes memory boundaryData = new bytes(100);

        // Fill with 60 different byte values (60% entropy)
        for (uint256 i = 0; i < 60; i++) {
            boundaryData[i] = bytes1(uint8(i));
        }
        // Fill remaining with the first byte value
        for (uint256 i = 60; i < 100; i++) {
            boundaryData[i] = bytes1(uint8(0));
        }

        string memory testData = string(boundaryData);
        bool result = testData.isEncrypted();

        // This should pass the entropy test (exactly at threshold)
        assertTrue(result, "Data with exactly 60% entropy should pass");
    }
}
