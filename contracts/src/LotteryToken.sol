// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract LotteryToken is ERC20, ERC20Permit, ERC20Votes {
    // Constants
    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000e18; // 100M tokens
    uint256 public constant PREMINE_AMOUNT = 5_000_000e18; // 5% for initial LP

    // State
    address public miner;
    address public immutable deployer;
    bool public premineExecuted;

    // Errors
    error OnlyMiner();
    error OnlyDeployer();
    error MinerAlreadySet();
    error ZeroAddress();
    error MaxSupplyReached();
    error PremineAlreadyExecuted();

    modifier onlyMiner() {
        if (msg.sender != miner) revert OnlyMiner();
        _;
    }

    constructor() ERC20("LOTTERY", "LOTTERY") ERC20Permit("LOTTERY") {
        deployer = msg.sender;
    }

    function setMiner(address _miner) external {
        if (msg.sender != deployer) revert OnlyDeployer();
        if (miner != address(0)) revert MinerAlreadySet();
        if (_miner == address(0)) revert ZeroAddress();
        miner = _miner;
    }

    /// @notice One-time premine for initial LP. Mints directly to LP pair.
    /// @param lpPair The Uniswap V2 pair address to receive tokens
    function premineForLP(address lpPair) external {
        if (msg.sender != deployer) revert OnlyDeployer();
        if (premineExecuted) revert PremineAlreadyExecuted();
        if (lpPair == address(0)) revert ZeroAddress();

        premineExecuted = true;
        _mint(lpPair, PREMINE_AMOUNT);
    }

    function mint(address to, uint256 amount) external onlyMiner {
        if (totalSupply() + amount > MAX_TOTAL_SUPPLY) revert MaxSupplyReached();
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, amount);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }
}
