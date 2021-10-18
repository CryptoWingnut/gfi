// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";

contract ApeSwapper is Ownable {
    IERC20  public ape;         // The Ape Token
    IERC20  public gfi;         // The Gorilla-FI token
    address public treasury;    // The treasury address to send G-FI to

    // Constructor for constructing things
    constructor(address _ape, address _gfi, address _treasury) {
        ape = IERC20(_ape);
        gfi = IERC20(_gfi);
        treasury = _treasury;
    }

    // Function for deployer to recover tokens if needed
    function recoverApe() public onlyOwner() {
        ape.transfer(treasury, ape.balanceOf(address(this)));
    }

    // Function to swap G-FI for APE
    function swap(uint256 _amount) public {
        require(ape.balanceOf(address(this)) >= _amount, 'Insufficient APE balance for swap');
        require(gfi.transferFrom(msg.sender, treasury, _amount), 'GFI transfer to treasury failed');
        require(ape.transfer(msg.sender, _amount), 'APE transfer to user failed');
    }
}