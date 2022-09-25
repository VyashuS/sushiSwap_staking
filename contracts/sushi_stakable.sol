// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract SushiBarStakeAble is ERC20("SushiBarStakable", "xSUST") {
    using SafeMath for uint256;
    IERC20 public sushi;
    uint public unlockTime;
    address payable public owner;
    uint public constant duration = 30 days;
    uint public immutable_end;
    address payable public immutable_owner;
    // boolean to prevent reentrancy
    bool internal locked;

    // Timestamp related variables
    uint256 public initialTimestamp;
    bool public timestampSet;
    uint256 public timePeriod;

    //timelock

    // Token amount variables
    mapping(address => uint256) public alreadyWithdrawn;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakedOnTimeStamp;
    uint256 public contractBalance;

    event Withdrawal(uint amount, uint when);

    // Events
    event tokensStaked(address from, uint256 amount);
    event TokensUnstaked(address to, uint256 amount);

    constructor(uint _unlockTime, IERC20 _sushi) payable {
        require(
            block.timestamp < _unlockTime,
            "Unlock time should be in the future"
        );
        sushi = _sushi;
        unlockTime = _unlockTime;
        owner = payable(msg.sender);
        // Timestamp values not set yet
        timestampSet = false;
        locked = false;
    }

    function enter(uint256 _amount) public {
        uint256 totalSushi = sushi.balanceOf(address(this));
        uint256 totalShares = sushi.totalSupply();
        if (totalShares == 0 || totalSushi == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            _mint(msg.sender, what);
        }
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SUSHIs.
    function leave(uint256 _share) public {
        uint256 totalShares = sushi.totalSupply();
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(
            totalShares
        );
        _burn(msg.sender, _share);
        sushi.transfer(msg.sender, what);
    }

    // staking additiions

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Message sender must be the contract's owner."
        );
        _;
    }

    modifier timestampNotSet() {
        require(timestampSet == false, "The time stamp has already been set.");
        _;
    }

    modifier timestampIsSet() {
        require(
            timestampSet == true,
            "Please set the time stamp first, then try again."
        );
        _;
    }

    function withdraw() public {
        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        require(msg.sender == owner, "You aren't the owner");
        emit Withdrawal(address(this).balance, block.timestamp);
        owner.transfer(address(this).balance);
    }

    function setTimestamp(uint256 _timePeriodInSeconds)
        public
        onlyOwner
        timestampNotSet
    {
        timestampSet = true;
        initialTimestamp = block.timestamp;
        timePeriod = initialTimestamp.add(_timePeriodInSeconds);
    }

    function stakeTokens(IERC20 token, uint256 amount) public timestampIsSet {
        require(
            token == sushi,
            "You are only allowed to stake the official erc20 token address which was passed into this contract's constructor"
        );
        require(
            amount <= token.balanceOf(msg.sender),
            "Not enough STATE tokens in your wallet, please try lesser amount"
        );
        sushi.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        emit tokensStaked(msg.sender, amount);
    }

    // 2 days - 0% can be unstaked
    // 2-4 days - 25% can be unstaked
    // 4-6 days - 50% can be unstaked
    // 6-8 days - 75% can be unstaked

    function unstakeTokens(IERC20 token, uint256 amount) public timestampIsSet {
        require(
            balances[msg.sender] >= amount,
            "Insufficient token balance, try lesser amount"
        );
        require(
            token == sushi,
            "Token parameter must be the same as the erc20 contract address which was passed into the constructor"
        );

        require(
            (block.timestamp - stakedOnTimeStamp[msg.sender]) <= 2 days,
            "Cant be unstaked before 2days"
        );

        if ((block.timestamp - stakedOnTimeStamp[msg.sender]) <= 4 days) {
            require(
                (amount <= (balances[msg.sender] / 4)),
                "in 2-4 days - only  25% can be unstaked"
            );
            alreadyWithdrawn[msg.sender] = alreadyWithdrawn[msg.sender].add(
                amount
            );
            balances[msg.sender] = balances[msg.sender].sub(amount);
            token.transfer(msg.sender, amount);
            emit TokensUnstaked(msg.sender, amount);
        } else {
            revert(
                "Rest of Tokens are only available after 2 days of time period has elapsed"
            );
        }

        if ((block.timestamp - stakedOnTimeStamp[msg.sender]) <= 6 days) {
            require(
                (amount <= (balances[msg.sender] / 2)),
                "in 4-6 days - only  50% can be unstaked"
            );
            alreadyWithdrawn[msg.sender] = alreadyWithdrawn[msg.sender].add(
                amount
            );
            balances[msg.sender] = balances[msg.sender].sub(amount);
            token.transfer(msg.sender, amount);
            emit TokensUnstaked(msg.sender, amount);
        } else {
            revert(
                "Rest of Tokens are only available after 4 days of time period has elapsed"
            );
        }

        if ((block.timestamp - stakedOnTimeStamp[msg.sender]) <= 8 days) {
            require(
                (amount <= (((balances[msg.sender]) * 75) / 100)),
                "in 6-8 days - only  75% can be unstaked"
            );
            alreadyWithdrawn[msg.sender] = alreadyWithdrawn[msg.sender].add(
                amount
            );
            balances[msg.sender] = balances[msg.sender].sub(amount);
            token.transfer(msg.sender, amount);
            emit TokensUnstaked(msg.sender, amount);
        } else {
            revert(
                "Rest of Tokens are only available after 4 days of time period has elapsed"
            );
        }
    }

    function transferAccidentallyLockedTokens(IERC20 token, uint256 amount)
        public
        onlyOwner
    {
        require(address(token) != address(0), "Token address can not be zero");
        require(
            token != sushi,
            "Token address can not be ERC20 address which was passed into the constructor"
        );
        token.transfer(owner, amount);
    }
}
