//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract DeployRaffle is Script {
    Raffle raffle;

    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        uint256 ticketPrice = networkConfig.ticketPrice;
        uint256 raffleInterval = networkConfig.raffleInterval;
        address vrfCoordinator = networkConfig.vrfCoordinator;
        bytes32 keyHash = networkConfig.keyHash;
        uint64 subscriptionId = networkConfig.subscriptionId;
        uint16 requestConfirmations = networkConfig.requestConfirmations;
        uint32 callbackGasLimit = networkConfig.callbackGasLimit;

        vm.startBroadcast();

        raffle = new Raffle(
            ticketPrice, 
            raffleInterval, 
            vrfCoordinator, 
            keyHash, 
            subscriptionId,
            requestConfirmations,
            callbackGasLimit
            );
        vm.stopBroadcast();

        if(block.chainid == 31337) {
            vm.prank(address(helperConfig));
            VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, address(raffle));
        }
        return (raffle, helperConfig);
    }
}
