//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// import "hardhat/console.sol";

contract ERC20 {
    uint256 public totalSupply;
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;

        _mint(msg.sender, 100e18);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "ERC20: approve to zero address");

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transferFrom(
        address sender,
        address to,
        uint256 amount
    ) public returns (bool) {
        uint256 currentAllowance = allowance[sender][msg.sender];

        require(currentAllowance >= amount, "ERC20: allowance exceeded");

        allowance[sender][msg.sender] = currentAllowance - amount;

        emit Approval(sender, msg.sender, allowance[sender][msg.sender]);

        return _transfer(sender, to, amount);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function _transfer(
        address sender,
        address to,
        uint256 amount
    ) private returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");

        uint256 senderBalance = balanceOf[sender];

        require(senderBalance >= amount, "ERC20: balance exceeded");

        balanceOf[sender] = senderBalance - amount;

        balanceOf[to] = balanceOf[to] + amount;

        emit Transfer(sender, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to zero address");

        totalSupply = totalSupply + amount;
        balanceOf[to] = balanceOf[to] + amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address sender, uint256 amount) internal {
        require(sender != address(0), "ERC20: burn to zero address");

        totalSupply = totalSupply - amount;
        balanceOf[sender] = balanceOf[sender] - amount;
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(address sender, uint256 amount) public {
        require(balanceOf[sender] >= amount, "ERC20: balance exceeded");

        transfer(msg.sender, amount);

        address payable recipient = payable(msg.sender);

        _burn(msg.sender, amount);

        recipient.transfer(amount);

        emit Withdrawal(recipient, amount);
    }
}
