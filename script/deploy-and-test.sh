#!/bin/bash
source .env
# Deploy and Test Orchestrator Script
# This script coordinates the deployment and testing workflow

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if required environment variables are set
check_environment() {
    print_step "Checking Environment"
    
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable is required"
        echo "Usage: PRIVATE_KEY=0x... RPC_URL=http://... ./deploy-and-test.sh"
        exit 1
    fi
    
    if [ -z "$RPC_URL" ]; then
        print_warning "RPC_URL not set, using default: http://localhost:8545"
        export RPC_URL="http://localhost:8545"
    fi
    
    print_success "Environment variables validated"
    echo "RPC URL: $RPC_URL"
    echo "Contract Type: ${CONTRACT_TYPE:-unsafe}"
    echo ""
}

# Deploy the contract using DeployInbox.s.sol
deploy_contract() {
    print_step "Deploying Contract"
    
    echo "Running DeployInbox.s.sol script..."
    
    if forge script script/DeployInbox.s.sol:DeployInboxScript \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast \
        --ffi \
        --via-ir; then
        
        print_success "Contract deployment completed"
        
        # Check if deployment JSON was created
        if [ -f "deployments/latest-deployment.json" ]; then
            print_success "Deployment JSON file created successfully"
            
            # Extract and display key info
            CONTRACT_ADDRESS=$(grep contractAddress deployments/latest-deployment.json | cut -d'"' -f4)
            CONTRACT_TYPE=$(grep contractType deployments/latest-deployment.json | cut -d'"' -f4)
            
            echo "Contract Address: $CONTRACT_ADDRESS"
            echo "Contract Type: $CONTRACT_TYPE"
        else
            print_warning "Deployment JSON not found, but deployment may have succeeded"
        fi
    else
        print_error "Contract deployment failed"
        exit 1
    fi
    
    echo ""
}

# Run tests using TestInbox.s.sol
run_tests() {
    print_step "Running Tests"
    
    echo "Running TestInbox.s.sol script..."
    
    if forge script script/TestInbox.s.sol:TestInboxScript \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast \
        --ffi; then
        print_success "All tests completed successfully"
    else
        print_error "Tests failed"
        exit 1
    fi
    
    echo ""
}

# Clean up function
cleanup() {
    print_step "Cleanup"
    
    # Optional: Clean up temporary files
    if [ -f "not_forge_scripts/libsodium_usage/test-encrypted.txt" ]; then
        rm -f not_forge_scripts/libsodium_usage/test-encrypted.txt
        print_success "Cleaned up temporary files"
    fi
}

# Main execution flow
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║        Deploy and Test Workflow        ║"
    echo "║           Forge Orchestrator           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check if we're in the right directory
    if [ ! -f "foundry.toml" ]; then
        print_error "foundry.toml not found. Please run this script from the project root."
        exit 1
    fi
    
    # Execute workflow steps
    check_environment
    deploy_contract
    run_tests
    cleanup
    
    print_step "Workflow Complete"
    print_success "🎉 Deploy and test workflow completed successfully!"
    
    if [ -f "deployments/latest-deployment.json" ]; then
        echo ""
        echo "📄 Deployment details saved in: deployments/latest-deployment.json"
        echo "🔍 Use this file to interact with your deployed contract"
    fi
}

# Help function
show_help() {
    echo "Deploy and Test Orchestrator"
    echo ""
    echo "Usage:"
    echo "  PRIVATE_KEY=0x... RPC_URL=http://... ./deploy-and-test.sh"
    echo ""
    echo "Environment Variables:"
    echo "  PRIVATE_KEY        (required) Private key for deployment"
    echo "  RPC_URL           (optional) RPC endpoint (default: http://localhost:8545)"
    echo "  CONTRACT_TYPE     (optional) Contract type: unsafe/light/full (default: unsafe)"
    echo "  ENCRYPT_PUBLIC_KEY (optional) Encryption public key"
    echo ""
    echo "Examples:"
    echo "  # Local deployment"
    echo "  PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ./deploy-and-test.sh"
    echo ""
    echo "  # Testnet deployment"
    echo "  PRIVATE_KEY=0x... RPC_URL=https://sepolia.infura.io/v3/... CONTRACT_TYPE=light ./deploy-and-test.sh"
}

# Handle command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Run main function
main "$@"