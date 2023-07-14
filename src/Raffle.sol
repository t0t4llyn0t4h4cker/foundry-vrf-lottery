//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title sample Raffle Contract
 * @notice Contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__InvalidEntranceFee();
    error Raffle__WinningsNotTransferred();
    error Raffle__InvalidState();
    error Raffle__UpkeepNotNeeded(
        uint256 contractBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING_WINNER // 1
    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev interval is in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_participants;
    address private s_mostRecentWinner;
    RaffleState private s_raffleState;

    event EnteredRaffle(
        address indexed participant,
        uint256 indexed entranceFee
    );
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) revert Raffle__InvalidState();
        if (msg.value < i_entranceFee) revert Raffle__InvalidEntranceFee();

        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender, msg.value);
    }

    /**
     * @dev Function called by Chainlink Automation nodes to check if upkeep is needed
     * The following should be true:
     * 1. The time interval passed between runs
     * 2. The raffle state is OPEN
     * 3. Contract has ETH (i.e. participants have entered)
     * 4. (Implicit) Subscription is funded
     */
    function checkUpkeep(
        bytes memory /* checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool raffleIsOpen = RaffleState.OPEN == s_raffleState;
        bool contractHasEth = address(this).balance > 0;
        bool hasPlayers = s_participants.length > 0;

        upkeepNeeded = (timeHasPassed &&
            raffleIsOpen &&
            contractHasEth &&
            hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("0x0");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_participants.length;
        address payable winner = s_participants[indexOfWinner];
        s_mostRecentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        (bool milady, ) = winner.call{value: address(this).balance}("");
        if (!milady) {
            revert Raffle__WinningsNotTransferred();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_participants[index];
    }

    function getMostRecentWinner() external view returns (address) {
        return s_mostRecentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_participants.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
