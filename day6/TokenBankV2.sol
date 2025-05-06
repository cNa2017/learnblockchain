// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/Address.sol";

contract ERC20_Extend is ERC20 {
    // using Address for address;
    event Log_ERC20_Extend(address msgSender);
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        _mint(msg.sender, initialSupply);
    }

    function transferWithCallback(address recipient, uint256 amount) external returns (bool) {
        emit Log_ERC20_Extend(msg.sender);
        _transfer(msg.sender, recipient, amount);//从用户账号转给合约
        if (recipient.code.length>0) {//判断是否合约
            bool r = TokenBankV2(recipient).tokensReceived(msg.sender, amount);//
            require(r, "No tokensReceived");
        }
        return true;
    }
}


contract TokenBankV2 {
    // using Address for address;
    // using SafeERC20 for IERC20;
    event Log_TokenBankV2(address msgSender);

    ERC20_Extend immutable tokenContract;
    mapping (address =>uint256) public balances;

    constructor(address _tokenAddress){
        //初始化代币
        tokenContract = ERC20_Extend(_tokenAddress);
    
    }

    function deposit(uint256 _value)public{
        require(tokenContract.allowance(msg.sender, address(this))>= _value, "deposit: transfer amount exceeds allowance TokenBank");
        tokenContract.transferFrom(msg.sender,address(this),_value);//转账
        balances[msg.sender] += _value;//增加银行余额
    }
    function withdraw(uint256 _value) public{
        require (balances[msg.sender]>=_value, "withdraw: transfer amount exceeds balance TokenBank");//取钱余额检查
        balances[msg.sender]-= _value; //减少银行余额
        tokenContract.transfer(msg.sender, _value);

    }

    function checkNaticeBalance()public view returns(uint256 ){
        uint256 balance = tokenContract.balanceOf(msg.sender);
        return balance;
    }

    function tokensReceived (address _from,uint256 _value)external returns(bool) {
        emit Log_TokenBankV2(msg.sender);
        require(msg.sender == address(tokenContract),"not the expected token");//检查是否是Token合约
        balances[_from]+= _value; //增加银行余额
        return true ;
    }

}