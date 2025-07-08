/**
 *Submitted for verification at BscScan.com on 2025-07-08
*/

/**
 *Submitted for verification at testnet.bscscan.com on 2025-06-10
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ========== CustomToken contract ==========
contract CustomToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public owner;
    address public stakingContract;
    address public tokenSaleContract;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _stakingContract,
        address _tokenSaleContract
    ) {
        name = _name;
        symbol = _symbol;
        owner = _owner;
        stakingContract = _stakingContract;
        tokenSaleContract = _tokenSaleContract;

        totalSupply = 1_000_000_000 * 10**uint256(decimals);
        balanceOf[address(this)] = totalSupply;
        emit Transfer(address(0), address(this), totalSupply);

        _transfer(address(this), tokenSaleContract, totalSupply);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(allowance[sender][msg.sender] >= amount, "Not enough allowance");
        allowance[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(balanceOf[sender] >= amount, "Not enough balance");
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
}

// ========== TokenFactory contract ==========
contract TokenFactory {
    address[] public allTokens;

    event TokenCreated(address indexed token, string name, string symbol, address indexed creator);

    function createToken(
        string memory name,
        string memory symbol,
        address stakingContract,
        address tokenSaleContract
    ) external returns (address) {
        CustomToken token = new CustomToken(
            name,
            symbol,
            msg.sender,
            stakingContract,
            tokenSaleContract
        );

        allTokens.push(address(token));
        emit TokenCreated(address(token), name, symbol, msg.sender);
        return address(token);
    }

    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }
}