# LibSodium CLI

A simple command-line interface for encryption and decryption using the libsodium library. This CLI provides secure public-key cryptography with easy-to-use commands for generating keypairs, encrypting messages, and decrypting them.

## Installation

```bash
# Install dependencies
npm install
```

## Using it

### 1. Generate a Keypair

```bash
# Generate keys in the default ./keys directory
npm run keygen

# Generate keys in a custom directory
npm run keygen -- --output ./my-keys
node ./not_forge_scripts/libsodium_usage/main.js keygen
```

This creates two files:
- `public_key.txt` - Share this with others to receive encrypted messages
- `private_key.txt` - Keep this secret for decrypting messages

### 2. Encrypt a Message

```bash
# Using public key directly
npm run encrypt -- --public-key "BASE64_PUBLIC_KEY" --text "Hello World"

# Using public key from file
npm run encrypt -- --public-key-file ./keys/public_key.txt --text "Secret message"
```

### 3. Decrypt a Message

```bash
# Using private key directly
npm run decrypt -- --private-key "BASE64_PRIVATE_KEY" --text "BASE64_ENCRYPTED_TEXT"

# Using private key from file
npm run decrypt -- --private-key-file ./keys/private_key.txt --text "BASE64_ENCRYPTED_TEXT"
```

## Complete Workflow Example

Here's a complete example from start to finish:

```bash
# Step 1: Generate a keypair
npm run keygen
# Output: Keys saved to ./keys/public_key.txt and ./keys/private_key.txt

# Step 2: Encrypt a message
npm run encrypt -- --public-key-file ./keys/public_key.txt --text "This is my secret message"
# Output: Returns a base64 encoded encrypted message

# Step 3: Decrypt the message (copy the encrypted output from step 2)
npm run decrypt -- --private-key-file ./keys/private_key.txt --text "eyJzZW5kZXJQdWJsaWNLZXkiOiJ..."
# Output: "This is my secret message"
```
