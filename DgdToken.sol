/**
 *Submitted for verification at BscScan.com on 2025-07-08
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Ownable
contract Ownable {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid");
        owner = newOwner;
    }
}

/// @dev ERC20
contract ERC20 is Ownable {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Not enough balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _beforeTokenTransfer(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _beforeTokenTransfer(from, to, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/// @dev Token
contract DegenDappToken is ERC20 {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    bool public globalTransferEnabled = false;
    uint256 public unlockTime;

    mapping(address => bool) public whitelist;
    mapping(address => VestingSchedule) public vesting;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 duration;
    }

    constructor(uint256 _unlockTime) ERC20("DegenDapp", "DGD") {
        unlockTime = _unlockTime;
        _mint(msg.sender, MAX_SUPPLY);
    }

    // ========== Lock Logic ==========
    function enableGlobalTransfer() external onlyOwner {
        globalTransferEnabled = true;
    }

    function disableGlobalTransfer() external onlyOwner {
        globalTransferEnabled = false;
    }

    function addToWhitelist(address wallet) external onlyOwner {
        whitelist[wallet] = true;
    }

    function removeFromWhitelist(address wallet) external onlyOwner {
        whitelist[wallet] = false;
    }

    function isUnlocked() public view returns (bool) {
        return globalTransferEnabled || block.timestamp >= unlockTime;
    }

    // ========== Vesting Logic ==========
    function setVesting(
        address wallet,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        require(totalAmount > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");
        require(startTime >= block.timestamp, "Start in future");

        vesting[wallet] = VestingSchedule({
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: startTime,
            duration: duration
        });
    }

    function claimVestedTokens() external {
        VestingSchedule storage v = vesting[msg.sender];
        require(v.totalAmount > 0, "No vesting schedule");

        uint256 elapsed = block.timestamp > v.startTime
            ? block.timestamp - v.startTime
            : 0;

        uint256 totalUnlocked = v.totalAmount * elapsed / v.duration;
        if (totalUnlocked > v.totalAmount) totalUnlocked = v.totalAmount;

        uint256 claimable = totalUnlocked - v.claimedAmount;
        require(claimable > 0, "Nothing to claim");

        v.claimedAmount += claimable;
        _transfer(owner, msg.sender, claimable);
    }

    
   function _beforeTokenTransfer(address from, address to, uint256 /* amount */) internal override {
    if (from == address(0) || to == address(0)) return; // mint/burn

    if (!isUnlocked()) {
        require(whitelist[from] || whitelist[to], "Transfers are locked");
    }
}

}