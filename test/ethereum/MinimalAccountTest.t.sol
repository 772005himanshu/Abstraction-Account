// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp,PackedUserOperation,IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
contract MinimalAccountTest is Test {

    using MessageHashUtils for bytes32;


    // This is only used for contracts
    HelperConfig public helperConfig;
    MinimalAccount public minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;



    address randomUser = makeAddr("randomUser");


    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig,minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Approval
    // msg.sender -> MinimalAccount
    // Approve some amount
    // USDC contract 
    // I above all the cases we just Bundling all the altmemepoll transaction to go for the entry point
    // come from the entry point

    function testOwnerCanExecuteCommands() public {
        // Arrange,Act,Assert
        assertEq(usdc.balanceOf(address(minimalAccount)),0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest,value,functionData);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)),AMOUNT);
    }


    function testNonOwnerCannotExecuteCommands() public {
        // Arrange,Act,Assert
        assertEq(usdc.balanceOf(address(minimalAccount)),0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);

        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest,value,functionData);

        // Assert  we are assuming it will revert
        
    }


    // 1. Sign userOp
    // 2. Call Validate userops
    // 3. Assert the return is correct
    function testValidationOfUserOps() public {
        // Arrange 
        assertEq(usdc.balanceOf(address(minimalAccount)),0);
        address dest = address(usdc);

        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector,dest,value,functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData,helperConfig.getConfig(),address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;
        vm.prank(helperConfig.getConfig().entryPoint);

        uint256 validationData = minimalAccount.validateUserOp(packedUserOp,userOperationHash,missingAccountFunds);

        assertEq(validationData,0); // Why??  because on success it return 0;
    }

    // we are here checking all altmemepoll working correctly to send all the thing to entryPoint contract.
    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)),0);

        address dest = address(usdc);

        uint256 value = 0;
        
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector,dest,value,functionData);

        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData,helperConfig.getConfig(),address(minimalAccount));
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserHashOp(packedUserOp); // we donot ned this because it already included in handleUserOps() function 

        vm.deal(address(minimalAccount),1e18); // Why we donot use constant here `AMOUNT`

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(randomUser);  // randomUser means any altMemepoll can submit that transatation to the entryPoint
        // In EntryPoint function `handleOps` beneficry the random user who execting all the process will get some fee (so we are Thank them to work for us)

        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops,payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)),AMOUNT);  // Why is we directly tranfering the amount to MinimalAccount

        // Error in AMOUNt thing taht is happenng without reduced fees
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)),0);
        address dest = address(usdc);

        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector,dest,value,functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData,helperConfig.getConfig(),address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        // Act
        // for hash we always use getUserOpHash() function account-abstraction/core/EntryPoint
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(),packedUserOp.signature);
        // it may be used for signature thing to get v,r,s value which is given by the curve

        // Assert
        assertEq(actualSigner,minimalAccount.owner());
        // it is used to compare left side with right side

    }


}