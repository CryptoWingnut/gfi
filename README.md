CAKE APE Token Guide
====================

## DEPLOYING ##

constructor (address _dexRouter, address _cake, address _treasury, address _lpstore)

When deploying the contract you need to provide the DEX router, the addresses for the CAKE token, treasury, and the LP storage wallet


## MANAGING ##

function setDex(address _dexRouter)

Call this function if you want to change the DEX router that the buyback of CAKE is performed through


function setLPStore(address _lpstore)

Call this function if you want to change the address the CAKE/APE is sent to from liquidity tax


function setTreasury(address _treasury)

Call this function if you want to change the address the CAKE is sent to from the marketing tax


function setTransferTaxEnabled(bool _enabled)

Call this function if you want to enable/disable the transfer taxes for everybody


function excludeFromFee(address _account)

function includeInFee(address _account)

Call these functions if you want to exclude an address from paying transfer taxes, or to include on back in that has been excluded
** Needs to be done for the swapper contract address once it is deployed **


function setTaxFeePercent(uint256 _taxFee)

function setLiquidityFeePercent(uint256 _liquidityFee)

function setMarketingTax(uint256 _marketingTax)

Call one of these functions to change one of the tax rates. Please note there is 1 decimal of precision so entry would be like:
10 = 1.0%
15 = 1.5%
6 = 0.6%


function setMaxTxPercent(uint256 _maxTxPercent)

Call this function if you want to change the maximum transfer size per transaction


function excludeFromReward(address _account)

function includeInReward(address _account)

Call one of these functions if you want to exclude an address from receiving reflections, or to include one back in that has been removed




G-FI to APE Swapper Contract
============================

## DEPLOYING ##

constructor(address _ape, address _gfi, address _treasury)

When deploying the contract you need to provide the addresses for the CAKE APE token, the G-FI token, and the treasury wallet where you want the G-FI that is send to be transferred to


## MANAGING ##

function recoverApe()

You can call this function from the deployer if you need to recover the CAKE APE tokens that were sent to it back to the treasury


function swap(uint256 _amount)

This is the function that is used by the front end to perform the swap. It provides the amount of G-FI tokens that should be converted, and there must also be the usual approval on the G-FI token for the contract to spend that amount already transacted.
