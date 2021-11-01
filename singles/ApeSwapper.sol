// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor()  {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

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