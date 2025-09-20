# Land Registry - Decentralized Land Ownership Proof 🗂️ Terra

A comprehensive blockchain-based land registry system built on Stacks blockchain using Clarity smart contracts. This system provides decentralized, immutable, and transparent proof of land ownership with transfer capabilities.

## Overview

The Land Registry system consists of two main smart contracts that work together to manage land ownership and transfers:

1. **Land Ownership Contract** - Manages property records, ownership validation, and property registration
2. **Land Transfer Contract** - Handles secure property transfers, ownership validation, and transfer history

## Features

### Land Ownership Management
- **Property Registration**: Register new properties with detailed metadata
- **Ownership Verification**: Verify current ownership of any property
- **Property Information**: Access comprehensive property details including location, size, and value
- **Owner History**: Track complete ownership history for transparency

### Secure Land Transfers
- **Transfer Initiation**: Property owners can initiate transfers to new owners
- **Transfer Validation**: Automatic validation of ownership before transfers
- **Transfer Completion**: Secure transfer completion with automatic ownership updates
- **Transfer History**: Complete audit trail of all property transfers

## Smart Contract Architecture

### Data Structures
- **Property Records**: Immutable property information with metadata
- **Ownership Mapping**: Current ownership tracking
- **Transfer Records**: Historical transfer data
- **Property Valuations**: Current and historical property values

### Security Features
- **Ownership Validation**: Only property owners can initiate transfers
- **Transfer Authorization**: Secure authorization mechanisms
- **Immutable Records**: Blockchain-based immutable property records
- **Fraud Prevention**: Built-in mechanisms to prevent fraudulent transfers

## Technical Stack

- **Blockchain**: Stacks Blockchain
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Clarinet Test Framework

## Getting Started

### Prerequisites
- Clarinet installed
- Node.js and npm
- Stacks wallet for testnet interactions

### Installation
```bash
git clone <repository-url>
cd land-registry
npm install
```

### Testing
```bash
clarinet check
npm test
```

### Deployment
Deploy to Stacks testnet or mainnet using Clarinet deployment tools.

## Contract Interactions

### Registering a Property
Properties can be registered with complete metadata including location, size, value, and ownership information.

### Transferring Ownership
Property owners can initiate transfers that are securely processed and recorded on the blockchain.

### Verifying Ownership
Anyone can verify the current ownership status of any property using the public functions.

## Security Considerations

- All ownership changes are immutably recorded
- Transfer validation prevents unauthorized ownership changes  
- Property registration includes comprehensive metadata validation
- Built-in fraud prevention mechanisms

## Contributing

This is a demonstration project showcasing blockchain-based land registry capabilities. The system provides a foundation for real-world land registry applications with appropriate legal and regulatory frameworks.

## License

This project is for educational and demonstration purposes.
