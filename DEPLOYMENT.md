# MessageInbox Deployment Guide

This project provides three different MessageInbox contract variants with different security/gas trade-offs:

## Contract Variants

1. **MessageInbox** (`unsafe`) - No validation, accepts any message
   - ✅ Lowest gas cost
   - ❌ No security (accepts plain text)
   - Use case: Testing, development

2. **EncryptedMessageInboxLight** (`light`) - Light encryption validation  
   - ⚖️ Balanced gas cost and security
   - ✅ Basic encryption validation
   - Use case: Production with gas optimization

3. **EncryptedMessageInbox** (`full`) - Full encryption validation
   - ✅ Highest security
   - ❌ Highest gas cost  
   - Use case: Production requiring maximum security

## Setup

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Fill in your values in `.env`:
   ```bash
   # Your deployment private key
   PRIVATE_KEY=your_private_key_here
   
   # Network RPC URLs
   SEPOLIA_RPC=https://sepolia.infura.io/v3/your_infura_key
   
   # Your PGP public key
   PGP_PUBLIC_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----
   mQENBGH...your_real_pgp_key_here...
   -----END PGP PUBLIC KEY BLOCK-----"
   ```

## Deployment Options

### Option 1: Universal Deploy Script (Recommended)

Deploy any contract type with a single script:

```bash
# Deploy unsafe version (no validation)
CONTRACT_TYPE=unsafe forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy light version (balanced)
CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast

# Deploy full version (most secure) - default
forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
```

### Option 2: Individual Deploy Scripts

```bash
# MessageInbox (unsafe)
forge script script/MessageInbox.s.sol:MessageInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast

# EncryptedMessageInboxLight  
forge script script/LightEncryptedMessageInbox.s.sol:LightEncryptedMessageInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast

# EncryptedMessageInbox (full)
forge script script/EncryptedMessageInbox.s.sol:EncryptedMessageInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
```

## Custom Public Key

### Method 1: Environment Variable

Set in your `.env` file:
```bash
PGP_PUBLIC_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----
your_actual_pgp_public_key_here
-----END PGP PUBLIC KEY BLOCK-----"
```

### Method 2: Inline Environment Variable

```bash
PGP_PUBLIC_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----..." forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast
```

## Simulation (No Broadcast)

Test your deployment without actually deploying:

```bash
# Simulate deployment
CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript

# Simulate with custom key
PGP_PUBLIC_KEY="your_key" CONTRACT_TYPE=full forge script script/DeployInbox.s.sol:DeployInboxScript
```

## Network Examples

### Local Development (Anvil)
```bash
# Start anvil in another terminal
anvil

# Deploy to local network
CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### Testnet (Sepolia)
```bash
CONTRACT_TYPE=full forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Mainnet
```bash
CONTRACT_TYPE=light forge script script/DeployInbox.s.sol:DeployInboxScript --rpc-url $MAINNET_RPC --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Gas Cost Comparison

Based on tests, approximate gas costs for `setMessage`:

- **MessageInbox**: ~50k gas
- **EncryptedMessageInboxLight**: ~120k gas  
- **EncryptedMessageInbox**: ~180k gas

Choose based on your security requirements and gas budget.
