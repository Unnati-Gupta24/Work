// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inlined Context contract
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// Inlined Ownable contract
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Inlined Pausable contract
abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// Inlined IERC20 interface
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// Inlined ERC20 contract
contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}

// Main Token Contract
contract PhoneStoreLoyaltyToken is ERC20, Ownable, Pausable {
    // Token tiers
    struct Tier {
        string name;
        uint256 requiredTokens;
        uint256 discountPercentage;
    }

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => bool) public isStaking;
    
    Tier[] public tiers;
    
    uint256 public constant TOTAL_SUPPLY = 10000000 * 10**18; // 10 million tokens
    uint256 public constant STAKING_PERIOD = 90 days; // 3 months
    uint256 public constant REFERRAL_REWARD = 50 * 10**18; // 50 tokens
    
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    event ReferralRewarded(address indexed referrer, address indexed newCustomer);
    event TierAchieved(address indexed user, string tierName);

    constructor() ERC20("Phone Store Loyalty Token", "PSLT") {
        _mint(_msgSender(), TOTAL_SUPPLY);
        
        // Initialize tiers
        tiers.push(Tier("Bronze", 100 * 10**18, 5));
        tiers.push(Tier("Silver", 500 * 10**18, 10));
        tiers.push(Tier("Gold", 1000 * 10**18, 15));
    }

    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");
        
        _transfer(_msgSender(), address(this), amount);
        
        if (isStaking[_msgSender()]) {
            stakedBalance[_msgSender()] += amount;
        } else {
            stakedBalance[_msgSender()] = amount;
            stakingTimestamp[_msgSender()] = block.timestamp;
            isStaking[_msgSender()] = true;
        }
        
        emit TokensStaked(_msgSender(), amount);
        _checkAndUpdateTier(_msgSender());
    }

    function unstake() external whenNotPaused {
        require(isStaking[_msgSender()], "No tokens staked");
        require(block.timestamp >= stakingTimestamp[_msgSender()] + STAKING_PERIOD, "Staking period not complete");
        
        uint256 amount = stakedBalance[_msgSender()];
        stakedBalance[_msgSender()] = 0;
        isStaking[_msgSender()] = false;
        
        _transfer(address(this), _msgSender(), amount);
        
        emit TokensUnstaked(_msgSender(), amount);
        _checkAndUpdateTier(_msgSender());
    }

    function rewardReferral(address referrer, address newCustomer) external onlyOwner {
        require(referrer != address(0) && newCustomer != address(0), "Invalid address");
        require(referrer != newCustomer, "Cannot refer self");
        
        _mint(referrer, REFERRAL_REWARD);
        emit ReferralRewarded(referrer, newCustomer);
    }

    function getUserTier(address user) public view returns (string memory, uint256) {
        uint256 totalBalance = balanceOf(user) + stakedBalance[user];
        
        for (uint256 i = tiers.length; i > 0; i--) {
            if (totalBalance >= tiers[i-1].requiredTokens) {
                return (tiers[i-1].name, tiers[i-1].discountPercentage);
            }
        }
        
        return ("No Tier", 0);
    }

    function _checkAndUpdateTier(address user) internal {
        (string memory tierName,) = getUserTier(user);
        emit TierAchieved(user, tierName);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        bool success = super.transfer(to, amount);
        if (success) {
            _checkAndUpdateTier(_msgSender());
            _checkAndUpdateTier(to);
        }
        return success;
    }
}
