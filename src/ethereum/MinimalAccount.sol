// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED,SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";



contract MinimalAccount is IAccount,Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPointOrOwner() {
        if(msg.sender != address(i_entryPoint) && msg.sender != owner()){
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    modifier requireFromEntryPoint() {
        if(msg.sender != address(i_entryPoint)){
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    // entryPoint -> this contract 
    uint256 ourNonce = 0;


    constructor(address entryPoint) Ownable(msg.sender){
        i_entryPoint = IEntryPoint(entryPoint);
    }

    // A signature is valid when if it is the owner of the contract
    function execute(address dest,uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success,bytes memory result) = dest.call{value: value}(functionData);
        // require(success,"execute failed");  --> why not this type of thing is done because we have to return the result also
        if(!success){
            revert MinimalAccount__CallFailed(result);
        }
    } 

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEntryPoint returns (uint256 validationData){
       validationData = _validateSignature(userOp,userOpHash);
       // _validateNonce()
       _payPrefund(missingAccountFunds);
    }

    function _validateSignature(PackedUserOperation calldata userOp,bytes32 userOpHash) internal view returns(uint256 validationData){
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash,userOp.signature);
        if(signer != owner()){
            return SIG_VALIDATION_FAILED;  // return 1;


        }
        return SIG_VALIDATION_SUCCESS;  // return 0;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
        (success);
    }


    function getEntryPoint() external view returns(address){
        return address(i_entryPoint);
    }
}