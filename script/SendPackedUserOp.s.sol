// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";



contract SendPackedUserOp is Script {

    using MessageHashUtils for bytes32;
    using DevOpsTools for address;

    address constant RANDOM_APPROVER = 0x668EDaf4f77d4d9c0d9B0d0879E7701b21D44e26;  // never deploy this on Mainnet

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        // DevOpsTools devOpsTools = new DevOpsTools();
        address dest = 0x668EDaf4f77d4d9c0d9B0d0879E7701b21D44e26;

        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment("MinimalAccount",block.chainid);

        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector,RANDOM_APPROVER,1e18);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector,dest,value,functionData);

        PackedUserOperation memory userOp = generateSignedUserOperation(executeCallData,helperConfig.getConfig(),minimalAccountAddress);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops,payable(helperConfig.getConfig().account));
        vm.stopBroadcast();

    }

    function generateSignedUserOperation(bytes memory callData,HelperConfig.NetworkConfig memory config,address minimalAccount) public returns(PackedUserOperation memory){
        // 1. Generate unsign data
        // 2. Get userOp Hash

        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData,minimalAccount,nonce);

        bytes32 userOpHash =  IEntryPoint(config.entryPoint).getUserOpHash(userOp);  // to inline in same row 
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. SIGN it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if(block.chainid == 31337){
            (v,r,s) = vm.sign(ANVIL_DEFAULT_KEY,digest);
        }else{
            (v,r,s) = vm.sign(config.account,digest);
        }
        userOp.signature = abi.encodePacked(r,s,v); // Orrder should be correct 

        return userOp;
    }


    function _generateUnsignedUserOperation(bytes memory callData,address sender, uint256 nonce ) internal pure returns(PackedUserOperation memory ){

        uint128 VerificationGasLimit = 16777216;
        uint128 callGasLimit = VerificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation ({
            sender: sender,
            nonce: nonce,
            initCode :hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(VerificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: VerificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}