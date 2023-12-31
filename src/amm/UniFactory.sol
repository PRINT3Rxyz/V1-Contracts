// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract UniFactory {
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;
}
