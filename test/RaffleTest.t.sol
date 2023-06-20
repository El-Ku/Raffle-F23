//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol"; 
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {

    DeployRaffle deployRaffle;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;
    Raffle raffle;

    uint256 ticketPrice;
    uint256 raffleInterval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;

    address constant USER1 = address(0x1);
    address constant USER2 = address(0x2);
    address constant USER3 = address(0x3);

    // EVENTS from Raffle.sol
    event TicketBought(address indexed user, uint32 indexed ticketId);
    event RequestForRandomWordsSent(uint256 indexed requestId, uint32 timestamp);
    event WinnerPayed(uint256 randomWord, address indexed winner, uint256 indexed prizeMoney);
    event TicketPriceChanged(uint256 oldTicketPrice, uint256 indexed newTicketPrice);
    event RaffleIntervalChanged(uint256 oldRaffleInterval, uint256 indexed newRaffleInterval);

    error OnlyCoordinatorCanFulfill();

    modifier skipfork() {
        if(block.chainid != 31337) {
            console.log("This test works only on anvil local chain");
            return;
        }
        _;
    }

    function setUp() external {
        //deploy raffle contract by deploying the script
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        networkConfig = helperConfig.getConfig();

        ticketPrice = networkConfig.ticketPrice;
        raffleInterval = networkConfig.raffleInterval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        keyHash = networkConfig.keyHash;
        subscriptionId = networkConfig.subscriptionId;
        requestConfirmations = networkConfig.requestConfirmations;
        callbackGasLimit = networkConfig.callbackGasLimit;

        //add the raffle contract as a consumer to the subscriptionId
        //VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, address(raffle));
        
        deal(USER1, 1000 ether);
        deal(USER2, 1000 ether);
        deal(USER3, 1000 ether);

        vm.roll(block.number + 1);
    }

    function testCheckDeployment() external {
        //print address
        console.log("Raffle owner:              ",raffle.getRaffleOwner());
        console.log("msg.sender:                ",msg.sender);
        console.log("deployRaffle contract:     ",address(deployRaffle));
        console.log("helperConfig contract:     ",address(helperConfig));
        console.log("Test contract(this):       ",address(this));
        console.log("vrfCoordinator contract:   ",vrfCoordinator);

        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getPaused(), 1);
        assertEq(raffle.getRaffleInterval(), raffleInterval);
        assertEq(raffle.getTicketPrice(), ticketPrice);
        assertEq(raffle.getCurrentLotStartTime(), block.timestamp);
        assertEq(raffle.getRaffleOwner(), msg.sender);
        assertEq(raffle.getLastWonTicketId(), 0);
        assertEq(raffle.getBuyersLength(), 0);
        (address a, bytes32 b, uint64 c, uint16 d, uint32 e) = raffle.getVrfConfigParameters();
        assertEq(a, vrfCoordinator);
        assertEq(b, keyHash);
        assertEq(c, subscriptionId);
        assertEq(d, requestConfirmations);
        assertEq(e, callbackGasLimit);
    }

    // set raffle interval after contract is deployed
    function testSetRaffleInterval() external {
        uint256 minRaffleInterval = raffle.MIN_RAFFLE_INTERVAL();
        
        // call as a regular user
        vm.prank(USER1);
        vm.expectRevert(Raffle.NotOwner.selector);
        raffle.setRaffleInterval(minRaffleInterval+1);
        
        //call as owner, but too small of a value
        vm.prank(raffle.getRaffleOwner());
        vm.expectRevert(Raffle.RaffleIntervalTooSmall.selector);
        raffle.setRaffleInterval(minRaffleInterval-1);

        // call as an owner with high enough value
        vm.expectEmit(true, true, false, true, address(raffle));
        emit RaffleIntervalChanged(raffleInterval, minRaffleInterval+1 );
        vm.prank(raffle.getRaffleOwner());
        raffle.setRaffleInterval(minRaffleInterval+1);
        assertEq(raffle.getRaffleInterval(), minRaffleInterval+1);
    }

    // set ticket price after contract is deployed
    function testSetTicketPrice() external {
        // call as a regular user
        vm.prank(USER1);
        vm.expectRevert(Raffle.NotOwner.selector);
        raffle.setTicketPrice(1 ether);

        //call as owner, but with value of zero
        vm.prank(raffle.getRaffleOwner());
        vm.expectRevert(Raffle.TicketPriceCannotBeZero.selector);
        raffle.setTicketPrice(0);

        // call as an owner with non-zero value
        vm.expectEmit(true, true, false, true, address(raffle));
        emit TicketPriceChanged(ticketPrice, 2 ether );
        vm.prank(raffle.getRaffleOwner());
        raffle.setTicketPrice(2 ether);
        assertEq(raffle.getTicketPrice(), 2 ether);
    }

    // cannot buy ticket when contract is paused
    function testBuyTicketWhenPaused() external {
        vm.prank(raffle.getRaffleOwner());
        raffle.togglePause();
        vm.prank(USER1);
        vm.expectRevert(Raffle.RafflePaused.selector);
        raffle.buyTicket{value: 1 ether}();
    }

    // cannot buy ticket after current Raffle interval
    function testBuyTicketAfterRaffleInterval() external {
        vm.warp(block.timestamp + raffleInterval + 1);
        vm.prank(USER1);
        vm.expectRevert(Raffle.CurrentLotOver.selector);
        raffle.buyTicket{value: 1 ether}();
    }

    // cannot buy ticket if enough eth is not sent
    function testBuyTicketWithLessPrice() external {
        vm.prank(USER1);
        vm.expectRevert(Raffle.NotEnoughSentForTicket.selector);
        raffle.buyTicket{value: 0.99 ether}();
    }

    // Different users buying tickets successfully
    function testBuyTickets() external {
        _buyTicket(USER1, raffle.getBuyersLength());
        _buyTicket(USER2, raffle.getBuyersLength());
        _buyTicket(USER3, raffle.getBuyersLength());
        _buyTicket(USER3, raffle.getBuyersLength());

        //Confirming buyer addresses are stored properly
        assertEq(raffle.getBuyerAt(0), USER1);
        assertEq(raffle.getBuyerAt(1), USER2);
        assertEq(raffle.getBuyerAt(2), USER3);
        assertEq(raffle.getBuyerAt(3), USER3);
        // Confirm 4 buyers are stored
        assertEq(raffle.getBuyersLength(), 4);
    }

    function testRequestRandomWordsWithZeroBuyers() external {
        vm.warp(block.timestamp + 61 minutes);
        uint256 requestId = raffle.requestRandomWords();
        assertEq(raffle.getCurrentLotStartTime(), block.timestamp);
        assertEq(requestId, 0);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    function testRequestRandomWords() external skipfork {
        for (uint256 i=1; i <= 10; i++) {
            _buyTicket(address(uint160(i)), raffle.getBuyersLength());
            vm.warp(block.timestamp + 5 minutes);
        }
        assertEq(raffle.getBuyersLength(), 10);
        // Try to request randomwords with 10 buyers and before raffle interval is over
        vm.expectRevert(Raffle.CannotRequestRandomWordNow.selector);
        raffle.requestRandomWords();

        vm.warp(block.timestamp + 11 minutes);
        vm.prank(raffle.getRaffleOwner());
        raffle.togglePause();  //toggle unpause to pause
        // Try to request randomwords after raffle interval is over but contract paused
        vm.expectRevert(Raffle.RafflePaused.selector);
        raffle.requestRandomWords();

        vm.prank(raffle.getRaffleOwner());
        raffle.togglePause();  //toggle pause to unpause
        //vm.expectEmit(false, true, false, false, address(raffle));
        //emit RequestForRandomWordsSent(1, uint32(block.timestamp));
        // Try to request randomwords after raffle interval is over and contract unpaused
        uint256 requestId = raffle.requestRandomWords();
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.DRAWING));
        assertGt(requestId, 0);
    }

    function testFulfillRandomWordsBeforeRequesting(uint256 requestId) external skipfork {
        // If the function is called before we request for a randomNumber then it should revert
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    // This test only works on anvil chain(local network)
    function testFulfillRandomWordsAfterRequesting() external skipfork {
        //first buy some tickets
        uint256 endInterval = block.timestamp + raffleInterval;
        uint256 NUMBUYERS = 100;
        uint256 PRIZEMONEY = NUMBUYERS * ticketPrice;

        for (uint256 i=1; i <= NUMBUYERS; i++) {
            _buyTicket(address(uint160(i)), raffle.getBuyersLength());
            vm.warp(block.timestamp + 30 seconds);
        }
        assertEq(raffle.getBuyersLength(), NUMBUYERS);
        vm.warp(endInterval + 1);  //warp to end of raffle lot.

        //call requestRandomWords
        uint256 requestId = raffle.requestRandomWords();
        assertGt(requestId, 0);

        // Mock a node which calls fulfillRandomWords on VRFCoordinator
        vm.recordLogs();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 emittedRandomWord = abi.decode(logs[0].data, (uint256));
        uint256 emittedWinner = uint256(logs[0].topics[1]);
        uint256 emittedPrizeMoney = uint256(logs[0].topics[2]);
        assertEq(emittedRandomWord % NUMBUYERS + 1, emittedWinner);
        assertEq(emittedPrizeMoney, PRIZEMONEY);
        // winner received the prize in his account
        assertEq(address(uint160(emittedWinner)).balance, PRIZEMONEY);
        //More asserts
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(raffle.getCurrentLotStartTime(), block.timestamp);
        assertEq(raffle.getRecentWinner(), address(uint160(emittedWinner)));
        assertEq(raffle.getBuyersLength(), 0);
    }

    // internal function buy a ticket as a specified user and check if its bought properly
    // and events are emitted correctly.
    function _buyTicket(address user, uint256 newTicketId) internal {
        newTicketId = uint32(newTicketId);
        uint256 ticketId;
        vm.expectEmit(true, true, false, true, address(raffle));
        emit TicketBought(user, uint32(newTicketId) );
        hoax(user, ticketPrice);
        ticketId = raffle.buyTicket{value: ticketPrice}();
        assertEq(ticketId, newTicketId);
    }
}
