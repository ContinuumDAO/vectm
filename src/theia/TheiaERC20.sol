// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TheiaERC20FeeConfig.sol";

contract TheiaERC20 is IERC20, TheiaERC20FeeConfig {
    using SafeERC20 for IERC20;
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    address public immutable underlying;
    bool public constant underlyingIsMinted = false;

    mapping(address => uint256) public override balanceOf;
    uint256 private _totalSupply;

    // init flag for setting immediate admin, needed for CREATE2 support
    bool private _init;

    // delay for timelock functions
    uint public constant DELAY = 1 days;

    // set of minters, can be this bridge or other bridges
    mapping(address => bool) public isMinter;
    address[] public minters;

    // primary controller of the token contract
    address public admin;

    address public pendingMinter;
    uint public delayMinter;

    address public pendingAdmin;
    uint public delayAdmin;

    modifier onlyMinter() {
        require(isMinter[msg.sender], "TheiaERC20: not Minter");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "TheiaERC20: not Admin");
        _;
    }

    function owner() external view returns (address) {
        return admin;
    }

    function initAdmin(address _admin) external onlyAdmin {
        require(_init);
        _init = false;
        admin = _admin;
        isMinter[_admin] = true;
        minters.push(_admin);
    }

    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "TheiaERC20: address(0)");
        pendingAdmin = _admin;
        delayAdmin = block.timestamp + DELAY;
    }

    function applyAdmin() external onlyAdmin {
        require(pendingAdmin != address(0) && block.timestamp >= delayAdmin);
        admin = pendingAdmin;

        pendingAdmin = address(0);
        delayAdmin = 0;
    }

    function setMinter(address _minter) external onlyAdmin {
        require(_minter != address(0), "TheiaERC20: address(0)");
        pendingMinter = _minter;
        delayMinter = block.timestamp + DELAY;
    }

    function applyMinter() external onlyAdmin {
        require(pendingMinter != address(0) && block.timestamp >= delayMinter);
        require(pendingMinter != address(0));
        isMinter[pendingMinter] = true;
        minters.push(pendingMinter);

        pendingMinter = address(0);
        delayMinter = 0;
    }

    // No time delay revoke minter emergency function
    function revokeMinter(address _minter) external onlyAdmin {
        isMinter[_minter] = false;
    }

    function getAllMinters() external view returns (address[] memory) {
        return minters;
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyMinter returns (bool) {
        _mint(to, amount);
        return true;
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyMinter returns (bool) {
        _burn(from, amount);
        return true;
    }

    mapping(address => mapping(address => uint256)) public override allowance;

    event LogSwapin(
        bytes32 indexed txhash,
        address indexed account,
        uint256 amount
    );
    event LogSwapout(
        address indexed account,
        address indexed bindaddr,
        uint256 amount
    );

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _underlying,
        address _admin
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
        // Use init to allow for CREATE2 accross all chains
        _init = true;

        admin = _admin;
        isMinter[_admin] = true;
        minters.push(_admin);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function deposit() external returns (uint256) {
        uint256 _amount = IERC20(underlying).balanceOf(msg.sender);
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
        return _deposit(_amount, msg.sender);
    }

    function deposit(uint256 amount) external returns (uint256) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        return _deposit(amount, msg.sender);
    }

    function deposit(uint256 amount, address to) external returns (uint256) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        return _deposit(amount, to);
    }

    function depositVault(
        uint256 amount,
        address to
    ) external onlyAdmin returns (uint256) {
        return _deposit(amount, to);
    }

    function _deposit(uint256 amount, address to) internal returns (uint256) {
        require(!underlyingIsMinted);
        require(underlying != address(0) && underlying != address(this));
        _mint(to, amount);
        return amount;
    }

    function withdraw() external returns (uint256) {
        return _withdraw(msg.sender, balanceOf[msg.sender], msg.sender);
    }

    function withdraw(uint256 amount) external returns (uint256) {
        return _withdraw(msg.sender, amount, msg.sender);
    }

    function withdraw(uint256 amount, address to) external returns (uint256) {
        return _withdraw(msg.sender, amount, to);
    }

    function withdrawVault(
        address from,
        uint256 amount,
        address to
    ) external onlyAdmin returns (uint256) {
        return _withdraw(from, amount, to);
    }

    function _withdraw(
        address from,
        uint256 amount,
        address to
    ) internal returns (uint256) {
        require(!underlyingIsMinted);
        require(underlying != address(0) && underlying != address(this));
        _burn(from, amount);
        IERC20(underlying).safeTransfer(to, amount);
        return amount;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 balance = balanceOf[account];
        require(balance >= amount, "ERC20: burn amount exceeds balance");

        balanceOf[account] = balance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        require(to != address(0) && to != address(this));
        uint256 balance = balanceOf[msg.sender];
        require(
            balance >= value,
            "TheiaERC20: transfer amount exceeds balance"
        );

        balanceOf[msg.sender] = balance - value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(to != address(0) && to != address(this));
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(
                    allowed >= value,
                    "TheiaERC20: request exceeds allowance"
                );
                uint256 reduced = allowed - value;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }

        uint256 balance = balanceOf[from];
        require(
            balance >= value,
            "TheiaERC20: transfer amount exceeds balance"
        );

        balanceOf[from] = balance - value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);

        return true;
    }

    function setFeeConfig(
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom // 1:from 2:to 0:free
    ) external onlyAdmin returns (bool) {
        return
            _setFeeConfig(
                srcChainID,
                dstChainID,
                maxFee,
                minFee,
                feeRate,
                payFrom
            );
    }

    function getFeeConfig(
        uint256 fromChainID,
        uint256 toChainID
    ) public view returns (uint256, uint256, uint256) {
        require(fromChainID > 0 || toChainID > 0, "FeeConfig: Invalid chainID");
        if (fromChainID > 0) {
            return getSwapInFeeConfig(fromChainID);
        } else {
            return getSwapOutFeeConfig(toChainID);
        }
    }
}
