const { assert } = require('chai');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

require('chai').use(require('chai-as-promised')).should();

const GFi = artifacts.require('GFi');

function tokens(n) {
    return web3.utils.toWei(n, 'Ether');
}

contract('G-Fi Token', ([ deployer, user1, user2 ]) => {
    let gfi;
    let transactionCount1 = 0, transactionCount2 = 0, transactionCount3 = 0;

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

    before(async() => {
        
    });
})