const { assert } = require('chai');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { time } = require('@openzeppelin/test-helpers');

require('chai').use(require('chai-as-promised')).should();

const GFi = artifacts.require('GorillaFi');
const Cake = artifacts.require('FakeCake');
const DexRouter = artifacts.require('IUniswapV2Router02');
const DexFactory = artifacts.require('IUniswapV2Factory');
const IERC20 = artifacts.require('IERC20');

const DEXROUTER = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';

function tokens(n) {
    return web3.utils.toWei(n, 'Ether');
}

contract('G-Fi Token', ([ deployer, user1, user2 ]) => {
    let gfi, cake, dexrouter, dexfactory, gfi_pair, cake_pair;
    let user1_gfi, user2_gfi, treasury_gfi;
    let result, temp;
    let transactionCount1 = 0, transactionCount2 = 0, transactionCount3 = 0;
    let BN = web3.utils.BN;

    async function nonce(account) {
        if (account == deployer) {
            transactionCount1 += 1;
            return await web3.eth.getTransactionCount(await deployer, 'pending') + (transactionCount1 - 1);
        } else if (account == user1) {
            transactionCount2 += 1;
            return await web3.eth.getTransactionCount(await user1, 'pending') + (transactionCount2 - 1);
        } else {
            transactionCount3 += 1;
            return await web3.eth.getTransactionCount(await user2, 'pending') + (transactionCount2 - 1);
        }
    }

    async function updateBalances() {
        result = await gfi.balanceOf(user1);
        user1_gfi = new BN(result.toString());
        result = await gfi.balanceOf(user2);
        user2_gfi = new BN(result.toString());  
        result = await gfi.balanceOf(deployer);
        treasury_gfi = new BN(result.toString()); 
    }

    async function printBalances() {
        console.log("User 1   : " + user1_gfi.toString());
        console.log("User 2   : " + user2_gfi.toString());
        console.log("Treasury : " + treasury_gfi.toString());
    }

    describe('G-Fi Token Test Script', async() => {
        describe('Test Environment Setup', async() => {
            it('1. Deploy fake CAKE token', async() => {       
                cake = await Cake.new({ nonce: await nonce(deployer)} );
            });
            it('2. Hook in PancakeSwap router and factory', async() => {       
                dexrouter = await DexRouter.at(DEXROUTER);
                dexfactory = await DexFactory.at(await dexrouter.factory());
            });
            it('3. Create a DEX pair for CAKE', async() => {       
                cake_pair = await dexfactory.createPair(cake.address, await dexrouter.WETH(), { nonce: await nonce(deployer) });
            });
            it('4. Mint 1,000,000 CAKE and pair with 1 BNB', async() => {       
                await cake.mint(tokens('1000000'), { nonce: await nonce(deployer) });
                await cake.approve(dexrouter.address, tokens('1000000'), { nonce: await nonce(deployer) });
                await dexrouter.addLiquidityETH(cake.address, tokens('1000000'), 0, 0, deployer, await time.latest() + 100, 
                    { value: tokens('1'), nonce: await nonce(deployer) });
            });
            it('5. Deploy the G-Fi token', async() => {       
                gfi = await GFi.new(DEXROUTER, cake.address, { nonce: await nonce(deployer) });
                gfi_pair = await gfi.dexPair();
            });
            it('6. Mint 1,000,000 CAKE and pair with 50,000,000 G-Fi', async() => {       
                await cake.mint(tokens('1000000'), { nonce: await nonce(deployer) });
                await cake.approve(dexrouter.address, tokens('1000000'), { nonce: await nonce(deployer) });
                await gfi.approve(dexrouter.address, tokens('50000000'), { nonce: await nonce(deployer) });
                await dexrouter.addLiquidity(gfi.address, cake.address, tokens('50000000'), tokens('1000000'), 0, 0, deployer, 
                    await time.latest() + 100, { nonce: await nonce(deployer) });
            });
            it('7. Send the remaining balance of the tokens to user 1', async() => {       
                await gfi.transfer(user1, tokens('50000000'), { nonce: await nonce(deployer) });
            });
            it('8. Check all starting balances', async() => {       
                await updateBalances();
                assert.equal(user1_gfi.toString(), new BN(tokens('50000000').toString()), 'User 1 does not have 50,000,000 GFI');
                assert.equal(user2_gfi, 0, 'User 2 does not have 0 GFI');                
                assert.equal(treasury_gfi, 0, 'Treasury does not have 0 GFI');                
            });
        });

        describe('Basic Test Routine', async() => {
            it('1. User 1 can transfer 10,000,000 tokens to user 2', async() => {                       
                await gfi.transfer(user2, tokens('10000000'), { from: user1, nonce: await nonce(user1) });
                await updateBalances();
                await printBalances();
            });            
        });
    });
})