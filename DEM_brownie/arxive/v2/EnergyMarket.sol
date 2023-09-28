// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EnergyMarket is Ownable {
    // State variables
    uint256 public energyPrice;

    // Events
    event EnergyPriceUpdated(uint256 newEnergyPrice);

    constructor() {
        // Initialize energyPrice with a default value (e.g., 2000)
        energyPrice = 2000;
    }

    // Update the energy price
    function updateEnergyPrice(uint256 _newEnergyPrice) public onlyOwner {
        energyPrice = _newEnergyPrice;
        emit EnergyPriceUpdated(_newEnergyPrice);
    }

    // Add other functions related to energy market management below

    function matchProduction(uint256 tokenId, uint256 surplus) external {
    // Add your implementation here
}

}
