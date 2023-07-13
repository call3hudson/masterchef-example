# Masterchef Example

This project demonstrates a basic masterchef example.

```shell
1. Create Sushi token which is mintable by master chef contract
2. Create SushiLP token which has static supply.
3. Create Master Chef contract
- Users can stake Sushi or SushiLP token to get reward
- Master chef contract mints 10 Sushi per block and distribute it to Sushi and SushiLp stakers.
- There is allocation point between Sushi and SushiLP. It determines how much reward give per each block for Sushi and SushiLP.
- There are deposit, withdraw, claim functions.
When, deposit, and withdraw, users can get reward automatically.
```

Try running some of the following tasks:

```shell
npx hardhat test
npx hardhat coverage
```
