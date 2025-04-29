// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Counter{
    uint public count = 0;

    function add(uint x) public   {
        count = count + x;
    }

    function get () public view returns (uint _count) {
        _count = count;
    }

}
