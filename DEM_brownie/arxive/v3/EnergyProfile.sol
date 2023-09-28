// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract EnergyProfile is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    AggregatorV2V3Interface private _energyProducedOracle;
    AggregatorV2V3Interface private _energyConsumedOracle;
    AggregatorV2V3Interface private _energyPriceOracle;
    // Add the EnergyPool contract address as a state variable
    address private _energyPoolContract;
    // Add the EnergyMarket contract address as a state variable
    address private _energyMarketContract;
    mapping(uint256 => uint256) private _currentCommitmentIndex;
    constructor(
        address energyProducedOracleAddress,
        address energyConsumedOracleAddress,
        address energyPriceOracleAddress
    ) ERC721("EnergyProfile", "EP") {
        _energyProducedOracle = AggregatorV2V3Interface(energyProducedOracleAddress);
        _energyConsumedOracle = AggregatorV2V3Interface(energyConsumedOracleAddress);
        _energyPriceOracle = AggregatorV2V3Interface(energyPriceOracleAddress);

    }
    struct UserData {
        uint256 collateral;
        uint256 energyProduced;
        uint256 energyConsumed;
        uint256 maxCommitment;
        uint256 energyPrice;
        string location;
        string energyType;
        uint256 historicalPerformance;
    }

    struct Commitment {
        uint256 energyAmount;
        bool isProduction;
        uint256 startBlock; // Add this line
        uint256 duration;
        bool settled;
        bool energy_pool_processed;
        bool energy_market_processed;
    }

    mapping(uint256 => UserData) private _userProfiles;
    mapping(uint256 => Commitment[]) public _userCommitments;

    event UserRegistered(address indexed user, uint256 tokenId);
    event CommitmentCreated(uint256 indexed tokenId, Commitment commitment);
    event EnergyDataUpdated(uint256 indexed tokenId, uint256 energyProduced, uint256 energyConsumed);
    event EnergyPriceUpdated(uint256 indexed tokenId, uint256 newEnergyPrice);

    function registerUser(
        address user,
        uint256 collateral,
        string memory location,
        string memory energyType
    ) public {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _mint(user, tokenId);
        _userProfiles[tokenId] = UserData(
            collateral,
            0,
            0,
            1000,
            0,
            location,
            energyType,
            100
        );
        emit UserRegistered(user, tokenId);
    }



    function getUserProfile(uint256 tokenId) public view returns (UserData memory) {
        return _userProfiles[tokenId];
    }

//    function createCommitment(
//        uint256 tokenId,
//        uint256 energyAmount,
//        bool isProduction,
//        uint256 duration
//    ) public {
//        // Check if the sender is the owner of the token
//        require(ownerOf(tokenId) == msg.sender, "Only the owner of the token can add a commitment");
//
//        UserData storage userData = _userProfiles[tokenId];
//        require(energyAmount <= userData.maxCommitment, "Energy amount exceeds maximum commitment");
//
//        Commitment memory newCommitment = Commitment({
//            energyAmount: energyAmount,
//            isProduction: isProduction,
//            startBlock: block.number,
//            duration: duration,
//            settled: false, // Set the settled status to false initially
//            energy_pool_processed: false,
//            energy_market_processed: false
//        });
//
//        // If the user has more than 3 commitments, remove the oldest one
//        if (_userCommitments[tokenId].length > 2) {
//            for (uint i = 0; i < _userCommitments[tokenId].length - 1; i++) {
//                _userCommitments[tokenId][i] = _userCommitments[tokenId][i + 1];
//            }
//            _userCommitments[tokenId][_userCommitments[tokenId].length - 1] = newCommitment;
//        } else {
//            _userCommitments[tokenId].push(newCommitment);
//        }
//
//        emit CommitmentCreated(tokenId, newCommitment);
//    }
//--------------------------------- v2
//    function createCommitment(
//        uint256 tokenId,
//        uint256 energyAmount,
//        bool isProduction,
//        uint256 duration
//    ) public {
//        // Check if the sender is the owner of the token
//        require(ownerOf(tokenId) == msg.sender, "Only the owner of the token can add a commitment");
//
//        UserData storage userData = _userProfiles[tokenId];
//        require(energyAmount <= userData.maxCommitment, "Energy amount exceeds maximum commitment");
//
//        Commitment memory newCommitment = Commitment({
//            energyAmount: energyAmount,
//            isProduction: isProduction,
//            startBlock: block.number,
//            duration: duration,
//            settled: false, // Set the settled status to false initially
//            energy_pool_processed: false,
//            energy_market_processed: false
//        });
//
//        // If the user has more than 3 commitments, replace the first settled one
//        if (_userCommitments[tokenId].length > 2) {
//            bool replaced = false;
//            for (uint i = 0; i < _userCommitments[tokenId].length; i++) {
//                // Check if the commitment is settled or the duration has passed
//                if (_userCommitments[tokenId][i].settled || block.number > _userCommitments[tokenId][i].startBlock + _userCommitments[tokenId][i].duration) {
//                    _userCommitments[tokenId][i] = newCommitment;
//                    replaced = true;
//                    break;
//                }
//            }
//            require(replaced, "No settled commitment found to replace");
//        } else {
//            _userCommitments[tokenId].push(newCommitment);
//        }
//
//        emit CommitmentCreated(tokenId, newCommitment);
//    }
//    -------------------- v3
    function createCommitment(
        uint256 tokenId,
        uint256 energyAmount,
        bool isProduction,
        uint256 duration
    ) public returns (uint256) { // <- Change: added 'returns (uint256)'
        // Check if the sender is the owner of the token or the EnergyPool contract
        require(
            ownerOf(tokenId) == msg.sender || msg.sender == _energyPoolContract,
            "Only the owner of the token or the EnergyPool contract can add a commitment"
        );
        UserData storage userData = _userProfiles[tokenId];
        // Check if the sender is the owner of the token or the EnergyPool contract

//        require(energyAmount <= userData.maxCommitment, "Energy amount exceeds maximum commitment");

        Commitment memory newCommitment = Commitment({
            energyAmount: energyAmount,
            isProduction: isProduction,
            startBlock: block.number,
            duration: duration,
            settled: false, // Set the settled status to false initially
            energy_pool_processed: false,
            energy_market_processed: false
        });

        uint256 newCommitmentIndex; // <- Change: added this line

        // If the user has more than 3 commitments, replace the first settled one
        if (_userCommitments[tokenId].length > 2) {
            bool replaced = false;
            for (uint i = 0; i < _userCommitments[tokenId].length; i++) {
                // Check if the commitment is settled or the duration has passed
                if (_userCommitments[tokenId][i].settled || block.number > _userCommitments[tokenId][i].startBlock + _userCommitments[tokenId][i].duration) {
                    _userCommitments[tokenId][i] = newCommitment;
                    replaced = true;
                    newCommitmentIndex = i; // <- Change: added this line
                    break;
                }
            }
            require(replaced, "No settled commitment found to replace");
        } else {
            _userCommitments[tokenId].push(newCommitment);
            newCommitmentIndex = _userCommitments[tokenId].length - 1; // <- Change: added this line
        }

        emit CommitmentCreated(tokenId, newCommitment);

        return newCommitmentIndex; // <- Change: added this line
    }

//    function updateDepositedProfile(
//        uint256 tokenId,
//        uint256 energyAmount,
//        bool isProduction,
//        uint256 duration
//    ) public returns (uint256) {
//        // Check if the sender is the EnergyPool contract
//        require(msg.sender == _energyPoolContract, "Only the EnergyPool contract can update the profile");
//
//        // Check if the token has been deposited to the EnergyPool contract
////        require(ownerOf(tokenId) == _energyPoolContract, "Token is not deposited in the EnergyPool");
//
//        // Call createCommitment on the EnergyProfile contract and return the commitment index
//        uint256 commitmentIndex = createCommitment(tokenId, energyAmount, isProduction, duration);
//
//        return commitmentIndex;
//    }




    //     to debug the issue, we can add a function to return the length of the commitments array
    function getCommitmentsLength(uint256 tokenId) external view returns (uint256) {
    return _userCommitments[tokenId].length;
    }

    function setEnergyPoolContract(address energyPoolContract) external onlyOwner {
        _energyPoolContract = energyPoolContract;
    }


        // Update the setCommitmentSettled function to include the required logic: change by
        //EnergyPool contract or timeout
    function setCommitmentSettled(uint256 tokenId, uint256 commitmentIndex, bool settledStatus) external {

        Commitment storage commitment = _userCommitments[tokenId][commitmentIndex];

        // Check if the sender is the EnergyPool contract or if the timeout condition has been met
        require(
//            msg.sender == _energyPoolContract || block.timestamp >= commitment.startBlock  + commitment.duration,
            msg.sender == _energyPoolContract,
            "Only EnergyPool contract or when the timeout is reached can update the settled status"
        );

        commitment.settled = settledStatus;
    }
    function setCommitmentProcessed(uint256 tokenId, uint256 commitmentIndex, bool processedStatus) external {
        Commitment storage commitment = _userCommitments[tokenId][commitmentIndex];

        // Check if the sender is the EnergyPool contract or EnergyMarket contract
        require(
            msg.sender == _energyPoolContract || msg.sender == _energyMarketContract,
            "Only EnergyPool contract or EnergyMarket contract can update the processed status"
        );
        commitment.energy_pool_processed = processedStatus;
    }
    function getUserCommitments(uint256 tokenId) public view returns (Commitment[] memory) {
        return _userCommitments[tokenId];
    }
//    set energy_market_processed from the commitment  to True
    function setMarketProcessed(uint256 tokenId, uint256 commitmentIndex, bool processedStatus) external {
        Commitment storage commitment = _userCommitments[tokenId][commitmentIndex];

        // Check if the sender is the EnergyMarket contract
//        require(
//            msg.sender == _energyMarketContract,
//            "ONly EnergyMarket contract can update the processed status"
//        );

        commitment.energy_market_processed = processedStatus;
    }

//    function updateCollateral(uint256 tokenId, uint256 newCollateral) public {
//        _userProfiles[tokenId].collateral = newCollateral;
//    }

//    function updateEnergyData(uint256 tokenId) public {
//        (, int256 energyProduced, , ,) = _energyProducedOracle.latestRoundData();
//        (, int256 energyConsumed, , ,) = _energyConsumedOracle.latestRoundData();
//
//        require(energyProduced >= 0, "Invalid energyProduced value from oracle");
//        require(energyConsumed >= 0, "Invalid energyConsumed value from oracle");
//
//        _userProfiles[tokenId].energyProduced = uint256(energyProduced);
//        _userProfiles[tokenId].energyConsumed = uint256(energyConsumed);
//
//        emit EnergyDataUpdated(tokenId, uint256(energyProduced), uint256(energyConsumed));
//    }

    function updateEnergyPrice(uint256 tokenId) public {
        (, int256 energyPrice, , ,) = _energyPriceOracle.latestRoundData();

        require(energyPrice >= 0, "Invalid energyPrice value from oracle");

        _userProfiles[tokenId].energyPrice = uint256(energyPrice);
        emit EnergyPriceUpdated(tokenId, uint256(energyPrice));
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}





