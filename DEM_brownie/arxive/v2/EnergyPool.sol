// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyProfile.sol";
import "./EnergyMarket.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract EnergyPool is Ownable {
    // State variables here
    using Counters for Counters.Counter;
    Counters.Counter private _poolIdCounter;

        // Added explicit visibility to state variables
    EnergyProfile private _energyProfileContract;
    EnergyMarket private _energyMarketContract;
    AggregatorV2V3Interface private _energyPriceOracle;


    uint256 public totalEnergyProduced;
    uint256 public totalEnergyConsumed;
    uint256 public numberOfDeposits = 0;
    mapping(uint256 => uint256) public intervalEnergyProduced;
    mapping(uint256 => uint256) public intervalEnergyConsumed;
    uint256 public intervalDuration = 295; //  blocks ~ 1 hour
    uint256 public current_block_number;
    // Step 3: Constructor
    constructor(
    address energyProfileContractAddress,
    address energyMarketContractAddress,
    address energyPriceOracleAddress
    ){
    _energyProfileContract = EnergyProfile(energyProfileContractAddress);
    _energyMarketContract = EnergyMarket(energyMarketContractAddress);
    _energyPriceOracle = AggregatorV2V3Interface(energyPriceOracleAddress);
    current_block_number = block.number;
    }
    struct Interval {
    uint256 energyProduced;
    uint256 energyConsumed;
    }
    mapping(uint256 => Interval) public intervals;

    event Deposit(address indexed user, uint256 tokenId);
    event Withdraw(address indexed user, uint256 tokenId);
    event MarketPriceUpdated(uint256 newEnergyPrice);
    event ProductionMatched(uint256 indexed tokenId, uint256 energyAmount);
    event EnergyIntervalUpdated(uint256 indexed tokenId, uint256 totalEnergyProduced, uint256 totalEnergyConsumed, uint256 intervalEnergyProduced, uint256 intervalEnergyConsumed);


    // Step 4: Deposit function
    // Allows users to deposit their EnergyProfile NFTs into the pool
    function deposit(uint256 tokenId) public {
        require(IERC721(_energyProfileContract).ownerOf(tokenId) == msg.sender, "Not the owner of the token");

        EnergyProfile.Commitment[] memory commitments = _energyProfileContract.getUserCommitments(tokenId);

        for (uint i = 0; i < commitments.length; i++) {
            updateIntervalEnergy(tokenId, i);
        }

        numberOfDeposits += 1;
        emit Deposit(msg.sender, tokenId);
    }


    // Step 5: Withdraw function
    // Allows users to withdraw their EnergyProfile NFTs from the pool
    function withdraw(uint256 tokenId) public {
        require(IERC721(_energyProfileContract).ownerOf(tokenId) == msg.sender, "Not the owner of the token");
//        IERC721(_energyProfileContract).approve(address(0), tokenId);
        numberOfDeposits--;
        emit Withdraw(msg.sender, tokenId);
    }



    // Step 6: Update market status
    //     Fetches the latest energy price from the Chainlink Oracle
    //    Updates the energy market price in the EnergyMarket contract
    //    Emits a MarketPriceUpdated event
    function updateMarketPrice() public {
        (, int256 energyPrice, , ,) = _energyPriceOracle.latestRoundData();
        require(energyPrice >= 0, "Invalid energyPrice value from oracle");
        uint256 newEnergyPrice = uint256(energyPrice);

        _energyMarketContract.updateEnergyPrice(newEnergyPrice);

        emit MarketPriceUpdated(newEnergyPrice);
    }

    // Step 8: Match producer and consumer
    // Matches energy production with consumption
    function matchProducerConsumer() internal {
        // Match producer and consumer logic here
    }

    // Step 9: Define settle interval function
    function settleInterval() public {
        uint256 currentInterval = block.timestamp / intervalDuration;
        uint256 intervalSurplus = intervalEnergyProduced[currentInterval] - intervalEnergyConsumed[currentInterval];

        if (intervalSurplus > 0) {
            uint256 randomTokenId = _selectRandomTokenId();
            _energyMarketContract.matchProduction(randomTokenId, intervalSurplus);
            emit ProductionMatched(randomTokenId, intervalSurplus);
        }

        // Reset interval energy
        intervalEnergyProduced[currentInterval] = 0;
        intervalEnergyConsumed[currentInterval] = 0;
    }

    function _selectRandomTokenId() private view returns (uint256) {
        // Assuming that the tokenIds are sequential and start from 1.
        require(numberOfDeposits > 0, "No tokens to select from");
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % numberOfDeposits;
        uint256 randomTokenId = _energyProfileContract.tokenOfOwnerByIndex(address(this), randomIndex);
        return randomTokenId;
    }



    // Function to be called by a Chainlink oracle that activates the contract
    function oracleActivation() external {
        // Oracle activation logic here
    }
//     update energy interval
    function updateIntervalEnergy(uint256 tokenId, uint256 commitmentIndex) internal {
        EnergyProfile.UserData memory userData = _energyProfileContract.getUserProfile(tokenId);
        EnergyProfile.Commitment memory commitment = _energyProfileContract.getUserCommitments(tokenId)[commitmentIndex];

        // Check if the commitment has been processed by the energy pool
        require(!commitment.energy_pool_processed, "Commitment has already been processed by the energy pool");

        uint256 currentInterval = block.timestamp / intervalDuration;

        if (commitment.isProduction) {
            totalEnergyProduced += commitment.energyAmount;
            intervals[currentInterval].energyProduced += commitment.energyAmount;
        } else {
            totalEnergyConsumed += commitment.energyAmount;
            intervals[currentInterval].energyConsumed += commitment.energyAmount;
        }

        // Mark the commitment as processed by the energy pool
        _energyProfileContract.setCommitmentProcessed(tokenId, commitmentIndex, true);
    }


}
