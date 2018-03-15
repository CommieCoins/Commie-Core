pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
// 'CCCP' 'Commie Coin' token contract
//
// Symbol      : CCCP
// Name        : Commie Coin
// Total supply: Generated from contributions
// Decimals    : 18
// ----------------------------------------------------------------------------

import './Safemath.sol';
import './ERC20.sol';
import './Owned.sol';

// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals
// Receives ETH and generates tokens
// ----------------------------------------------------------------------------
contract CCCP_Token is ERC20Interface, Owned, SafeMath {
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;
    uint public startDate;
    uint public bonusEnds;
    uint public endDate;
    
    struct Entry {
    bytes1 id;
    uint balances;
    }

    //mapping(address => uint) balances;
    mapping (address => Entry) public users;
    mapping(address => mapping(address => uint)) allowed;
    address[] public addressArray;
    
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function CCCP_Token() public {
        symbol = "CCCP";
        name = "Commie Coin";
        decimals = 18;
        _totalSupply = 0;        
        users[owner].balances = _totalSupply;
        Transfer(address(0), owner, _totalSupply);

        // Activate to include bonus coins
        startDate = now;
        bonusEnds = now + 1 weeks;
        endDate = now + 1 weeks;
    }


    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public constant returns (uint) {
        return _totalSupply - users[address(0)].balances;
    }


    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return users[tokenOwner].balances;
    }


    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        if (users[to].id == "")
            addressArray.push(to);
            users[msg.sender].id = 1;
        users[msg.sender].balances = safeSub(users[msg.sender].balances, tokens);
        users[to].balances = safeAdd(users[to].balances, tokens);
        Transfer(msg.sender, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ---------------------------------------------------------------------0---
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        if (users[to].id == "")
            addressArray.push(to);
            users[msg.sender].id = 1;
        users[msg.sender].balances = safeSub(users[msg.sender].balances, tokens);
        allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
        users[to].balances = safeAdd(users[to].balances, tokens);
        Transfer(from, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account. The `spender` contract function
    // `receiveApproval(...)` is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }


    // ------------------------------------------------------------------------
    // 1,000 tokens per 1 ETH, with 20% bonus
    // ------------------------------------------------------------------------
    function ICOpayment() public payable {
        require(now >= startDate && now <= endDate);
        uint tokens;
        if (now <= bonusEnds) {
            tokens = msg.value * 1200;
        } else {
            tokens = msg.value * 1000;
        }
        if (users[msg.sender].id == "")
            addressArray.push(msg.sender);
            users[msg.sender].id = 1;
        users[msg.sender].balances = safeAdd(users[msg.sender].balances, tokens);
        _totalSupply = safeAdd(_totalSupply, tokens);
        Transfer(address(0), msg.sender, tokens);
        owner.transfer(msg.value);
    }   


    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    //------------------------------------------------------------------------------
    // Owner can transfer balances to a secure wallet for redistribution
    //------------------------------------------------------------------------------
    function deductaccounts() public returns (bool success) {
        require(msg.sender == owner);
        uint count = addressArray.length;
        for (uint256 i = 0; i < count; i++) {
            address inputaddr = address(addressArray[i]);
            uint inputaddr_balance = users[inputaddr].balances;
            users[inputaddr].balances = safeSub(users[inputaddr].balances, users[inputaddr].balances);
            users[owner].balances = safeAdd(users[owner].balances, inputaddr_balance);
            Transfer(inputaddr, owner, inputaddr_balance);
        }
        return true;
    }
    
    //------------------------------------------------------------------------------
    // Send coins from master account to all users in the address addressArray
    // - addrbalances is the balance of all users in addressArray
    //------------------------------------------------------------------------------
    function sendredist(uint[] addrbalances) public returns (bool success) {
        require(msg.sender == owner);
        uint count = addressArray.length;
        for (uint256 i = 0; i < count; i++) {
            address inputaddr = address(addressArray[i]);
            uint coins = addrbalances[i];
            users[owner].balances = safeSub(users[owner].balances, coins);
             users[inputaddr].balances = safeAdd(users[inputaddr].balances, coins);
            Transfer(owner, inputaddr, coins);
        }
        return true;
    }
    
    //------------------------------------------------------------------------------
    // Determine the min number of coins (mincoins) to redistribute
    // - perc_coins is the percent of the total supply of coins to set as mincoins
    // Steps:
    // - Set min number of coins (mincoins)
    // - Set penalty to 10% of the mincoins
    // - If mincoins is not met then reduce their wallet by the penalty
    // - Store new balances in array (newbalance)
    // - Send new balances for redistribution to sendredist
    //------------------------------------------------------------------------------
    function redistaccounts(uint perc_coins) public returns (bool success) {
        require(msg.sender == owner);
        uint mincoins = safeDiv(_totalSupply, perc_coins);
        uint count = addressArray.length;
        uint distvar = 0;   // How many people are splitting the payment
        uint penalty = safeDiv(mincoins, 10);
        uint[] memory newbalance = new uint[](count);
        uint coinshare = _totalSupply;
        
       for (uint256 i = 0; i < count; i++) {
            address inputaddr = address(addressArray[i]);
            uint inputaddr_balance = users[inputaddr].balances;
            bool hasmin = hasMinCoins(mincoins, inputaddr_balance);
            if (hasmin == true){                              // Check if the account has enough coins if they do
                distvar = distvar + 1;
            }else{                                            // add to the number of people splitting coins
            coinshare = safeSub(coinshare, inputaddr_balance);         // If they don't subtract the amount they get to keep from the share
            coinshare = safeAdd(coinshare, penalty);
            }
        } 
        
        for (i = 0; i < count; i++) {
            inputaddr = address(addressArray[i]);
            inputaddr_balance = users[inputaddr].balances;
            uint sharebalance = safeDiv(coinshare, distvar);
            uint penbalance;
            
            hasmin = hasMinCoins(mincoins, inputaddr_balance);
            if (hasmin == true){                         // if they have enough coins give them shared redistribution
                newbalance[i]=sharebalance;
            } else {                                      // else apply penalty 
                penbalance = safeSub(inputaddr_balance, penalty);
                newbalance[i]=penbalance;    
            }
            
            users[inputaddr].balances = safeSub(users[inputaddr].balances, users[inputaddr].balances);
            users[owner].balances = safeAdd(users[owner].balances, inputaddr_balance);
            Transfer(inputaddr, owner, inputaddr_balance);
        }
        
        sendredist(newbalance);
      
         return true;
    }
    
    //------------------------------------------------------------------------------
    // Check if user balance meets the min number of coins
    //------------------------------------------------------------------------------
    function hasMinCoins(uint mincoins, uint balance) public returns (bool success){
        if (balance >= mincoins){
            return true;
        }else{
        
        return false;
        
        }
    }
  }
