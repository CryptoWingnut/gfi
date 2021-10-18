const { assert } = require('chai');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { time } = require('@openzeppelin/test-helpers');

require('chai').use(require('chai-as-promised')).should();

const GFi = artifacts.require('CakeApe');
const Cake = artifacts.require('FakeCake');
const DexRouter = artifacts.require('IUniswapV2Router02');
const DexFactory = artifacts.require('IUniswapV2Factory');
const IERC20 = artifacts.require('IERC20');

const DEXROUTER = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';

function tokens(n) {
    return web3.utils.toWei(n, 'Ether');
}

contract('G-Fi Token', ([ deployer, user1, user2, treasury, lpstore ]) => {
    let gfi, cake, dexrouter, dexfactory, cake_pair;
    let user1_gfi, user2_gfi, treasury_cake, lpstore_cake, lpstore_gfi, treasury_cake_old, lpstore_cake_old, lpstore_gfi_old;
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
        result = await cake.balanceOf(treasury);
        treasury_cake = new BN(result.toString()); 
        result = await cake.balanceOf(lpstore);
        lpstore_cake = new BN(result.toString());
        result = await gfi.balanceOf(lpstore);
        lpstore_gfi = new BN(result.toString());
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
                gfi = await GFi.new(DEXROUTER, cake.address, treasury, lpstore, { nonce: await nonce(deployer) });
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
            });
        });

        describe('Basic Test Routine', async() => {
            it('1. User 1 can transfer 10,000,000 tokens to user 2 - taxes taken', async() => {  
                await gfi.transfer(user2, tokens('10000000'), { from: user1, nonce: await nonce(user1) });
                treasury_cake_old = treasury_cake;
                lpstore_cake_old = lpstore_cake;
                lpstore_gfi_old = lpstore_gfi;
                await updateBalances();
                assert.isTrue(treasury_cake.gte(treasury_cake_old), 'Treasury did not receive CAKE');
                assert.isTrue(lpstore_cake.gte(lpstore_cake_old), 'LP store did not receive CAKE');
                assert.isTrue(lpstore_gfi.gte(lpstore_gfi_old), 'LP store did not receive GFI');
                assert.isTrue(user1_gfi.gte(new BN(tokens('40000000'))), 'User 1 does not have enough tokens');
                assert.isTrue(user2_gfi.gte(new BN(tokens('9000000'))), 'User 2 does not have enough tokens');
            });
            it('2. User 1 can transfer another 10,000,000 tokens to user 2 - taxes taken', async() => {  
                await gfi.transfer(user2, tokens('10000000'), { from: user1, nonce: await nonce(user1) });
                treasury_cake_old = treasury_cake;
                lpstore_cake_old = lpstore_cake;
                lpstore_gfi_old = lpstore_gfi;
                await updateBalances();
                assert.isTrue(treasury_cake.gte(treasury_cake_old), 'Treasury did not receive CAKE');
                assert.isTrue(lpstore_cake.gte(lpstore_cake_old), 'LP store did not receive CAKE');
                assert.isTrue(lpstore_gfi.gte(lpstore_gfi_old), 'LP store did not receive GFI');
                assert.isTrue(user1_gfi.gte(new BN(tokens('30000000'))), 'User 1 does not have enough tokens');
                assert.isTrue(user2_gfi.gte(new BN(tokens('18000000'))), 'User 2 does not have enough tokens');
            });
            it('3. Deployer can disable taxes for user 1', async() => {
                await gfi.excludeFromFee(user1, { nonce: await nonce(deployer) });
            });
            it('4. User 1 can transfer another 10,000,000 tokens to user 2 - no taxes taken', async() => {  
                await gfi.transfer(user2, tokens('10000000'), { from: user1, nonce: await nonce(user1) });
                treasury_cake_old = treasury_cake;
                lpstore_cake_old = lpstore_cake;
                lpstore_gfi_old = lpstore_gfi;
                await updateBalances();
                assert.isTrue(treasury_cake_old.eq(treasury_cake), 'Treasury received CAKE');
                assert.isTrue(lpstore_cake_old.eq(lpstore_cake), 'LP store received CAKE');
                assert.isTrue(lpstore_gfi_old.eq(lpstore_gfi), 'LP store received GFI');
                assert.isTrue(user1_gfi.gte(new BN(tokens('20000000'))), 'User 1 does not have enough tokens');
                assert.isTrue(user2_gfi.gte(new BN(tokens('28000000'))), 'User 2 does not have enough tokens');
            });
            it('5. Deployer can enable taxes for user 1', async() => {
                await gfi.includeInFee(user1, { nonce: await nonce(deployer) });
            });
            it('6. User 1 can transfer another 10,000,000 tokens to user 2 - taxes taken', async() => {  
                await gfi.transfer(user2, tokens('10000000'), { from: user1, nonce: await nonce(user1) });
                treasury_cake_old = treasury_cake;
                lpstore_cake_old = lpstore_cake;
                lpstore_gfi_old = lpstore_gfi;
                await updateBalances();
                assert.isTrue(treasury_cake.gte(treasury_cake_old), 'Treasury did not receive CAKE');
                assert.isTrue(lpstore_cake.gte(lpstore_cake_old), 'LP store did not receive CAKE');
                assert.isTrue(lpstore_gfi.gte(lpstore_gfi_old), 'LP store did not receive GFI');
                assert.isTrue(user1_gfi.gte(new BN(tokens('10000000'))), 'User 1 does not have enough tokens');
                assert.isTrue(user2_gfi.gte(new BN(tokens('37000000'))), 'User 2 does not have enough tokens');
            });
            it('7. Deployer can disable taxes for all users', async() => {
                await gfi.setTransferTaxEnabled(false, { nonce: await nonce(deployer) });
            });
            it('8. User 1 can transfer remaining tokens to user 2 - no taxes taken', async() => {  
                await gfi.transfer(user2, user1_gfi, { from: user1, nonce: await nonce(user1) });
                treasury_cake_old = treasury_cake;
                lpstore_cake_old = lpstore_cake;
                lpstore_gfi_old = lpstore_gfi;
                await updateBalances();
                assert.isTrue(treasury_cake_old.eq(treasury_cake), 'Treasury received CAKE');
                assert.isTrue(lpstore_cake_old.eq(lpstore_cake), 'LP store received CAKE');
                assert.isTrue(lpstore_gfi_old.eq(lpstore_gfi), 'LP store received GFI');
                assert.isTrue(user1_gfi.eq(new BN(tokens('0'))), 'User 1 does not have enough tokens');
                assert.isTrue(user2_gfi.gte(new BN(tokens('47000000'))), 'User 2 does not have enough tokens');
            });
        });
    });
})