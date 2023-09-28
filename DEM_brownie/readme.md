1. Install Brownie and Ganache CLI if you haven't already:

pip install eth-brownie
npm install -g ganache-cli

2. Create a new Brownie project:

brownie init my_energy_project
cd my_energy_project

3. Copy the contract files (.sol) for EnergyProfile, MockV3Aggregator, and any other dependencies, such as OpenZeppelin contracts, to the contracts/ folder within the Brownie project.

4. Create a network-config.yaml file in the project root directory (if it doesn't already exist) and add a local development network configuration for Ganache:

networks:
  default: development
  development:
    host: http://localhost
    port: 7545
    chainid: 1337

5. Start Ganache CLI in a separate terminal window:

ganache-cli --chainId 1337

6. Add the required packages for the contracts. In this case, you will need the Chainlink and OpenZeppelin packages:
``` bash
brownie pm install smartcontractkit/chainlink-brownie-contracts@1.1.1
brownie pm install OpenZeppelin/openzeppelin-contracts@4.4.0
```
7. Compile the contracts:

brownie compile

8. Create a deployment script to deploy the contracts. In the scripts/ folder, create a new file called deploy_energy_profile.py with the following content:

from brownie import EnergyProfile, MockV3Aggregator, accounts, network, interface
```python
def main():
    dev = accounts[0]

    # Deploy the MockV3Aggregator contracts for energyProduced and energyConsumed
    energy_produced_aggregator = MockV3Aggregator.deploy(18, 1000, {"from": dev})
    energy_consumed_aggregator = MockV3Aggregator.deploy(18, 2000, {"from": dev})

    # Deploy the EnergyProfile contract with the aggregator addresses
    energy_profile = EnergyProfile.deploy(energy_produced_aggregator.address, energy_consumed_aggregator.address, {"from": dev})

    print(f"EnergyProfile deployed at: {energy_profile.address}")
```


9. Deploy the contracts using the script:

brownie run scripts/deploy_energy_profile.py

10. Interact with the deployed contracts using the Brownie console:

brownie console


Chainlink Mock contract should work for each user 



## V1: How Does the Energy Market Work?

The system should include the addresses of the following contracts:
- EnergyProfile
- EnergyPool
- Oracle (Price, Energy Produced, Energy Consumed)

The functions to be implemented include:

1. matchProducerConsumer()
- Main Objective: This function scans the list of producers and consumers and matches them.
  - It has access to all the commitments.
  - It first checks whether the commitment is processed by the energy pool by verifying energy_pool_processed.
  - Next, it checks if each commitment is processed by the energy market contract by checking energy_market_processed.
  - It adds the ID of the commitments that are not processed by the energy market contract to a list (market_not_processed_commitments).
  - For market_not_processed_commitments, it checks the energy produced in the current interval.
    - If it is less than energyCommittedConsumption in the current interval, it calls the processCommitment() function for the element in the list.
    - Otherwise, it breaks the loop.
2. processCommitment()
- This function updates the energy produced and consumed for the current interval based on the amount of energy and the is_Production flag in the given commitment.
- It computes the cost or revenue for the current commitment based on the price oracle.
- It sets energy_market_processed to true.
3. settle_commitment()
- The production or consumption oracle is called to get the status of consumption and production for a given commitment ID.
- It settles the payment between producers and consumers based on the price oracle and the collateral in the commitment.
- It sets the 'settled' field in the commitment to true.  
----------------------------------------------------------------------
## V2: How Does the Energy Market Work?
The system should include the addresses of the following contracts:
- EnergyProfile
- EnergyPool
- Oracle (Price, Energy Produced, Energy Consumed)

### Data structures:
1. market_buffer: It has an array of structs for commitments, to be processed by the energy market contract:
- Profile NFT ID
- A Commitment  (which is structure itself)
- 

### Functions:
The functions to be implemented include:
1. process_buffer()
- Main Objective: his function processes the commitment inside the buffer and removes the processed ones
    - It calls the check_expired_commitments() function
    - it iterates over the commitments in the buffer
        - if energy_pool_processed is true, and energy produced is less than energyCommittedConsumption for the 
          current interval, it calls the processCommitment() function.
        - the current interval is index 0 of intervals array in the energy pool contract


2. check_expired_commitments()
- This function checks if the commitments in the buffer are expired or not, 
then it removes the expired ones from the buffer. 
- The order of the commitments in the buffer is not important
3. processCommitment()
- This function updates the energy produced and consumed for the current interval based on the amount of energy and the is_Production flag in the given commitment.
- It computes the cost or revenue for the current commitment based on the price oracle.
- It sets energy_market_processed to true.
4. settle_commitment()
- The production or consumption oracle is called to get the status of consumption and production for a given commitment ID.
- It settles the payment between producers and consumers based on the price oracle and the collateral in the commitment.
- It sets the 'settled' field in the commitment to true.  


## How to remove expired commitments from the buffer:
implement this logic:
buffer_size=length(buffer)
while i< length(buffer):
if i < buffer_size:
  if the element  is  expired:
    remove the element from the buffer
    buffer_size=buffer_size-1
    i=i+1
  else:
    i=i+1
else:
  break
### To do:
-  I disabled the  checking of energy_market_processed energy profile contract. Fixt it