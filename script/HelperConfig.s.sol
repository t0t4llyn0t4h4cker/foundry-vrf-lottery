//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFCoordinatorV2Mock} from "../test/mocks/VRFCoordinatorV2Mock.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint64 subscriptionId;
        bytes32 gasLane;
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address linkToken;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 0,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                interval: 30,
                entranceFee: 0.01 ether,
                callbackGasLimit: 500000,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 linkFee = 1e9; // 1 gwei

        vm.startBroadcast(DEFAULT_ANVIL_KEY);
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            linkFee
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                subscriptionId: 0,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                interval: 30,
                entranceFee: 0.01 ether,
                callbackGasLimit: 500000,
                vrfCoordinator: address(vrfCoordinatorMock),
                linkToken: address(linkToken),
                deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
