const { assert } = require('chai');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { time } = require('@openzeppelin/test-helpers');

require('chai').use(require('chai-as-promised')).should();

const CakeApe = artifacts.require('CakeApe');
const Cake = artifacts.require('FakeCake');
const Taxed = artifacts.require('ExampleTaxedToken');
const Swapper = artifacts.require('ApeSwapper');

const DEXROUTER = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';

function tokens(n) {
    return web3.utils.toWei(n, 'Ether');
}

contract('Ape Swapper', ([ deployer, user, treasury ]) => {
    let ape, cake, taxed, swapper;
    let result, temp;
    let transactionCount1 = 0, transactionCount2 = 0;
    let BN = web3.utils.BN;

    async function nonce(account) {
        if (account == deployer) {
            transactionCount1 += 1;
            return await web3.eth.getTransactionCount(await deployer, 'pending') + (transactionCount1 - 1);
        } else {
            transactionCount2 += 1;
            return await web3.eth.getTransactionCount(await user, 'pending') + (transactionCount2 - 1);
        }
    }

    describe('Ape Swapper Test Script', async() => {
        describe('Test Environment Setup', async() => {
            it('1. Deploy Fake CAKE, CAKE APE, Example Taxed token', async() => {
                cake = await Cake.new({ nonce: await nonce(deployer)} );
                ape = await CakeApe.new(DEXROUTER, cake.address, treasury, treasury, { nonce: await nonce(deployer) });
                taxed = await Taxed.new({ nonce: await nonce(deployer) });
            });
            it('2. Deploy the ApeSwapper contract', async() => {
                swapper = await Swapper.new(ape.address, taxed.address, treasury, { nonce: await nonce(deployer) });
            });
            it('3. Exclude the swapper from taxes on APE token', async() => {
                await ape.excludeFromFee(swapper.address, { nonce: await nonce(deployer) });
            });
            it('4. Deployer transfer 20,000,000 APE tokens to swapper', async() => {
                await ape.transfer(swapper.address, tokens('20000000'), { nonce: await nonce(deployer) });
            });
            it('5. Mint user 10,000,000 example taxed token', async() => {
                await taxed.mint(user, tokens('10000000'), { nonce: await nonce(deployer) });
            });
            it('6. Validate starting state', async() => {
                result = await ape.balanceOf(deployer);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('80000000'))), 'Deployer does not have 80,000,000 APE');
                result = await ape.balanceOf(swapper.address);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('20000000'))), 'Swapper does not have 20,000,000 APE');
                result = await ape.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'User does not have 0 APE');
                result = await taxed.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('10000000'))), 'User does not have 10,000,000 TAXED');
                result = await taxed.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'Treasury does not have 0 TAXED');
                result = await ape.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'Treasury does not have 0 APE');
            });
        });
        describe('Test Routine', async() => {
            it('1. User can swap 10,000,000 TAXED with the swapper', async() => {
                await taxed.approve(swapper.address, tokens('10000000'), { from: user, nonce: await nonce(user) });
                await swapper.swap(tokens('10000000'), { from: user, nonce: await nonce(user) });
            });
            it('2. Validate post swap balances', async() => {
                result = await ape.balanceOf(deployer);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('80000000'))), 'Deployer does not have 80,000,000 APE');
                result = await ape.balanceOf(swapper.address);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('10000000'))), 'Swapper does not have 10,000,000 APE');
                result = await ape.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('10000000'))), 'User does not have 10,000,000 APE');
                result = await taxed.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'User does not have 0 TAXED');
                result = await taxed.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('9000000'))), 'Treasury does not have 9,000,000 TAXED');
                result = await ape.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'Treasury does not have 0 APE');
            });
            it('3. Deployer can recover APE tokens from swapper contract', async() => {
                await swapper.recoverApe({ nonce: await nonce(deployer) });
            });
            it('4. Validate post recovery balances', async() => {
                result = await ape.balanceOf(deployer);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('80000000'))), 'Deployer does not have 80,000,000 APE');
                result = await ape.balanceOf(swapper.address);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'Swapper does not have 0 APE');
                result = await ape.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('10000000'))), 'User does not have 10,000,000 APE');
                result = await taxed.balanceOf(user);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(0)), 'User does not have 0 TAXED');
                result = await taxed.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('9000000'))), 'Treasury does not have 9,000,000 TAXED');
                result = await ape.balanceOf(treasury);
                temp = new BN(result.toString());
                assert.isTrue(temp.eq(new BN(tokens('10000000'))), 'Treasury does not have 10,000,000 APE');
            });
        });
    });
})