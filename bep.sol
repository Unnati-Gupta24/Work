// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MPST {
    string public constant name = "My Phone Store Token";
    string public constant symbol = "MPST";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 10_000_000 * 10**decimals;
    
    address public owner;
    address public pendingOwner;
    bool public paused;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    
    uint256 public constant MIN_STAKE_DURATION = 90 days;
    uint256 public constant REFERRAL_REWARD = 50 * 10**decimals;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferStarted(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Already owner");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }
    
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
    
    function pause() external onlyOwner {
        require(!paused, "Already paused");
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        return _transfer(msg.sender, to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }
    
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Zero amount");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        stakingTimestamp[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake() external whenNotPaused {
        uint256 amount = stakedBalance[msg.sender];
        require(amount > 0, "No stake");
        require(block.timestamp >= stakingTimestamp[msg.sender] + MIN_STAKE_DURATION, 
                "Stake locked");
        
        stakedBalance[msg.sender] = 0;
        balanceOf[msg.sender] += amount;
        
        emit Unstaked(msg.sender, amount);
    }
    
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "From zero address");
        require(to != address(0), "To zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    // Emergency token recovery
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot recover native tokens");
        (bool success, ) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, amount)
        );
        require(success, "Recovery failed");
    }
}
