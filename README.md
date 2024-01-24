# ETH Staking Contracts

## Addresses

### Ethereum Mainnet

Staking: `0xFB4022E94460ae7bd4d65EcD8214fbf574740494`

## Setup

```shell
forge install
cp .env.sample .env # and fill in values
```

### Tests

```shell
forge test # run all tests

make test-unit # only unit tests
make test-integration # only integration tests
```

### Deployment

```shell
source .env
forge script script/Staking.s.sol:Deploy --rpc-url $RPC_MAINNET --broadcast --verify # or $RPC_GOERLI

```
