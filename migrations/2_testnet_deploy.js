// const ApeToken = artifacts.require("ApeToken");
// const FakeCake = artifacts.require("FakeCake");
// const Router = artifacts.require("IUniswapV2Router02");

// const DEXROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
// const TREASURY = "0x321ADB0e081FbB7298B37FD2BD8FE694be9b81D1";
// const LPSTORE = "0xdCb8e2965549e677E355557033f983CEbE18e9fb";

module.exports = async function (deployer) {
    // await deployer.deploy(FakeCake);
    // const cake = await FakeCake.deployed();

    // await cake.mint('100000000000000000000000000');

    // await deployer.deploy(ApeToken, DEXROUTER, cake.address, TREASURY, LPSTORE);
    // const ape = await ApeToken.deployed();

    // const router = await Router.at(DEXROUTER);
    // await cake.approve(DEXROUTER, '1000000000000000000000000');
    // await ape.approve(DEXROUTER, '1000000000000000000000000');

    // const timeout = new Date().getTime() + 100;
    // await router.addLiquidity(ape.address, cake.address, '1000000000000000000000000', '1000000000000000000000000', 0, 0, TREASURY, timeout);

    // console.log("CAKE : " + cake.address);
    // console.log("APE  : " + ape.address);
}