// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title MobiFi
 * @dev Implementation of the Mobile Phone Store Token with complete tokenomics
 */
contract MobiFi is
    ERC20,
    ERC20Burnable,
    Pausable,
    AccessControl,
    ReentrancyGuard
{
    using SafeMath for uint256;

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant STORE_ROLE = keccak256("STORE_ROLE");

    // Token configuration
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 10**18; // 10 million tokens
    uint256 public constant INITIAL_PRICE = 100000000000000; // 0.0001 BNB = $0.10

    // Tier configuration
    struct Tier {
        uint256 requirement;
        uint256 discount;
        bool earlyAccess;
        bool prioritySupport;
        bool exclusiveEvents;
    }

    mapping(string => Tier) public tiers;

    // Staking configuration
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardCalculation;
        bool isStaking;
    }

    mapping(address => StakeInfo) public stakeInfo;
    uint256 public constant MIN_STAKE_DURATION = 90 days;
    uint256 public constant STAKE_APR = 500; // 5% APR, using basis points (1% = 100)

    // Referral configuration
    struct ReferralInfo {
        bool hasBeenReferred;
        address referrer;
        uint256 totalReferrals;
    }

    mapping(address => ReferralInfo) public referralInfo;
    uint256 public constant REFERRAL_REWARD = 50 * 10**18; // 50 tokens

    // Events
    event TierUpdated(string tierName, uint256 requirement, uint256 discount);
    event UserStaked(address indexed user, uint256 amount, uint256 timestamp);
    event UserUnstaked(
        address indexed user,
        uint256 amount,
        uint256 reward,
        uint256 timestamp
    );
    event ReferralProcessed(
        address indexed referrer,
        address indexed referee,
        uint256 reward
    );
    event DiscountApplied(
        address indexed user,
        uint256 amount,
        uint256 discount
    );
    event GovernanceVote(
        address indexed voter,
        uint256 proposalId,
        uint256 votingPower
    );

    /**
     * @dev Constructor initializes the contract with initial supply and roles
     */
    constructor() ERC20("Mobile Phone Store Token", "MPST") {
        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(STORE_ROLE, msg.sender);

        // Initialize tiers
        tiers["BRONZE"] = Tier(100 * 10**18, 500, false, false, false); // 5% discount
        tiers["SILVER"] = Tier(500 * 10**18, 1000, true, false, false); // 10% discount
        tiers["GOLD"] = Tier(1000 * 10**18, 1500, true, true, true); // 15% discount

        // Mint initial supply
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    /**
     * @dev Modifier to check if caller has store role
     */
    modifier onlyStore() {
        require(hasRole(STORE_ROLE, msg.sender), "Caller must have store role");
        _;
    }

    /**
     * @dev Purchase tokens with BNB
     */
    function purchaseTokens() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must send BNB");
        uint256 tokenAmount = (msg.value.mul(10**18)).div(INITIAL_PRICE);
        require(
            balanceOf(address(this)) >= tokenAmount,
            "Insufficient tokens in contract"
        );
        _transfer(address(this), msg.sender, tokenAmount);
    }

    /**
     * @dev Stake tokens
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // If already staking, add rewards and update amount
        if (stakeInfo[msg.sender].isStaking) {
            uint256 reward = calculateStakingReward(msg.sender);
            _mint(msg.sender, reward);
        }

        _transfer(msg.sender, address(this), amount);

        stakeInfo[msg.sender] = StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lastRewardCalculation: block.timestamp,
            isStaking: true
        });

        emit UserStaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Unstake tokens and claim rewards
     */
    function unstake() external nonReentrant whenNotPaused {
        StakeInfo storage userStake = stakeInfo[msg.sender];
        require(userStake.isStaking, "No tokens staked");
        require(
            block.timestamp >= userStake.startTime + MIN_STAKE_DURATION,
            "Minimum stake duration not met"
        );

        uint256 reward = calculateStakingReward(msg.sender);
        uint256 amount = userStake.amount;

        // Reset staking info
        delete stakeInfo[msg.sender];

        // Transfer staked tokens and reward
        _transfer(address(this), msg.sender, amount);
        _mint(msg.sender, reward);

        emit UserUnstaked(msg.sender, amount, reward, block.timestamp);
    }

    /**
     * @dev Calculate staking reward
     * @param user Address of the staker
     * @return reward Amount of reward tokens
     */
    function calculateStakingReward(address user)
        public
        view
        returns (uint256)
    {
        StakeInfo memory userStake = stakeInfo[user];
        if (!userStake.isStaking) return 0;

        uint256 stakingDuration = block.timestamp.sub(
            userStake.lastRewardCalculation
        );
        uint256 reward = userStake
            .amount
            .mul(stakingDuration)
            .mul(STAKE_APR)
            .div(365 days)
            .div(10000); // Basis points division

        return reward;
    }

    /**
     * @dev Process referral
     * @param referee Address of the new user
     */
    function processReferral(address referee) external onlyStore nonReentrant {
        require(
            !referralInfo[referee].hasBeenReferred,
            "User already referred"
        );
        require(msg.sender != referee, "Cannot refer self");

        referralInfo[referee].hasBeenReferred = true;
        referralInfo[referee].referrer = msg.sender;
        referralInfo[msg.sender].totalReferrals++;

        _mint(msg.sender, REFERRAL_REWARD);

        emit ReferralProcessed(msg.sender, referee, REFERRAL_REWARD);
    }

    /**
     * @dev Get user's current tier
     * @param user Address of the user
     * @return string Name of the tier
     */
    function getUserTier(address user) public view returns (string memory) {
        uint256 balance = balanceOf(user).add(stakeInfo[user].amount);

        if (balance >= tiers["GOLD"].requirement) return "GOLD";
        if (balance >= tiers["SILVER"].requirement) return "SILVER";
        if (balance >= tiers["BRONZE"].requirement) return "BRONZE";
        return "STANDARD";
    }

    /**
     * @dev Apply discount based on user's tier
     * @param user Address of the user
     * @param amount Purchase amount
     * @return uint256 Discounted amount
     */
    function applyDiscount(address user, uint256 amount)
        external
        view
        onlyStore
        returns (uint256)
    {
        string memory tier = getUserTier(user);
        uint256 discount = tiers[tier].discount;
        return amount.sub(amount.mul(discount).div(10000));
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Function to transfer the contract ownership to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyRole(ADMIN_ROLE) {
        require(newOwner != address(0), "New owner cannot be the zero address");
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }
}

