// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    // State variable to store a value
    uint256 private s_value;

    // Event to broadcast the new value
    event ValueChanged(uint256 newValue);

    constructor(address initialOwner) Ownable(initialOwner) {
        // Your constructor code here
    }

    // Store a new value in the contract
    function store(uint256 newValue) public onlyOwner {
        s_value = newValue;
        emit ValueChanged(newValue);
    }

    // Read the last stored value
    function getValue() external view returns (uint256) {
        return s_value;
    }
}
