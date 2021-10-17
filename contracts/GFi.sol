// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./utils/Address.sol";
import "./utils/Ownable.sol";

contract GorillaFi is IERC20, Ownable {
    using Address for address;

    string      public name         = "GorillaFi";      // Token name
    string      public symbol       = "G-Fi";           // Token symbol
    uint8       public decimals     = 18;               // Token decimals
    uint256     public taxFee       = 4;                // The reflection tax rate    
    uint256     public liquidityFee = 5;                // The liquidity tax rate
    uint256     public marketingTax = 1;                // The marketing tax rate
    bool        public transferTaxEnabled = true;       // Flag for if the transfer tax is enabled
    address     public dexPair;                         // The DEX pair to add liquidity to
    IERC20      public cake;                            // The CAKE token
    address     public treasury;                        // The treasury for sending marketing tax to  

    address[]   private excluded;                       // Array of addresses excluded from rewards

    uint256 public maxTxAmount = 100000000 * 10 ** uint256(decimals);// The maximum transfer amount
    uint256 private constant MAX = ~uint256(0);         // uint256 maximum
    uint256 private tTotal = 100000000 * 10 ** uint256(decimals); // Total supply of the token
    uint256 private rTotal = (MAX - (MAX % tTotal));    // Total reflections
    uint256 private tFeeTotal;                          // The total fees
    
    IUniswapV2Router02 public dexRouter;                // The DEX router for performing swaps

    // Variables to store tax rates while doing notax operations
    uint256 private previousTaxFee = taxFee;
    uint256 private previousLiquidityFee = liquidityFee;    
    uint256 private previousMarketingTax = marketingTax;

    // Balance mappings
    mapping (address => uint256) private rOwned;
    mapping (address => uint256) private tOwned;
    mapping (address => mapping (address => uint256)) private allowances;

    // Exclusion mappings
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isExcluded;
    
    // Events for sending stuff
    event MinTokensBeforeSwapUpdated(uint256 _minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool _enabled);
    event SwapAndLiquify(uint256 _tokensSwapped, uint256 _ethReceived, uint256 _tokensIntoLiqudity);
    
    // Constructor for constructing things
    constructor (address _dexRouter, address _cake) {
        cake = IERC20(_cake);
        treasury = msg.sender;

        rOwned[msg.sender] = rTotal;
        
        dexRouter = IUniswapV2Router02(_dexRouter);
        dexPair = IUniswapV2Factory(dexRouter.factory()).createPair(address(this), _cake);
        
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[treasury];
        
        emit Transfer(address(0), msg.sender, tTotal);
    }

    receive() external payable {}

    // Function to set the DEX router
    function setDex(address _dexRouter, address _dexPair) public onlyOwner() {
        dexRouter = IUniswapV2Router02(_dexRouter);
        dexPair = _dexPair;
    }

    // Function to set the treasury address
    function setTreasury(address _treasury) public onlyOwner() {
        treasury = _treasury;
    }

    // Function to set if the transfer tax is enabled
    function setTransferTaxEnabled(bool _enabled) public onlyOwner() {
        transferTaxEnabled = _enabled;
    }

    // Function to exclude an address from fee
    function excludeFromFee(address _account) public onlyOwner() {
        isExcludedFromFee[_account] = true;
    }

    // Function to include an address for the fee
    function includeInFee(address _account) public onlyOwner() {
        isExcludedFromFee[_account] = false;
    }
    
    // Function to set the tax percent
    function setTaxFeePercent(uint256 _taxFee) public onlyOwner() {
        taxFee = _taxFee;
    }
    
    // Function to set the liquidity percentage
    function setLiquidityFeePercent(uint256 _liquidityFee) public onlyOwner() {
        liquidityFee = _liquidityFee;
    }

    // Function to set the marketing tax percentage
    function setMarketingTax(uint256 _marketingTax) public onlyOwner() {
        marketingTax = _marketingTax;
    }
   
    // Function to set the max transfer size
    function setMaxTxPercent(uint256 _maxTxPercent) public onlyOwner() {
        maxTxAmount = tTotal * _maxTxPercent / (10**2);
    }

    // Function to exclude an address from getting rewards
    function excludeFromReward(address _account) public onlyOwner() {
        require(!isExcluded[_account], "Account is already excluded");
        if(rOwned[_account] > 0) {
            tOwned[_account] = tokenFromReflection(rOwned[_account]);
        }
        isExcluded[_account] = true;
        excluded.push(_account);
    }

    // Function to include an address in getting rewards
    function includeInReward(address _account) public onlyOwner() {
        require(isExcluded[_account], "Account is not excluded");
        for (uint256 i = 0; i < excluded.length; i++) {
            if (excluded[i] == _account) {
                excluded[i] = excluded[excluded.length - 1];
                tOwned[_account] = 0;
                isExcluded[_account] = false;
                excluded.pop();
                break;
            }
        }
    }

    // Function to get the total supply
    function totalSupply() public view override returns (uint256) { return tTotal; }

    // Function to get the balance of an account
    function balanceOf(address _account) public view override returns (uint256) {
        if (isExcluded[_account]) return tOwned[_account];
        return tokenFromReflection(rOwned[_account]);
    }

    // Function for initiating a transfer
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    // Function for getting the allowance of a spender
    function allowance(address _owner, address _spender) public view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    // Function for initiating an approval
    function approve(address _spender, uint256 _amount) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    // Function for initiating a transfer from
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, allowances[_sender][msg.sender] - _amount);
        return true;
    }

    // Function to increase the allowance for a spender
    function increaseAllowance(address _spender, uint256 _addedValue) public virtual returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    // Function to decrease the allowance for a spender
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender]- _subtractedValue);
        return true;
    }

    // Function to check if an address is excluded from rewards
    function isExcludedFromReward(address _account) public view returns (bool) {
        return isExcluded[_account];
    }

    // Function to get the total fees
    function totalFees() public view returns (uint256) {
        return tFeeTotal;
    }

    // Deliver function
    function deliver(uint256 _tAmount) public {
        address sender = msg.sender;
        require(!isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,,) = _getValues(_tAmount);
        rOwned[sender] = rOwned[sender] - rAmount;
        rTotal = rTotal - rAmount;
        tFeeTotal = tFeeTotal + _tAmount;
    }

    // Function to get the reflections for an amount
    function reflectionFromToken(uint256 _tAmount, bool _deductTransferFee) public view returns(uint256) {
        require(_tAmount <= tTotal, "Amount must be less than supply");
        if (!_deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getValues(_tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(_tAmount);
            return rTransferAmount;
        }
    }

    // Function to get the tokens from reflections
    function tokenFromReflection(uint256 _rAmount) public view returns(uint256) {
        require(_rAmount <= rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return _rAmount / currentRate;
    }

    // Function to get the reflection fee
    function _reflectFee(uint256 _rFee, uint256 _tFee) private {
        rTotal = rTotal - _rFee;
        tFeeTotal = tFeeTotal + _tFee;
    }

    // Function to calculate the values
    function _getValues(uint256 _tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getTValues(_tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = 
            _getRValues(_tAmount, tFee, tLiquidity, tMarketing, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tMarketing);
    }

    // Function to calculate the 't' values
    function _getTValues(uint256 _tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = _calculateTaxFee(_tAmount);
        uint256 tLiquidity = _calculateLiquidityFee(_tAmount);
        uint256 tMarketing = _calculateMarketingTax(_tAmount);
        uint256 tTransferAmount = _tAmount - tFee - tLiquidity - tMarketing;
        return (tTransferAmount, tFee, tLiquidity, tMarketing);
    }

    // Function to calculate the 'r' values
    function _getRValues(uint256 _tAmount, uint256 _tFee, uint256 _tLiquidity, uint256 _tMarketing, uint256 _currentRate) 
            private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = _tAmount * _currentRate;
        uint256 rFee = _tFee * _currentRate;
        uint256 rLiquidity = _tLiquidity * _currentRate;
        uint256 rMarketing = _tMarketing * _currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity - rMarketing;
        return (rAmount, rTransferAmount, rFee);
    }

    // Function to get the current rate
    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    // Function to get the current supply
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = rTotal;
        uint256 tSupply = tTotal;      
        for (uint256 i = 0; i < excluded.length; i++) {
            if (rOwned[excluded[i]] > rSupply || tOwned[excluded[i]] > tSupply) return (rTotal, tTotal);
            rSupply = rSupply - rOwned[excluded[i]];
            tSupply = tSupply - tOwned[excluded[i]];
        }
        if (rSupply < rTotal / tTotal) return (rTotal, tTotal);
        return (rSupply, tSupply);
    }
    
    // Function to take liquidity
    function _takeLiquidity(uint256 _tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = _tLiquidity * currentRate;
        rOwned[treasury] = rOwned[treasury] + rLiquidity;
        if(isExcluded[treasury])
            tOwned[treasury] = tOwned[treasury] + _tLiquidity;
    }

    // Function to tax marketing tax
    function _takeMarketing(uint256 _tMarketing) private {
        uint256 currentRate =  _getRate();
        uint256 rMarketing = _tMarketing * currentRate;
        rOwned[treasury] = rOwned[treasury] + rMarketing;
        if (isExcluded[treasury])
            tOwned[treasury] = tOwned[treasury] + _tMarketing;        
    }
    
    // Function to calculate the tax fee
    function _calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount * taxFee / (10 ** 2);
    }

    // Function to calculate the liquidity fee
    function _calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount * liquidityFee / (10 ** 2);
    }

    // Function to calculate the marketing tax
    function _calculateMarketingTax(uint256 _amount) private view returns (uint256) {
        return _amount * marketingTax / (10 ** 2);
    }
    
    // Function to set all tax rates to zero
    function _removeAllFee() private {
        if(taxFee == 0 && liquidityFee == 0 && marketingTax == 0) return;
        
        previousTaxFee = taxFee;
        previousLiquidityFee = liquidityFee;
        previousMarketingTax = marketingTax;
        
        taxFee = 0;
        liquidityFee = 0;
        marketingTax = 0;
    }
    
    // Function to restore the tax rates
    function _restoreAllFee() private {
        taxFee = previousTaxFee;
        liquidityFee = previousLiquidityFee;
        marketingTax = previousMarketingTax;
    }

    // Function to handle approvals
    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    // Function to handle transfers
    function _transfer(address _from, address _to, uint256 _amount) private {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");
        require(_amount > 0, "Transfer amount must be greater than zero");
        if(_from != owner() && _to != owner()) {
            require(_amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        bool takeFee = true;
        
        if(!transferTaxEnabled || isExcludedFromFee[_from] || isExcludedFromFee[_to]){
            takeFee = false;
        }
        
        _tokenTransfer(_from, _to, _amount, takeFee);
    }

    // Function to handle transfers based on fees
    function _tokenTransfer(address _sender, address _recipient, uint256 _amount, bool _takeFee) private {
        if(!_takeFee)
            _removeAllFee();
        
        if (isExcluded[_sender] && !isExcluded[_recipient]) {
            _transferFromExcluded(_sender, _recipient, _amount);
        } else if (!isExcluded[_sender] && isExcluded[_recipient]) {
            _transferToExcluded(_sender, _recipient, _amount);
        } else if (!isExcluded[_sender] && !isExcluded[_recipient]) {
            _transferStandard(_sender, _recipient, _amount);
        } else if (isExcluded[_sender] && isExcluded[_recipient]) {
            _transferBothExcluded(_sender, _recipient, _amount);
        } else {
            _transferStandard(_sender, _recipient, _amount);
        }
        
        if(!_takeFee)
            _restoreAllFee();
    }

    // Function for handling standard transfers
    function _transferStandard(address _sender, address _recipient, uint256 _tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, 
            uint256 tLiquidity, uint256 tMarketing) = _getValues(_tAmount);

        rOwned[_sender] = rOwned[_sender] - rAmount;
        rOwned[_recipient] = rOwned[_recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeMarketing(tMarketing);
        emit Transfer(_sender, _recipient, tTransferAmount);
    }

    // Function for handling transferring to an excluded address
    function _transferToExcluded(address _sender, address _recipient, uint256 _tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, 
            uint256 tLiquidity, uint256 tMarketing) = _getValues(_tAmount);
        rOwned[_sender] = rOwned[_sender] - rAmount;
        tOwned[_recipient] = tOwned[_recipient] + tTransferAmount;
        rOwned[_recipient] = rOwned[_recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeMarketing(tMarketing);
        emit Transfer(_sender, _recipient, tTransferAmount);
    }

    // Function for handling transferring from and excluded address
    function _transferFromExcluded(address _sender, address _recipient, uint256 _tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, 
            uint256 tLiquidity, uint256 tMarketing) = _getValues(_tAmount);
        tOwned[_sender] = tOwned[_sender] - _tAmount;
        rOwned[_sender] = rOwned[_sender] - rAmount;
        rOwned[_recipient] = rOwned[_recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeMarketing(tMarketing);
        emit Transfer(_sender, _recipient, tTransferAmount);
    }

    // Function for performing a transfer when both parties are excluded        
    function _transferBothExcluded(address _sender, address _recipient, uint256 _tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, 
            uint256 tLiquidity, uint256 tMarketing) = _getValues(_tAmount);
        tOwned[_sender] = tOwned[_sender] - _tAmount;
        rOwned[_sender] = rOwned[_sender] - rAmount;
        tOwned[_recipient] = tOwned[_recipient] + tTransferAmount;
        rOwned[_recipient] = rOwned[_recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        _takeMarketing(tMarketing);
        emit Transfer(_sender, _recipient, tTransferAmount);
    }
}