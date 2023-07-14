//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint64 subscriptionId;
    bytes32 gasLane;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    event EnteredRaffle(
        address indexed participant,
        uint256 indexed entranceFee
    );

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            ,
            gasLane,
            interval,
            entranceFee,
            callbackGasLimit,
            vrfCoordinator,
            ,

        ) = helperConfig.activeNetworkConfig();
        deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNoEthSent() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InvalidEntranceFee.selector);
        raffle.enterRaffle();
        vm.stopPrank();
        assert(address(raffle).balance == 0);
    }

    function testRaffleRevertsWhenNotEnoughEntranceFee() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__InvalidEntranceFee.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
        // Assert
        assert(address(raffle).balance == 0);
    }

    function testRaffleRecordsPlayerEntry() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == address(PLAYER));
        vm.expectRevert();
        raffle.getPlayer(1);
        vm.stopPrank();
    }

    function testEmitsEventOnPlayerEntry() public {
        vm.startPrank(PLAYER);
        vm.expectEmit(true, true, false, false, address(raffle));
        emit EnteredRaffle(address(PLAYER), entranceFee);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        uint256 currentTime = block.timestamp;
        vm.warp(currentTime + interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__InvalidState.selector);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upkeepNeeded);
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPass() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsTrueWhenParamsAreTrue() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
        raffle.performUpkeep("");
        vm.stopPrank();
    }

    function testPerformUpkeepRevertsIfUpkeepNotNeeded() public {
        // arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // act
        vm.expectRevert();
        raffle.performUpkeep("");
        // assert
        vm.stopPrank();
    }

    function testPerformUpKeepRevertsWithDetails() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        // Raffle.RaffleState raffleState = raffle.getRAffleState();
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
        assert(requestId > 0);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformingUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        // assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getMostRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        assert(
            raffle.getMostRecentWinner().balance ==
                prize + STARTING_USER_BALANCE - entranceFee
        );
    }
}
