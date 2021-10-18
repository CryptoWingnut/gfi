// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";

contract ExampleTaxedToken is Ownable, IERC20 {
    string  private _name = 'Taxed Token';          // The token's name
    string  private _symbol = 'TAX';                // The token's symbol
    uint8   private _decimals = 18;                 // The token's decimal
    uint256 private _totalSupply;                   // The token's supply
    uint256 private _tax = 1000;                    // The tax rate to burn

    address public _burnAddr = 0x000000000000000000000000000000000000dEaD;


    // Mapping tables for storing wallet balances and allowances
    mapping(address => uint256)                     private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Functions to return data stored in the contract
    function getOwner() external view returns (address) { return owner(); }
    function name() public view returns (string memory) { return _name; }
    function decimals() public view returns (uint8) { return _decimals; }
    function symbol() public view returns (string memory) { return _symbol; }
    function totalSupply() public override view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public override view returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) public override view returns (uint256) { return _allowances[owner][spender]; }
    
    // Transfer function
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    // Transfer From function
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    // Approves the spender to spend an amount of the sender's tokens
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    // Increases the allowance an address can spend on behalf of another
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - addedValue);
        return true;
    }

    // Decreases the allowance an address can spend on behalf of another
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    // Function for minting tokens
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), 'BEP20: mint to the zero address');

        _totalSupply = _totalSupply + _amount;
        _balances[_to] = _balances[_to] + _amount;
        emit Transfer(address(0), _to, _amount);
    }

    // Function that actually handles transfers
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), 'Cannot transfer from 0 address');
        require(_balances[sender] >= amount, 'You cannot transfer more tokens than you have');
        
        uint256 tokens = amount;
        uint256 taxes = (amount * _tax) / 10000;
        _balances[_burnAddr] = _balances[_burnAddr] + _tax;
        tokens = amount - taxes;
        
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + tokens;
        emit Transfer(sender, recipient, amount);
    }

    // Approves another address to spend on the owners behalf
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), 'Cannot approve from the zero address');
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}