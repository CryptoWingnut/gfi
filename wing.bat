:: Wingnut's "Because I'm Too Lazy To Keep Typing Commands" Batch File
:: Feel free to add to this and be lazy too!

@echo off
CLS

IF "%1"=="ganache" (
    ganache-cli -f https://data-seed-prebsc-1-s1.binance.org:8545/
) ELSE IF "%1"=="test" (
    truffle test .\test\%2.js --network develop
) ELSE IF "%1"=="migrate" (
    truffle migrate --f %2 --to %2 --network testnet --compile-all
) ELSE IF "%1"=="deploy" (
    truffle migrate --f %2 --to %2 --network bsc --compile-all
) ELSE (
    ECHO Usage
    ECHO -----
    ECHO ./wing ganache         - Starts ganache-cli and forks the BSC testnet
    ECHO ./wing test XXX        - Executes a truffle test against the provided filename *do not include the .js*
    ECHO ./wing migrate XXX     - Executes a truffle migrate script with the provided number on the BSC testnet
    ECHO ./wing deploy XXX      - Executes a truffle migrate script with the provided number on the BSC mainnet
)