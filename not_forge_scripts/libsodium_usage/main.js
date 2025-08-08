#!/usr/bin/env node

const sodium = require('libsodium-wrappers');
const { Command } = require('commander');
const fs = require('fs-extra');
const chalk = require('chalk');
const path = require('path');

// Initialize the CLI
const program = new Command();

program
  .name('libsodium-cli')
  .description('Simple CLI for encryption/decryption using libsodium')
  .version('1.0.0');

// Wait for sodium to be ready
async function initSodium() {
  await sodium.ready;
  return sodium;
}

// Generate keypair command
program
  .command('keygen')
  .description('Generate a new public/private keypair')
  .option('-o, --output <dir>', 'Output directory for keys', './keys')
  .action(async (options) => {
    try {
      const sodium = await initSodium();
      
      console.log(chalk.blue('🔑 Generating keypair...'));
      
      // Generate box keypair (for encryption/decryption)
      const keypair = sodium.crypto_box_keypair();
      
      // Convert to base64 for storage
      const publicKey = sodium.to_base64(keypair.publicKey);
      const privateKey = sodium.to_base64(keypair.privateKey);
      
      // Create output directory
      await fs.ensureDir(options.output);
      
      // Save keys to files
      const publicKeyPath = path.join(options.output, 'public_key.txt');
      const privateKeyPath = path.join(options.output, 'private_key.txt');
      
      await fs.writeFile(publicKeyPath, publicKey);
      await fs.writeFile(privateKeyPath, privateKey);
      
      console.log(chalk.green('✅ Keypair generated successfully!'));
      console.log(chalk.yellow(`📁 Keys saved to: ${options.output}`));
      console.log(chalk.gray(`   Public key:  ${publicKeyPath}`));
      console.log(chalk.gray(`   Private key: ${privateKeyPath}`));
      console.log('');
      console.log(chalk.cyan('📋 Public Key:'));
      console.log(publicKey);
      console.log('');
      console.log(chalk.cyan('🔐 Private Key:'));
      console.log(privateKey);
      
    } catch (error) {
      console.error(chalk.red('❌ Error generating keypair:'), error.message);
      process.exit(1);
    }
  });

// Encrypt command
program
  .command('encrypt')
  .description('Encrypt text using a public key')
  .requiredOption('-p, --public-key <key>', 'Public key (base64)')
  .requiredOption('-t, --text <text>', 'Text to encrypt')
  .option('-f, --public-key-file <file>', 'Read public key from file')
  .action(async (options) => {
    try {
      const sodium = await initSodium();
      
      console.log(chalk.blue('🔒 Encrypting message...'));
      
      // Get public key
      let publicKey;
      if (options.publicKeyFile) {
        const keyData = await fs.readFile(options.publicKeyFile, 'utf8');
        publicKey = sodium.from_base64(keyData.trim());
      } else {
        publicKey = sodium.from_base64(options.publicKey);
      }
      
      // Generate a random keypair for the sender (ephemeral)
      const senderKeypair = sodium.crypto_box_keypair();
      
      // Create nonce
      const nonce = sodium.randombytes_buf(sodium.crypto_box_NONCEBYTES);
      
      // Encrypt the message
      const plaintext = sodium.from_string(options.text);
      const ciphertext = sodium.crypto_box_easy(plaintext, nonce, publicKey, senderKeypair.privateKey);
      
      // Combine sender public key + nonce + ciphertext for the final encrypted message
      const encryptedMessage = {
        senderPublicKey: sodium.to_base64(senderKeypair.publicKey),
        nonce: sodium.to_base64(nonce),
        ciphertext: sodium.to_base64(ciphertext)
      };
      
      const encryptedString = JSON.stringify(encryptedMessage);
      const encryptedBase64 = Buffer.from(encryptedString).toString('base64');
      
      console.log(chalk.green('✅ Message encrypted successfully!'));
      console.log('');
      console.log(chalk.cyan('📝 Original text:'));
      console.log(options.text);
      console.log('');
      console.log(chalk.cyan('🔒 Encrypted message (base64):'));
      console.log(encryptedBase64);
      
    } catch (error) {
      console.error(chalk.red('❌ Error encrypting message:'), error.message);
      process.exit(1);
    }
  });

// Decrypt command
program
  .command('decrypt')
  .description('Decrypt text using a private key')
  .requiredOption('-k, --private-key <key>', 'Private key (base64)')
  .requiredOption('-t, --text <text>', 'Encrypted text to decrypt (base64)')
  .option('-f, --private-key-file <file>', 'Read private key from file')
  .action(async (options) => {
    try {
      const sodium = await initSodium();
      
      console.log(chalk.blue('🔓 Decrypting message...'));
      
      // Get private key
      let privateKey;
      if (options.privateKeyFile) {
        const keyData = await fs.readFile(options.privateKeyFile, 'utf8');
        privateKey = sodium.from_base64(keyData.trim());
      } else {
        privateKey = sodium.from_base64(options.privateKey);
      }
      
      // Parse encrypted message
      const encryptedString = Buffer.from(options.text, 'base64').toString();
      const encryptedMessage = JSON.parse(encryptedString);
      
      const senderPublicKey = sodium.from_base64(encryptedMessage.senderPublicKey);
      const nonce = sodium.from_base64(encryptedMessage.nonce);
      const ciphertext = sodium.from_base64(encryptedMessage.ciphertext);
      
      // Decrypt the message
      const decrypted = sodium.crypto_box_open_easy(ciphertext, nonce, senderPublicKey, privateKey);
      const plaintext = sodium.to_string(decrypted);
      
      console.log(chalk.green('✅ Message decrypted successfully!'));
      console.log('');
      console.log(chalk.cyan('🔓 Decrypted text:'));
      console.log(plaintext);
      
    } catch (error) {
      console.error(chalk.red('❌ Error decrypting message:'), error.message);
      console.error(chalk.red('   Make sure you have the correct private key and encrypted text'));
      process.exit(1);
    }
  });

// Help command
program
  .command('help')
  .description('Show detailed usage examples')
  .action(() => {
    console.log(chalk.bold.blue('🔐 LibSodium CLI Usage Examples'));
    console.log('');
    
    console.log(chalk.yellow('1. Generate a keypair:'));
    console.log(chalk.gray('   npm run keygen'));
    console.log(chalk.gray('   npm run keygen -- --output ./my-keys'));
    console.log('');
    
    console.log(chalk.yellow('2. Encrypt a message:'));
    console.log(chalk.gray('   npm run encrypt -- --public-key "BASE64_PUBLIC_KEY" --text "Hello World"'));
    console.log(chalk.gray('   npm run encrypt -- --public-key-file ./keys/public_key.txt --text "Secret message"'));
    console.log('');
    
    console.log(chalk.yellow('3. Decrypt a message:'));
    console.log(chalk.gray('   npm run decrypt -- --private-key "BASE64_PRIVATE_KEY" --text "BASE64_ENCRYPTED_TEXT"'));
    console.log(chalk.gray('   npm run decrypt -- --private-key-file ./keys/private_key.txt --text "BASE64_ENCRYPTED_TEXT"'));
    console.log('');
    
    console.log(chalk.yellow('Full workflow example:'));
    console.log(chalk.gray('   1. npm run keygen'));
    console.log(chalk.gray('   2. npm run encrypt -- --public-key-file ./keys/public_key.txt --text "My secret"'));
    console.log(chalk.gray('   3. npm run decrypt -- --private-key-file ./keys/private_key.txt --text "ENCRYPTED_OUTPUT_FROM_STEP_2"'));
    console.log('');
    
    console.log(chalk.green('Note: Use -- before options when running with npm run'));
  });

// Parse command line arguments
program.parse(process.argv);

// Show help if no command provided
if (!process.argv.slice(2).length) {
  program.outputHelp();
}