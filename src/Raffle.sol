//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error NotEnoughSentForTicket();
    error NotOwner();
    error RaffleIntervalTooSmall();
    error RafflePaused();
    error RaffleNotOpen();
    error CurrentLotOver();
    error TicketPriceCannotBeZero();
    error CannotRequestRandomWordNow();
    error PaymentFailedToWinner();
    error CannotFulfillRandomWordYet();

    enum RaffleState {
        OPEN,
        DRAWING
    }

    RaffleState private s_raffleState;
    uint256 private s_paused; // 1 means unpaused, 2 means paused.
    uint256 public constant MIN_RAFFLE_INTERVAL = 3600; //1 hour
    uint256 private s_raffleInterval; //in seconds.
    uint256 private s_ticketPrice;
    address payable[] private s_buyerList;
    uint256 private s_currentLotStartTime;
    VRFCoordinatorV2Interface i_vrfCoordinator;
    address private immutable i_owner;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint16 private immutable i_requestConfirmations;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastWonTicketId;
    address payable private s_recentWinner;

    event TicketBought(address indexed user, uint32 indexed ticketId);
    event RequestForRandomWordsSent(uint256 indexed requestId, uint32 timestamp);
    event WinnerPayed(uint256 randomWord, address indexed winner, uint256 indexed prizeMoney);
    event TicketPriceChanged(uint256 oldTicketPrice, uint256 indexed newTicketPrice);
    event RaffleIntervalChanged(uint256 oldRaffleInterval, uint256 indexed newRaffleInterval);

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    modifier isNotPaused() {
        if (s_paused != 1) {
            revert RafflePaused();
        }
        _;
    }

    modifier isRaffleOpen() {
        if (s_raffleState != RaffleState.OPEN) {
            revert RaffleNotOpen();
        }
        _;
    }

    modifier checkLotInterval() {
        if (block.timestamp > s_currentLotStartTime + s_raffleInterval) {
            revert CurrentLotOver();
        }
        _;
    }

    modifier checkTicketPrice() {
        if (msg.value < s_ticketPrice) {
            revert NotEnoughSentForTicket();
        }
        _;
    }

    constructor(
        uint256 _ticketPrice,
        uint256 _raffleInterval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_owner = msg.sender;
        s_paused = 1;
        setTicketPrice(_ticketPrice);
        setRaffleInterval(_raffleInterval);
        s_currentLotStartTime = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_keyHash = _keyHash;
        i_subscriptionId = _subscriptionId;
        i_requestConfirmations = _requestConfirmations;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function setRaffleInterval(uint256 _raffleInterval) public onlyOwner {
        if (_raffleInterval < MIN_RAFFLE_INTERVAL) {
            revert RaffleIntervalTooSmall();
        }
        emit RaffleIntervalChanged(s_raffleInterval, _raffleInterval);
        s_raffleInterval = _raffleInterval;
    }

    function setTicketPrice(uint256 _ticketPrice) public onlyOwner {
        if (_ticketPrice == 0) {
            revert TicketPriceCannotBeZero();
        }
        emit TicketPriceChanged(s_ticketPrice, _ticketPrice);
        s_ticketPrice = _ticketPrice;
    }

    function togglePause() external onlyOwner {
        if (s_paused == 1) {
            s_paused = 2;
        } else {
            s_paused = 1;
        }
    }

    function buyTicket()
        external
        payable
        isNotPaused
        isRaffleOpen
        checkLotInterval
        checkTicketPrice
        returns (uint32 ticketId)
    {
        s_buyerList.push(payable(msg.sender));
        emit TicketBought(msg.sender, ticketId = uint32(s_buyerList.length - 1));
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external isRaffleOpen isNotPaused returns (uint256 requestId) {
        if (block.timestamp < s_currentLotStartTime + s_raffleInterval) {
            revert CannotRequestRandomWordNow();
        }
        if (address(this).balance == 0) {
            //No one bought a ticket.
            s_currentLotStartTime = block.timestamp; //reset next lot start time and exit
            return 0;
        }
        // Will revert if subscription is not set and funded.
        requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash, i_subscriptionId, i_requestConfirmations, i_callbackGasLimit, 1
        );
        s_raffleState = RaffleState.DRAWING;
        emit RequestForRandomWordsSent(requestId, uint32(block.timestamp));
    }

    function fulfillRandomWords(uint256 /*_requestId*/, uint256[] memory _randomWords) internal override {
        if (s_raffleState != RaffleState.DRAWING) {
            revert CannotFulfillRandomWordYet();
        }
        uint256 numTickets = s_buyerList.length;
        uint256 winnerId = _randomWords[0] % numTickets;
        address payable winner = s_buyerList[winnerId];
        uint256 prizeMoney = address(this).balance;

        s_raffleState = RaffleState.OPEN;
        s_currentLotStartTime = block.timestamp;
        s_recentWinner = winner;
        s_buyerList = new address payable [](0);

        (bool success,) = winner.call{value: prizeMoney}("");
        if (success == true) {
            emit WinnerPayed(_randomWords[0], winner, prizeMoney);
        } else {
            revert PaymentFailedToWinner();
        }
    }

    /* VIEW FUNCTIONS */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPaused() external view returns (uint256) {
        return s_paused;
    }

    function getRaffleInterval() external view returns (uint256) {
        return s_raffleInterval;
    }

    function getTicketPrice() external view returns (uint256) {
        return s_ticketPrice;
    }

    function getBuyerAt(uint256 index) external view returns (address payable) {
        return s_buyerList[index];
    }

    function getBuyersLength() external view returns (uint256) {
        return s_buyerList.length;
    }

    function getCurrentLotStartTime() external view returns (uint256) {
        return s_currentLotStartTime;
    }

    function getRaffleOwner() external view returns (address) {
        return i_owner;
    }

    function getLastWonTicketId() external view returns (uint256) {
        return s_lastWonTicketId;
    }

    function getRecentWinner() external view returns (address payable) {
        return s_recentWinner;
    }

    function getVrfConfigParameters() external view returns (address, bytes32, uint64, uint16, uint32) {
        return (address(i_vrfCoordinator), i_keyHash, i_subscriptionId, i_requestConfirmations, i_callbackGasLimit);
    }
}
