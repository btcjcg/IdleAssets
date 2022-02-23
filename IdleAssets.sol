pragma solidity ^0.4.24;
interface token{
    function transfer(address _to,uint amount) external;
}
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
contract Ownable {
  address public owner;
  address public dev;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}
contract Pausable is Ownable {
  event Pause();
  event Unpause();
  bool public paused = false;
  modifier whenNotPaused() {
    require(!paused);
    _;
  }
  modifier whenPaused() {
    require(paused);
    _;
  }
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract StandardToken is ERC20, Pausable {
  using SafeMath for uint256;
  uint8 public R_tfee;
  uint8 public B_tfee;
  address public tax;
  uint public tokencount;
  mapping (address => mapping (address => uint256)) internal allowed;
  mapping(address => bool) public tokenBlacklist;
  mapping(address => bool) public icolist;
  mapping(address => uint256) balances;
  event Blacklist(address indexed blackListed, bool value);
  event Icolist(address indexed icoListed, bool value);
  event Burn(address indexed burner, uint256 value);
  event Tax(address indexed addrFrom, address indexed addrTo, uint256 value);
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(!tokenBlacklist[msg.sender]);
    require(_to != address(0));
    require(_value <= balances[msg.sender] && _value>0 );
    balances[msg.sender] = balances[msg.sender].sub(_value);
    (uint256 v_fee, uint256 b_fee, uint256 R_value) = _getValues(_value);
    totalSupply = totalSupply.sub(b_fee);
    tokencount = tokencount.sub(b_fee);
    balances[_to] = balances[_to].add(R_value);
    balances[tax] = balances[tax].add(v_fee);
    balances[address(0)] = balances[address(0)].add(b_fee);
    emit Burn(msg.sender, b_fee);
    emit Tax(msg.sender,_to,v_fee);
    emit Transfer(msg.sender, _to, R_value);
    emit Transfer(msg.sender, tax, v_fee);
    emit Transfer(msg.sender, address(0), b_fee);
    return true;
  }
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(!tokenBlacklist[msg.sender]);
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    (uint256 v_fee, uint256 b_fee, uint256 R_value) = _getValues(_value);
    totalSupply = totalSupply.sub(b_fee);
    tokencount = tokencount.sub(b_fee);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(R_value);
    balances[tax] = balances[tax].add(v_fee);
    balances[address(0)] = balances[address(0)].add(b_fee);
    emit Burn(_from, b_fee);
    emit Tax(_from,_to,v_fee);
    emit Transfer(_from, _to, R_value);
    emit Transfer(_from, tax, v_fee);
    emit Transfer(_from, address(0), b_fee);
    return true;
  }
  function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
    uint256 v_fee = tAmount.mul(R_tfee).div(10000);
    uint256 b_fee = tAmount.mul(B_tfee).div(10000);
    return (v_fee, b_fee, tAmount.sub(v_fee).sub(b_fee));
  }
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
  function _blackList(address _address, bool _isBlackListed) internal returns (bool) {
    require(tokenBlacklist[_address] != _isBlackListed);
    require(_address!=dev);
    tokenBlacklist[_address] = _isBlackListed;
    emit Blacklist(_address, _isBlackListed);
    return true;
  }
  function _icoList(address _address, bool _isIcoListed) internal returns (bool) {
    require(icolist[_address] != _isIcoListed);
    require(_address!=dev);
    icolist[_address] = _isIcoListed;
    emit Icolist(_address, _isIcoListed);
    return true;
  }
}

contract PausableToken is StandardToken {
  function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transfer(_to, _value);
  }
  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }
  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    return super.approve(_spender, _value);
  }
  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
  function blackListAddress(address listAddress,  bool isBlackListed) public whenNotPaused onlyOwner  returns (bool success) {
  return super._blackList(listAddress, isBlackListed);
  }
  function icoListAddress(address listAddress,  bool isIcoListed) public whenNotPaused onlyOwner  returns (bool success) {
  return super._icoList(listAddress, isIcoListed);
  }
}
contract CoinToken is PausableToken {
    string public name;
    string public symbol;
    uint public decimals;
    uint funAmount;
    uint public unlocktime;
    address public receivetaxaddr;
    event Mint(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed burner, uint256 value);
    event FundTransfer(address indexed backer,uint amount);
    constructor(address tokenOwner,address[] cr_addrs,uint[] cr_values) public {
        name = "Idle Assets";
        symbol = "IA";
        decimals = 18;
        totalSupply = 10000000 * 10**decimals;
        dev = msg.sender;
        tax = address(this);
        receivetaxaddr= tax;
        owner = tokenOwner;
        R_tfee = 10;
        B_tfee = 10;
        icolist[dev] = true;
        unlocktime = now + 365 days;
        creation(cr_addrs,cr_values);
    }
    function creation(address[] _addr,uint[] _values) internal returns (bool) {
            require(_addr.length == _values.length);
            uint i;
            uint valuecount;
            uint _val;
            for(i = 0; i < _values.length; i++){
              valuecount += _values[i];
            }
            require(valuecount <= 100);
            for(i = 0; i < _addr.length; i++){
              _val = totalSupply * _values[i] / 100;
              balances[_addr[i]] = _val;
              tokencount =tokencount.add(_val);
              emit Mint(address(0), _addr[i], _val);
            }
            return true;
    }
    function taxtransfer(address _taxaddr) onlyOwner public returns (bool){
      require(_taxaddr!= address(0));
      require(_taxaddr!= tax);
      require(now >= unlocktime);
      require(balances[tax]>0);
      uint value = balances[tax];
      balances[tax]=balances[tax].sub(value);
      balances[_taxaddr]=balances[_taxaddr].add(value);
      receivetaxaddr = _taxaddr;
      unlocktime = now + 365 days;
      emit Transfer(address(this),_taxaddr,value);
      return true;
    }
    function airtransfer(address[] _recipients, uint _value) public returns (bool) {
      require(_recipients.length > 0);
      require(_value > 0);
      uint i = _recipients.length;
      uint _vals = i.mul(_value);
      require(balances[msg.sender] >= _vals);
      if (allowance(msg.sender,msg.sender)<_vals){approve(msg.sender, _vals);}
      for(i = 0; i < _recipients.length; i++){
            transferFrom(msg.sender,_recipients[i], _value);
      }
      return true;
    }
    function icotransfer(address[] _recipients, uint[] _values) public returns (bool){
      require(_recipients.length > 0);
      require(_recipients.length == _values.length);
      uint valuecount;
      uint i;
      for(i = 0; i < _recipients.length; i++){
            valuecount += _values[i];
      }
      require(valuecount > 0);
      require(balances[msg.sender] >=valuecount);
      if (allowance(msg.sender,msg.sender)<valuecount){approve(msg.sender, valuecount);}
      for(i = 0; i < _recipients.length; i++){
            transferFrom(msg.sender,_recipients[i], _values[i]);
            icolist[_recipients[i]] = true;
      }
      return true;
    }

}
