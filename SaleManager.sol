/**
 *Submitted for verification at BscScan.com on 2025-07-08
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-07-07
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-27
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-26
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-24
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}

interface IPancakeRouter {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract TokenSaleManager {
    struct Sale {
        address owner;
        address tokenCreator;
        address token;
        uint256 softCap;
        uint256 hardCap;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        bool saleEnded;
        bool liquidityAdded;
        bool feesClaimed;
        uint256 duration;
        address[] buyerList;
        mapping(address => uint256) contributions;
    }

    mapping(address => Sale) private sales;
    mapping(address => bool) private deployFeeClaimed;
    mapping(address => bool) public dgdRewarded;
    mapping(address => uint256) public dgdAcquired;

    address[] public tokenList;
    IPancakeRouter public router;
    address public immutable contractOwner;
    address public immutable DGD_TOKEN = 0x08feBf3667a134A4f8D12E2845CddE5e0C23a2AE;
    uint256 public minSoftCapForReward = 10 ether;



    uint256 public constant TOKEN_DECIMALS = 1e18;
    uint256 public constant TOTAL_TOKENS = 1_000_000_000 * TOKEN_DECIMALS;
    uint256 public constant STAKE_TOKENS = 50_000_000 * TOKEN_DECIMALS;
    uint256 public constant FUNDRAISE_TOKENS = 760_000_000 * TOKEN_DECIMALS;
    uint256 public constant LP_TOKENS = 190_000_000 * TOKEN_DECIMALS;
    address public constant STAKE_CONTRACT = 0x47f603d108b488855de90A032D19287F2dC91959;
    address public constant CREATOR_ADDRESS = 0x15AAa61796B8528375f120B4CF09f682260B4981;

    event SaleCreated(address indexed token, address indexed owner, address indexed tokenCreator);
    event TokensPurchased(address indexed buyer, address indexed token, uint256 bnbAmount);
    event TokensClaimed(address indexed user, address indexed token, uint256 tokenAmount);
    event RefundClaimed(address indexed user, address indexed token, uint256 bnbAmount);
    event DGDRewarded(address indexed token, address indexed recipient, uint256 amount);


    constructor(address _router) {
        router = IPancakeRouter(_router);
        contractOwner = msg.sender;
    }

    function setRouter(address newRouter) external {
        require(msg.sender == contractOwner, "Only contract owner");
        router = IPancakeRouter(newRouter);
    }

    function createSale(
        address token,
        address tokenCreator,
        uint256 softCap,
        uint256 hardCap,
        uint256 duration
    ) external {
        require(sales[token].token == address(0), "Sale exists");
        require(softCap > 0 && hardCap >= softCap, "Invalid caps");
        require(duration > 0, "Invalid duration");

        Sale storage s = sales[token];
        s.token = token;
        s.owner = msg.sender;
        s.tokenCreator = tokenCreator;
        s.softCap = softCap;
        s.hardCap = hardCap;
        s.startTime = block.timestamp;
        s.endTime = block.timestamp + duration;
        s.duration = duration;

        tokenList.push(token);
        emit SaleCreated(token, msg.sender, tokenCreator);
    }

    function buyTokens(address token) external payable {
        Sale storage s = sales[token];
        require(block.timestamp >= s.startTime && block.timestamp <= s.endTime, "Sale inactive");
        require(!s.saleEnded, "Sale ended");
        require(msg.value > 0, "No BNB sent");
        require(s.totalRaised + msg.value <= s.hardCap, "Exceeds hardcap");

        if (s.contributions[msg.sender] == 0) {
            s.buyerList.push(msg.sender);
        }

        s.contributions[msg.sender] += msg.value;
        s.totalRaised += msg.value;

        emit TokensPurchased(msg.sender, token, msg.value);
    }

    function endSale(address token) external {
        Sale storage s = sales[token];
        require(
            msg.sender == s.owner || msg.sender == contractOwner,
            "Not authorized"
        );
        require(!s.saleEnded, "Already ended");
        require(block.timestamp > s.endTime || s.totalRaised == s.hardCap, "Too early");

        s.saleEnded = true;
    }

    function addLiquidity(address token) external {
        Sale storage s = sales[token];
        require(
            msg.sender == s.owner || msg.sender == contractOwner,
            "Not authorized"
        );
        require(s.saleEnded, "Sale not ended");
        require(!s.liquidityAdded, "Liquidity already added");

        uint256 bnbAmount = (s.totalRaised * 90) / 100;
        uint256 tokenAmount = (LP_TOKENS * s.totalRaised) / s.hardCap;
        require(IERC20(token).approve(address(router), tokenAmount), "Approve failed");

        router.addLiquidityETH{value: bnbAmount}(
            token,
            tokenAmount,
            0,
            0,
            address(0x000000000000000000000000000000000000dEaD),
            block.timestamp
        );

        s.liquidityAdded = true;
    }

    function distributeDeployFees() external {
        for (uint i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            if (deployFeeClaimed[token]) continue;

            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            if (tokenBalance >= STAKE_TOKENS) {
                require(IERC20(token).transfer(STAKE_CONTRACT, STAKE_TOKENS), "Stake transfer failed");
                deployFeeClaimed[token] = true;
            }
        }
    }

    function claimTokens(address token) external {
        Sale storage s = sales[token];
        require(s.saleEnded, "Sale not ended");
        require(s.totalRaised >= s.softCap, "Softcap not met");

        uint256 contributed = s.contributions[msg.sender];
        require(contributed > 0, "No contribution");

        uint256 tokenAmount = (contributed * FUNDRAISE_TOKENS) / s.totalRaised;
        s.contributions[msg.sender] = 0;
        require(IERC20(token).transfer(msg.sender, tokenAmount), "Transfer failed");

        emit TokensClaimed(msg.sender, token, tokenAmount);
    }

    function claimRefund(address token) external {
        Sale storage s = sales[token];
        require(s.saleEnded, "Sale not ended");
        require(s.totalRaised < s.softCap, "Softcap met");

        uint256 amount = s.contributions[msg.sender];
        require(amount > 0, "No contribution");

        s.contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit RefundClaimed(msg.sender, token, amount);
    }
    
    function distributeDGDRewards() external {
    bool isOwner = msg.sender == contractOwner;
    bool isAuthorized = false;

    for (uint256 i = 0; i < tokenList.length; i++) {
        address token = tokenList[i];
        Sale storage s = sales[token];

        if (
            msg.sender == s.owner &&
            s.liquidityAdded &&
            !dgdRewarded[token] &&
            s.softCap >= minSoftCapForReward
        ) {
            isAuthorized = true;
            break;
        }
    }

    require(isOwner || isAuthorized, "Not authorized");

    for (uint256 i = 0; i < tokenList.length; i++) {
        address token = tokenList[i];
        Sale storage s = sales[token];

        if (
            s.liquidityAdded &&
            !dgdRewarded[token] &&
            s.softCap >= minSoftCapForReward &&
            (isOwner || msg.sender == s.owner)
        ) {
            uint256 rewardAmount = 1000 * 1e18 + (
                uint256(keccak256(abi.encodePacked(block.timestamp, token, i))) % (9001 * 1e18)
            );

            require(IERC20(DGD_TOKEN).transfer(s.owner, rewardAmount), "Reward transfer failed");

            dgdAcquired[s.owner] += rewardAmount;
            dgdRewarded[token] = true;
            emit DGDRewarded(token, s.owner, rewardAmount);
        }
    }
}




    function withdrawBNB() external {
        require(msg.sender == contractOwner, "Not contract owner");
        payable(msg.sender).transfer(address(this).balance);
    }

    

    function getSale(address token) external view returns (
        address owner,
        address tokenCreator,
        uint256 softCap,
        uint256 hardCap,
        uint256 totalRaised,
        bool ended,
        bool liquidity,
        uint256 duration
    ) {
        Sale storage s = sales[token];
        return (
            s.owner,
            s.tokenCreator,
            s.softCap,
            s.hardCap,
            s.totalRaised,
            s.saleEnded,
            s.liquidityAdded,
            s.duration
        );
    }

    function getTopBuyers(address token) external view returns (
        address[] memory buyers,
        uint256[] memory bnbAmounts,
        uint256[] memory tokenPercents
    ) {
        Sale storage s = sales[token];
        uint256 count = s.buyerList.length;
        buyers = new address[](count);
        bnbAmounts = new uint256[](count);
        tokenPercents = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address buyer = s.buyerList[i];
            uint256 contributed = s.contributions[buyer];

            buyers[i] = buyer;
            bnbAmounts[i] = contributed;
            tokenPercents[i] = s.totalRaised > 0
                ? (contributed * 10000) / s.totalRaised
                : 0;
        }
    }

    function getSaleProgress(address token) external view returns (
        uint256 buyerCount,
        uint256 totalBNB,
        uint256 tokenPercent
    ) {
        Sale storage s = sales[token];
        buyerCount = s.buyerList.length;
        totalBNB = s.totalRaised;
        tokenPercent = s.totalRaised > 0
            ? (s.totalRaised * 10000) / s.hardCap
            : 0;
    }

    function getSaleEndIn(address token) external view returns (uint256 secondsLeft) {
        Sale storage s = sales[token];
        if (block.timestamp >= s.endTime || s.saleEnded) {
            return 0;
        }
        return s.endTime - block.timestamp;
    }
    function setMinSoftCapForReward(uint256 _minSoftCap) external {
    require(msg.sender == contractOwner, "Only owner");
    minSoftCapForReward = _minSoftCap;
}

}