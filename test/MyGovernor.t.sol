// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "src/Box.sol";
import {GovToken} from "src/GovToken.sol";
import {MyGovernor} from "src/MyGovernor.sol";
import {TimeLock} from "src/TimeLock.sol";

contract MyGovernorTest is Test {
    Box box;
    GovToken govToken;
    MyGovernor governor;
    TimeLock timelock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] callDatas;
    address[] targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after the vote passes.
    uint256 public constant VOTING_DELAY = 1; // how many blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box(address(this));
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdateBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);

        callDatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, callDatas, description);

        // Log initial proposal state
        console.log("Initial Proposal State : ", uint256(governor.state(proposalId)));

        // Move forward to activate the proposal
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Log proposal state after delay
        console.log("Proposal State after delay: ", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "Web3 is the best";
        uint8 voteWay = 1; // Voting Yes
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the Tx.
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, callDatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute
        governor.execute(targets, values, callDatas, descriptionHash);

        console.log("Box Value : ", box.getValue());
        assert(box.getValue() == valueToStore);
    }
}
