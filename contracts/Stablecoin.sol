// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.3.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts@4.3.2/access/Ownable.sol";

contract StableCoin is
    ERC20, ERC20Burnable, ERC20Snapshot, Ownable
{
    

    // Events Emitted
    event Constructed(
        string tokenName,
        string tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address complianceManager,
        address enforcementManager
    );


    // ERC20+
    event Wipe(address account, uint256 amount);
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);
    event Transfer(address sender, address recipient, uint256 amount);
    event Approve(address sender, address spender, uint256 amount);
    event IncreaseAllowance(address sender, address spender, uint256 amount);
    event DecreaseAllowance(address sender, address spender, uint256 amount);

    // KYC
    event Freeze(address account); // Freeze: Freeze this account
    event Unfreeze(address account);

    // Halt
    event Pause(address sender); // Pause: Pause entire contract
    event Unpause(address sender);

    // "External Transfer"
    // Signify to the coin bridge to perform external transfer
    event ApproveExternalTransfer(
        address from,
        string networkURI,
        bytes to,
        uint256 amount
    );
    event ExternalTransfer(
        address from,
        string networkURI,
        bytes to,
        uint256 amount
    );
    event ExternalTransferFrom(
        bytes from,
        string networkURI,
        address to,
        uint256 amount
    );

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address complianceManager,
        address enforcementManager
    ) public ERC20(tokenName, tokenSymbol, tokenDecimal) {
        _supplyManager = supplyManager;
        _complianceManager = complianceManager;
        _enforcementManager = enforcementManager;

        mint(totalSupply); // Emits Mint

        // Did it
        emit Constructed(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            totalSupply,
            supplyManager,
            complianceManager,
            enforcementManager
        );
    }

    // Wipe
    function wipe(address account, uint256 amount) public onlyEnforcementManager {
        uint256 balance = balanceOf(account);
        require(
            amount <= balance,
            "Amount cannot be greater than balance"
        );
        super._transfer(account, _supplyManager, amount);
        _burn(_supplyManager, amount);
        emit Wipe(account, amount);
    }

    /*
     * Transfers
     */

    // Mint
    function mint(uint256 amount) public onlySupplyManager {
        _mint(supplyManager(), amount);
        emit Mint(_msgSender(), amount);
    }

    // Burn
    function burn(uint256 amount) public onlySupplyManager {
        _burn(_supplyManager, amount);
        emit Burn(_msgSender(), amount);
    }


    function transfer(address to, uint256 amount) public override(ERC20) {
        super._transfer(_msgSender(), to, amount);
        emit Transfer(_msgSender(), to, amount);
    }

    /*
     * External Transfers
     */

    // approve an allowance for transfer to an external network
    function approveExternalTransfer(
        string memory networkURI,
        bytes memory externalAddress,
        uint256 amount
    )
        public
        override(ExternallyTransferable)
        requiresKYC
        requiresNotFrozen
        whenNotPaused
    {
        require(
            amount <= balanceOf(_msgSender()),
            "Cannot approve more than balance."
        );
        super.approveExternalTransfer(networkURI, externalAddress, amount);
        emit ApproveExternalTransfer(
            _msgSender(),
            networkURI,
            externalAddress,
            amount
        );
    }


    function externalTransferFrom(
        bytes memory from,
        string memory networkURI,
        address to,
        uint256 amount
    ) public override(ExternallyTransferable) onlySupplyManager whenNotPaused {
        require(isKycPassed(to), "Recipient account requires KYC to continue.");
        require(!isFrozen(to), "Recipient account is frozen.");
        _mint(_supplyManager, amount);
        super._transfer(_supplyManager, to, amount);
        emit ExternalTransferFrom(from, networkURI, to, amount);
    }


    // Transfer From (allowance --> user)
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20) requiresKYC requiresNotFrozen {
        super.transferFrom(from, to, amount);
        emit Transfer(from, to, amount);
        emit Approve(from, _msgSender(), allowance(from, _msgSender()));
    }


}