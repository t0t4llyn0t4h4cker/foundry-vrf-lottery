# Proveably Random Raffle Contracts

## About

This code is to create a proveable random smart contract lottery.

## What we want it to do?

1. Allow users to enter the lottery by sending ether to the contract
   1. Ticket fees go to winner during draw
2. After X period of time, lottery automatically draws a winner
   1. all done programatically (no human intervention)
3. Using Chainlink VRF & Chainlink Automation
   1. Chainlink VRF to generate a random number
   2. Chainlink Automation to time base trigger the draw

## ! Notice !

ATM requires manually Upkeep (automation job) to be created on the Chainlink node.
Scripted: Deploy Raffle, Test Raffle, Create/Fund Chainlink Subscriptions, addConsumer for Chainlink Subscriptions

## Test!

1. Write some deploy scripts
2. Write our tests
   1. Works on local chain (anvil)
   2. on forked testnet
   3. on forked mainnet
