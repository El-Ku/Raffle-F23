# Foundry Fund Me

- [Foundry Fund Me](#foundry-fund-me)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)
- [Thank you!](#thank-you)



# Getting Started

This contract allows users(buyers or players) to buy a ticket from the contract. And after the raffle interval is over, a winner will be drawn at random and all the ticket prices accumulated during that raffle interval will go to that particular winner. A user can buy more than one ticket, but by calling the the buyTicket function repeatedly.

This project was done as part of the Foundry 2023 course by [Patrick Collins](https://twitter.com/PatrickAlphaC). So the repo is very similar to [his](https://github.com/Cyfrin/foundry-smart-contract-lottery-f23). Though I have skipped some steps, and I still have a TODO list to complete it fully.

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`


## Quickstart

```
git clone https://github.com/El-Ku/Raffle-F23
cd Raffle-F23
forge build
```

# Usage

Deploy:

```
forge script script/DeployRaffle.s.sol
```

## Testing

```bash
# Test everything without any log messages
forge test

# Test everything with emitted events and console messages
forge test -vv

# Test everything with information printed out on each individual transaction
forge test -vvvv
```

or 

```bash
# Only run test functions matching the specified regex pattern.
forge test --match-test testFunctionName
# (OR)
forge test --mt testFunctionName

```

or

```bash
# Test on forked version of the specified network
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
forge coverage
```


# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. 

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

2. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some tesnet ETH. You should see the ETH show up in your metamask.

3. Deploy

```
forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see and output file called `.gas-snapshot`


# Formatting


To run code formatting:
```
forge fmt
```


# Thank you!

[My Twitter - ElKu](https://twitter.com/ElKu_crypto)
