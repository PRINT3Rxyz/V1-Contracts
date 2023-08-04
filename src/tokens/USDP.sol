// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./interfaces/IUSDP.sol";
import "./YieldToken.sol";

contract USDP is YieldToken, IUSDP {
    mapping(address => bool) public vaults;

    modifier onlyVault() {
        require(vaults[msg.sender], "USDP: forbidden");
        _;
    }

    constructor(address _vault) YieldToken("USD PRINT3R", "USDP", 0) {
        vaults[_vault] = true;
    }

    function addVault(address _vault) external override onlyGov {
        vaults[_vault] = true;
    }

    function removeVault(address _vault) external override onlyGov {
        vaults[_vault] = false;
    }

    function mint(address _account, uint256 _amount) external override onlyVault {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override onlyVault {
        _burn(_account, _amount);
    }
}
