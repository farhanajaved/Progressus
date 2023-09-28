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

    mapping(uint256 => uint256) public tokenIdToPoolId;
    mapping(uint256 => address) public poolIdToOwner;
    mapping(uint256 => uint256) public poolIdToTokenId;

    uint256 public totalEnergyProduced;
    uint256 public totalEnergyConsumed;
    mapping(uint256 => uint256) public intervalEnergyProduced;
    mapping(uint256 => uint256) public intervalEnergyConsumed;
    uint256 public intervalDuration = 300; // 5 minutes in seconds
    // Step 3: Constructor
    constructor(
    address energyProfileContractAddress,
    address energyMarketContractAddress,
    address energyPriceOracleAddress
    ){
    _energyProfileContract = EnergyProfile(energyProfileContractAddress);
    _energyMarketContract = EnergyMarket(energyMarketContractAddress);
    _energyPriceOracle = AggregatorV2V3Interface(energyPriceOracleAddress);
    }
    event Deposit(address indexed user, uint256 tokenId, uint256 poolId);
    event Withdraw(address indexed user, uint256 tokenId, uint256 poolId);
    event MarketPriceUpdated(uint256 newEnergyPrice);
    event ProductionMatched(uint256 indexed tokenId, uint256 energyAmount);

        // Step 4: Deposit function
    // Allows users to deposit their EnergyProfile NFTs into the pool
    function deposit(uint256 tokenId) public {
        _poolIdCounter.increment();
        uint256 poolId = _poolIdCounter.current();

        IERC721(_energyProfileContract).transferFrom(msg.sender, address(this), tokenId);

        tokenIdToPoolId[tokenId] = poolId;
        poolIdToOwner[poolId] = msg.sender;
        poolIdToTokenId[poolId] = tokenId;

        emit Deposit(msg.sender, tokenId, poolId);
    }

    // Step 5: Withdraw function
    // Allows users to withdraw their EnergyProfile NFTs from the pool
    function withdraw(uint256 tokenId) public {
        uint256 poolId = tokenIdToPoolId[tokenId];
        require(poolIdToOwner[poolId] == msg.sender, "Not the owner of the token");

        IERC721(_energyProfileContract).transferFrom(address(this), msg.sender, tokenId);

        delete tokenIdToPoolId[tokenId];
        delete poolIdToOwner[poolId];
        delete poolIdToTokenId[poolId];

        emit Withdraw(msg.sender, tokenId, poolId);
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
//    Define update interval energy function
    function updateIntervalEnergy(uint256 tokenId) public {
        uint256 poolId = tokenIdToPoolId[tokenId];
        require(poolIdToOwner[poolId] == msg.sender, "Not the owner of the token");

        EnergyProfile.UserData memory userData = _energyProfileContract.getUserProfile(tokenId);

        uint256 currentInterval = block.timestamp / intervalDuration;

       if (keccak256(bytes(userData.energyType)) == keccak256(bytes("producer"))) {

            totalEnergyProduced += userData.energyProduced;
            intervalEnergyProduced[currentInterval] += userData.energyProduced;
        } else {
            totalEnergyConsumed += userData.energyConsumed;
            intervalEnergyConsumed[currentInterval] += userData.energyConsumed;
        }
    }

//    Step 8: Define settle interval function
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
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % _poolIdCounter.current();
        uint256 randomTokenId = poolIdToTokenId[randomIndex + 1];
        return randomTokenId;
    }


    // Function to be called by a Chainlink oracle that activates the contract
    function oracleActivation() external {
        // Oracle activation logic here
    }
}
