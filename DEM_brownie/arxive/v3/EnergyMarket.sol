// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyProfile.sol";
import "./EnergyPool.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Import the Ownable contract
// The EnergyMarket contract handles the energy market.
// It communicates with the EnergyProfile and EnergyPool contracts,
// and uses data from the Oracle contracts to process and settle commitments.
contract EnergyMarket is Ownable {
    // References to other contracts
    EnergyProfile private _energyProfileContract;
    EnergyPool private _energyPoolContract;
    AggregatorV2V3Interface private _energyPriceOracle;

    // This struct holds the commitments to be processed by the EnergyMarket contract.
    // Each entry in the buffer consists of a Profile NFT ID and a Commitment.
    struct MarketBuffer {
        uint256 profileNFTId;
        uint256 commitmentIndex;
    }
    struct ProducerBuffer{
        uint256 profileNFTId;
        uint256 commitmentIndex;
        }
    struct ConsumerBuffer{
        uint256 profileNFTId;
        uint256 commitmentIndex;
        }
    ProducerBuffer[] public producerBuffer;
    ConsumerBuffer[] public consumerBuffer;

    // This array holds the buffer of commitments to be processed.
//    MarketBuffer[] private _buffer;
//     make buffer public

    MarketBuffer[] public _buffer;
    event MarketPriceUpdated(uint256 newEnergyPrice);
    event CommitmentAddedToBuffer(uint256 profileNFTId, uint256 commitmentIndex);

    // The constructor initializes the EnergyProfile and EnergyPool contract addresses.
    constructor(address energyProfileContractAddress) {
        _energyProfileContract = EnergyProfile(energyProfileContractAddress);
    }

     function setEnergyPoolContract(address energyPoolContractAddress) external onlyOwner {
        // Here you might want to add some access control, for example allow only the contract owner to set this
        _energyPoolContract = EnergyPool(energyPoolContractAddress);
    }
    // Add a new commitment to the MarketBuffer
  // Add a new commitment to the MarketBuffer
    function addCommitmentToBuffer(uint256 profileNFTId, uint256 commitmentIndex) public returns(uint256, uint256) {
        // Only allow the EnergyPool or the owner of contract to call this function
        require(msg.sender == address(_energyPoolContract) || msg.sender == owner(), "Only the EnergyPool contract or the owner of the contract can add a commitment to the buffer");

        MarketBuffer memory newEntry;
        newEntry.profileNFTId = profileNFTId;
        newEntry.commitmentIndex = commitmentIndex;
        _buffer.push(newEntry);

        emit CommitmentAddedToBuffer(profileNFTId, commitmentIndex);

        return (profileNFTId, commitmentIndex);
    }


    // Remove a commitment from the MarketBuffer
    function removeCommitmentFromBuffer(uint256 index) public {
//        // Only allow the EnergyPool contract to call this function
//        require(msg.sender == address(_energyPoolContract), "Only the EnergyPool contract can remove a commitment from the buffer");

        if (index >= _buffer.length) return;

        _buffer[index] = _buffer[_buffer.length - 1];
        _buffer.pop();
    }
    function getBufferLength() public view returns (uint256) {
    return _buffer.length;
}
    // This function processes the commitments in the buffer.
    // It first calls `check_expired_commitments()` to remove any expired commitments from the buffer.
    // It then iterates over the remaining commitments in the buffer.
    // If `energy_pool_processed` is true and the energy produced is less than `energyCommittedConsumption`
    // for the current interval, it calls `processCommitment()`.
    function process_buffer() public {
        check_expired_commitments();

        uint256 i = 0;
        uint256 buffer_size = _buffer.length;

        while(i < buffer_size) {
            EnergyProfile.Commitment memory commitment = _energyProfileContract.getUserCommitments(_buffer[i].profileNFTId)[_buffer[i].commitmentIndex];
            if (commitment.energy_pool_processed) {
                // Process the commitment
                processCommitment(_buffer[i].profileNFTId, _buffer[i].commitmentIndex);

                // If the buffer has more than one element, swap the processed commitment with the last element
                if (buffer_size > 1) {
                    _buffer[i] = _buffer[buffer_size - 1];
                }
                // Remove the last element in the array
                _buffer.pop();
                // Reduce the buffer size
                buffer_size = buffer_size - 1;
            } else {
                i = i + 1;
            }
        }
    }


    // This function checks if the commitments in the buffer are expired or not,
    // and removes the expired ones from the buffer.
    // The order of the commitments in the buffer is not important, so this operation can be performed efficiently.
    function check_expired_commitments() public {
        uint256 i = 0;
        uint256 buffer_size = _buffer.length;

        while(i < buffer_size) {
            EnergyProfile.Commitment memory commitment = _energyProfileContract.getUserCommitments(_buffer[i].profileNFTId)[_buffer[i].commitmentIndex];
            if (block.number > commitment.startBlock + commitment.duration) {
                // If the buffer has more than one element, swap the expired commitment with the last element
                if (buffer_size > 1) {
                    _buffer[i] = _buffer[buffer_size - 1];
                }
                // Remove the last element in the array
                _buffer.pop();
                // Reduce the buffer size
                buffer_size = buffer_size - 1;
            } else {
                i = i + 1;
            }
        }
    }




//  after debugging, this function should be internal
    function processCommitment(uint256 profileNFTId, uint256 commitmentIndex) public {
        EnergyProfile.Commitment memory commitment = _energyProfileContract.getUserCommitments(profileNFTId)[commitmentIndex];

        // Update the energy amount in the energy pool contract
        _energyPoolContract.updateIntervalEnergyByMarket(commitment.isProduction, commitment.energyAmount);

        // Mark the commitment as processed by the energy market
        _energyProfileContract.setMarketProcessed(profileNFTId, commitmentIndex, true);

        // Based on commitment.isProduction add the commitment to producerBuffer or consumerBuffer
        if (commitment.isProduction) {
            // Add to the producerBuffer
            ProducerBuffer memory newProducer;
            newProducer.profileNFTId = profileNFTId;
            newProducer.commitmentIndex = commitmentIndex;
            producerBuffer.push(newProducer);
        } else {
            // Add to the consumerBuffer
            ConsumerBuffer memory newConsumer;
            newConsumer.profileNFTId = profileNFTId;
            newConsumer.commitmentIndex = commitmentIndex;
            consumerBuffer.push(newConsumer);
        }
    }
//    function settle_commitment() public {
//        uint256 producerIndex = 0;
//        uint256 consumerIndex = 0;
//        uint256 energyPrice;
//        uint256 demand=0;
//
//        // Iterate over the consumerBuffer
//        while (consumerIndex < consumerBuffer.length) {
//            // Get the energy amount from the consumer's commitment
//            EnergyProfile.Commitment memory consumerCommitment = _energyProfileContract.getUserCommitments(consumerBuffer[consumerIndex].profileNFTId)[consumerBuffer[consumerIndex].commitmentIndex];
//            demand += consumerCommitment.energyAmount;
//
//            // Iterate over the producerBuffer
//            while (producerIndex < producerBuffer.length) {
//                // Get the energy amount from the producer's commitment
//                EnergyProfile.Commitment memory producerCommitment = _energyProfileContract.getUserCommitments(producerBuffer[producerIndex].profileNFTId)[producerBuffer[producerIndex].commitmentIndex];
//                uint256 supply = producerCommitment.energyAmount;
//
//                if (supply <= demand) {
//                    energyPrice = _priceOracle.getLatestPrice();
//                    _energyProfileContract.settlePayment(consumerCommitment.profileNFTId, demand * energyPrice);
//                    demand = demand - supply;
//                    producerIndex++;
//                } else {
//                    consumerIndex++;
//                    break;
//                }
//            }
//
//    }
//    }

//     get the price from oracle
    function updateEnergyPrice() public {
        (, int256 energyPrice, , ,) = _energyPriceOracle.latestRoundData();
        require(energyPrice >= 0, "Invalid energyPrice value from oracle");
        uint256 newEnergyPrice = uint256(energyPrice);
        emit MarketPriceUpdated(newEnergyPrice);
    }
//    Add consumer to a consumer buffer

}
