/**
 *Submitted for verification at BscScan.com on 2025-07-08
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-07-07
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DGDStaking {
    IERC20 public token;
    address public owner;
    bool public stakingActive = true;
    uint256 public totalStaked;
    uint256 public constant REWARD_PER_TOKEN = 50000000e18;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 apy;
        uint8 plan;
        bool withdrawn;
    }

    mapping(address => StakeInfo[]) public stakes;
    mapping(uint8 => uint256) public planAPY;
    mapping(uint8 => uint256) public planLockPeriod;
    mapping(uint8 => uint256) public totalStakedPerPlan;

    struct Snapshot {
        uint256 time;
        address rewardToken;
        uint256 totalReward;
        mapping(address => uint256) userRewards;
        mapping(address => bool) userClaimed;
    }

    Snapshot[] public snapshots;
    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;

    address[] public stakers;
    mapping(address => bool) public hasStaked;

    event Staked(address indexed user, uint256 amount, uint8 plan);
    event Unstaked(address indexed user, uint256 reward);
    event ForceUnlocked(address indexed user, uint256 index, uint256 totalReturned);
    event RewardTokenAdded(address token);
    event SnapshotCreated(address rewardToken, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;

        planAPY[0] = 15;
        planAPY[1] = 20;
        planAPY[2] = 50;

        planLockPeriod[0] = 15 days;
        planLockPeriod[1] = 30 days;
        planLockPeriod[2] = 90 days;
    }

    function stake(uint256 amount, uint8 plan) external {
        require(stakingActive, "Staking disabled");
        require(amount > 0, "Amount must be > 0");
        require(planAPY[plan] > 0, "Invalid plan");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        if (!hasStaked[msg.sender]) {
            hasStaked[msg.sender] = true;
            stakers.push(msg.sender);
        }

        totalStaked += amount;
        totalStakedPerPlan[plan] += amount;

        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: planLockPeriod[plan],
            apy: planAPY[plan],
            plan: plan,
            withdrawn: false
        }));

        emit Staked(msg.sender, amount, plan);
    }

    function notifyRewardTokens(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            address t = tokens[i];
            if (!isRewardToken[t]) {
                isRewardToken[t] = true;
                rewardTokens.push(t);
                emit RewardTokenAdded(t);
            }
        }
    }

    function snapshotDistributeRewards() external onlyOwner {
        uint256[3] memory shares = [uint256(15), 30, 55];

        for (uint r = 0; r < rewardTokens.length; r++) {
            address rewardToken = rewardTokens[r];
            Snapshot storage snap = snapshots.push();
            snap.time = block.timestamp;
            snap.rewardToken = rewardToken;
            snap.totalReward = REWARD_PER_TOKEN;

            for (uint8 p = 0; p < 3; p++) {
                uint256 totalWeight = 0;
                address[] memory userList = new address[](stakers.length);
                uint256[] memory userWeights = new uint256[](stakers.length);
                uint256 count = 0;

                for (uint u = 0; u < stakers.length; u++) {
                    address user = stakers[u];
                    StakeInfo[] storage sArr = stakes[user];
                    uint256 userWeight = 0;

                    for (uint i = 0; i < sArr.length; i++) {
                        StakeInfo storage s = sArr[i];
                        if (!s.withdrawn && s.plan == p) {
                            uint256 remaining = s.startTime + s.lockPeriod > block.timestamp ?
                                s.startTime + s.lockPeriod - block.timestamp : 0;
                            userWeight += s.amount * remaining;
                        }
                    }

                    if (userWeight > 0) {
                        userList[count] = user;
                        userWeights[count] = userWeight;
                        totalWeight += userWeight;
                        count++;
                    }
                }

                uint256 planReward = REWARD_PER_TOKEN * shares[p] / 100;
                for (uint j = 0; j < count; j++) {
                    address user = userList[j];
                    uint256 weight = userWeights[j];
                    if (weight > 0 && totalWeight > 0) {
                        uint256 reward = planReward * weight / totalWeight;
                        snap.userRewards[user] += reward;
                    }
                }
            }

            emit SnapshotCreated(rewardToken, REWARD_PER_TOKEN);
        }
    }

    function unstake(uint256 index) external {
        require(index < stakes[msg.sender].length, "Invalid index");
        StakeInfo storage s = stakes[msg.sender][index];
        require(!s.withdrawn, "Already withdrawn");
        require(block.timestamp >= s.startTime + s.lockPeriod, "Lock period not over");

        s.withdrawn = true;

        uint256 baseReward = s.amount * s.apy * s.lockPeriod / 365 days / 100;
        uint256 total = s.amount + baseReward;

        totalStaked -= s.amount;
        totalStakedPerPlan[s.plan] -= s.amount;

        require(token.transfer(msg.sender, total), "Transfer failed");
        emit Unstaked(msg.sender, baseReward);

        _claimSnapshotRewards(msg.sender);
    }

    function _claimSnapshotRewards(address user) internal {
        for (uint256 i = 0; i < snapshots.length; i++) {
            Snapshot storage snap = snapshots[i];
            if (!snap.userClaimed[user]) {
                uint256 reward = snap.userRewards[user];
                if (reward > 0) {
                    snap.userClaimed[user] = true;
                    IERC20(snap.rewardToken).transfer(user, reward);
                }
            }
        }
    }

    function forceUnlock(address user, uint256 index) external onlyOwner {
        require(index < stakes[user].length, "Invalid index");
        StakeInfo storage s = stakes[user][index];
        require(!s.withdrawn, "Already withdrawn");

        s.withdrawn = true;
        totalStaked -= s.amount;
        totalStakedPerPlan[s.plan] -= s.amount;

        require(token.transfer(user, s.amount), "Transfer failed");
        emit ForceUnlocked(user, index, s.amount);

        _claimSnapshotRewards(user);
    }

    function setPlanAPY(uint8 plan, uint256 newApy) external onlyOwner {
        planAPY[plan] = newApy;
    }

    function setPlanLockPeriod(uint8 plan, uint256 newLockPeriod) external onlyOwner {
        planLockPeriod[plan] = newLockPeriod;
    }

    function toggleStaking(bool enabled) external onlyOwner {
        stakingActive = enabled;
    }

    function changeToken(address newToken) external onlyOwner {
        token = IERC20(newToken);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    function getStakes(address user) external view returns (StakeInfo[] memory) {
        return stakes[user];
    }
}