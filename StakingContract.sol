// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error Staking__TransferFailed();
error Withdraw__TransferFailed();
error Staking__NeedsMoreThanZero();

contract Staking is ReentrancyGuard {
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public constant REWARD_RATE = 100;
    uint256 public s_totalSupply;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;

    /* Mapping from address to the amount the user has staked */
    mapping(address => uint256) public s_balances;

    /* Mapping from address to the amount the user has been rewarded */
    mapping(address => uint256) public s_userRewardPerTokenPaid;

    /* Mapping from address to the rewards claimable for user */
    mapping(address => uint256) public s_rewards;

    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken(); //reward per token
        s_lastUpdateTime = block.timestamp; // get last timestamp
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Staking__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    function earned(address account) public view returns (uint256) {
        uint256 currentBalance = s_balances[account];
        // how much they were paid already
        uint256 amountPaid = s_userRewardPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[account];
        uint256 _earned = ((currentBalance *
            (currentRewardPerToken - amountPaid)) / 1e18) + pastRewards;
        return _earned;
    }

    /* rewards increasing based on the length of time staked */
    function rewardPerToken() public view returns (uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        } else {
            return
                s_rewardPerTokenStored +
                (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) /
                    s_totalSupply);
        }
    }

    function stake(
        uint256 amount
    ) external payable updateReward(msg.sender) moreThanZero(amount) {
        s_balances[msg.sender] += amount; // keep track of how much this user has staked
        s_totalSupply += amount; // keep track of how much token we have total
        // transfer the tokens to this contract
        bool success = s_stakingToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );

        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    function withdraw(
        uint256 amount
    ) external updateReward(msg.sender) moreThanZero(amount) {
        s_balances[msg.sender] -= amount;
        s_totalSupply -= amount;
        // transfer
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert Withdraw__TransferFailed();
        }
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        bool success = s_rewardToken.transfer(msg.sender, reward);
        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    // Getter for UI
    function getStaked(address account) public view returns (uint256) {
        return s_balances[account];
    }
}
