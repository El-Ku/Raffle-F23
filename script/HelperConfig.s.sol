//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {console} from "forge-std/Script.sol";

contract HelperConfig {
    error ChainNotSupported();

    struct NetworkConfig {
        uint256 ticketPrice;
        uint256 raffleInterval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
    }

    NetworkConfig public networkConfig;

    uint256 immutable chainid;
    uint256 constant ticketPrice = 1 ether;
    uint256 constant raffleInterval = 3600; //1 hour
    uint16 constant requestConfirmations = 3;
    uint32 constant callbackGasLimit = 100_000;

    constructor() {
        chainid = block.chainid;
        if (chainid == 11155111) {
            setSepoliaConfig();
        } else if (chainid == 31337) {
            setOrCreateAnvilConfig();
        } else {
            revert ChainNotSupported();
        }
    }

    function getConfig() external view returns (NetworkConfig memory) {
        return networkConfig;
    }

    function setSepoliaConfig() internal {
        networkConfig = NetworkConfig({
            ticketPrice: ticketPrice,
            raffleInterval: raffleInterval,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 2908,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit
        });
    }

    function setOrCreateAnvilConfig() internal {
        (address vRFCoordinatorV2Mock, uint64 subscriptionId) = deployMocks();

        networkConfig = NetworkConfig({
            ticketPrice: ticketPrice,
            raffleInterval: raffleInterval,
            vrfCoordinator: vRFCoordinatorV2Mock,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit
        });
    }

    function deployMocks() internal returns(address, uint64) {
        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            0.025 ether,
            10e9 wei
        );  //constructor(uint96 _baseFee, uint96 _gasPriceLink
        //call create subscriber funciton on Mock.
        uint64 subscriptionId = vRFCoordinatorV2Mock.createSubscription();
        //fund it.
        vRFCoordinatorV2Mock.fundSubscription(subscriptionId, 1000 ether);
        return(address(vRFCoordinatorV2Mock), subscriptionId);
    }
}
