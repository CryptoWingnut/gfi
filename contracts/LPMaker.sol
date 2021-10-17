// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./utils/Ownable.sol";

contract LPMaker is Ownable {
    IERC20              public ape;             // The CAKE APE token
    IERC20              public cake;            // The CAKE token
    IUniswapV2Router02  public dexRouter;       // The DEX router
    address             public lpStorage;       // The LP storage address

    // Constructor for constructing things
    constructor(address _ape, address _cake, address _dexRouter, address _lpStorage) {
        ape = IERC20(_ape);
        cake = IERC20(_cake);
        dexRouter = IUniswapV2Router02(_dexRouter);
        lpStorage = _lpStorage;
    }

    // Function to set the DEX router
    function setDexRouter(address _dexRouter) public onlyOwner() {
        dexRouter = IUniswapV2Router02(_dexRouter);
    }

    // Function to set the lpStorage address
    function setLPStorage(address _lpStorage) public onlyOwner() {
        lpStorage = _lpStorage;
    }

    // Function to emergency recover APE/CAKE that has been sent here
    function emergencyWithdraw() public onlyOwner() {
        uint256 apeBal = ape.balanceOf(address(this));
        uint256 cakeBal = cake.balanceOf(address(this));
        
        ape.transfer(owner(), apeBal);
        cake.transfer(owner(), cakeBal);
    }

    // Function to add the liquidity
    function addLiquidity(uint256 _tokenAmount, uint256 _cakeAmount) public onlyOwner() {
        uint256 apeBal = ape.balanceOf(address(this));
        uint256 cakeBal = cake.balanceOf(address(this));
        
        ape.approve(address(dexRouter), apeBal);
        cake.approve(address(dexRouter), cakeBal);

        dexRouter.addLiquidity(
            address(this), 
            address(cake), 
            _tokenAmount, 
            _cakeAmount, 
            0, 
            0, 
            lpStorage, 
            block.timestamp);
    }
}