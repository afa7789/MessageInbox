#!/bin/bash

# Script to run EncryptionValidator tests
echo "🧪 Running EncryptionValidator Tests..."

# Compile contracts
echo "📦 Building contracts..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Run specific library tests
echo "🔍 Running EncryptionValidator tests..."
forge test --match-contract EncryptionValidatorTest -vvv

echo ""
echo "📊 Running tests with gas reporting..."
forge test --match-contract EncryptionValidatorTest --gas-report

echo ""
echo "🎯 Running fuzz tests (longer)..."
forge test --match-contract EncryptionValidatorTest --match-test testFuzz -vvv

echo ""
echo "✨ All tests completed!"
