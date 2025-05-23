// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract BaseERC20 {
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 10**8*10**18;
        balances[msg.sender] = totalSupply;  
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here
        uint256 ownerAmount = balances[msg.sender];
        require(ownerAmount>=_value, "ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require (_value <=allowances[_from][msg.sender],"ERC20: transfer amount exceeds allowance"); 
        require(_value<=balances[_from], "ERC20: transfer amount exceeds balance");
        
        balances[_from] -= _value;  
        allowances[_from][msg.sender] -= _value;
        balances[_to] += _value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here     
        return allowances[_owner][_spender];
    }
}


contract TokenBank {
    BaseERC20 immutable tokenContract;
    mapping (address =>uint256) public balances;

    constructor(address _tokenAddress){
        //初始化代币
        tokenContract = BaseERC20(_tokenAddress);
    
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
}