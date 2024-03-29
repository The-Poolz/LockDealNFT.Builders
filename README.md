# LockDealNFT.Builders

[![Build and Test](https://github.com/The-Poolz/LockDealNFT.Builders/actions/workflows/node.js.yml/badge.svg)](https://github.com/The-Poolz/LockDealNFT.Builders/actions/workflows/node.js.yml)
[![codecov](https://codecov.io/gh/The-Poolz/LockDealNFT.Builders/branch/master/graph/badge.svg)](https://codecov.io/gh/The-Poolz/LockDealNFT.Builders)
[![CodeFactor](https://www.codefactor.io/repository/github/the-poolz/LockDealNFT.Builders/badge)](https://www.codefactor.io/repository/github/the-poolz/LockDealNFT.Builders)
[![npm version](https://img.shields.io/npm/v/@poolzfinance/builders/latest.svg)](https://www.npmjs.com/package/@poolzfinance/builders/v/latest)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/The-Poolz/LockDealNFT.Builders/blob/master/LICENSE)

**Builders** are **Solidity** smart contracts designed to **mass-create NFTs** using the [LockDealNFT](https://github.com/The-Poolz/LockDealNFT) system.

### Navigation

-   [Installation](#installation)
-   [Simple Builder](https://github.com/The-Poolz/LockDealNFT.Builders/tree/master/contracts/SimpleBuilder#simplebuilder)
-   [Simple Refund Builder](https://github.com/The-Poolz/LockDealNFT.Builders/tree/master/contracts/SimpleRefundBuilder#simplerefundbuilder)
-   [License](#license)

## Installation

**Install the packages:**

```console
npm i
```

```console
yarn
```

**Compile contracts:**

```console
npx hardhat compile
```

**Run tests:**

```console
npx hardhat test
```

**Run coverage:**

```console
npx hardhat coverage
```

**Deploy:**

```console
npx truffle dashboard
```

```console
npx hardhat run ./scripts/deploySimpleBuilder.ts --network truffleDashboard
```

```console
npx hardhat run ./scripts/deploySimpleRefundBuilder.ts --network truffleDashboard
```

## License

[The-Poolz](https://poolz.finance/) Contracts is released under the [MIT License](https://github.com/The-Poolz/LockDealNFT.Builders/blob/master/LICENSE).
