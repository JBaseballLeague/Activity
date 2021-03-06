/**
 *Submitted for verification at BscScan.com on 2022-01-12
*/

pragma solidity ^0.4.0;

library Address {

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
    
}

library Counters {
    using SafeMath for uint256;

    struct Counter {

        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}

interface ERC20 {
  function transfer(address _to, uint256 _value) external returns (bool);
  function balanceOf(address _owner) external view returns (uint256 balance);
  function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
  function totalSupply() external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
}

interface ERC721 {

    function owner() external view returns (address);//??????????????????
    function balanceOf(address owner) public view returns (uint256 balance);
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) public;
    function transferFrom(address from, address to, uint256 tokenId) public;
    function approve(address to, uint256 tokenId) public;
    function getApproved(uint256 tokenId) public view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) public;
    function isApprovedForAll(address owner, address operator) public view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public;

    function GRT_NFT_PRICE(uint256 tokenId) public view returns (uint256 price);
    function GRT_NFT_APY(uint256 tokenId) public view returns (uint256 apy);
    function GRT_NFT_TYPE(uint256 tokenId) public view returns (uint256 _type);
}

contract Staking{
    using SafeMath for uint256;

    ERC20 public JBL_token;
    ERC721 public NFT_token;
    ERC721 public NFT_token2;
    ERC721 public NFT_token3;

    address public contract_owner;
    uint256 public decimals = 18;
    uint256 public referrer = 10;//10% = (10/100) ??????????????????

    struct Order {
        address nft_addr;
        uint256 nft_id;
        uint256 nft_type;
        address user_addr;
        uint256 price;
        uint256 apy;
        uint256 start_time;
        uint256 end_time;
        uint256 withdraw_time;//??????????????????
    }

    mapping (address => bool) private nft_creator;//?????????NFT
    
    Order[] public Orders;
    mapping (uint256 => address) private user_order;// Order_id => User_addr
    mapping(address => uint256[]) private _OrderList;
    mapping (address => uint256) internal user_profit;//?????????

    // User_addr => Order_id[]
    mapping(address => uint256[]) private NFT_OF;// ????????? (type=0) 
    mapping(address => uint256[]) private NFT_IF;// ????????? (type=1)
    mapping(address => uint256[]) private NFT_C;// ?????? (type=2)
    mapping(address => uint256[]) private NFT_P;// ?????? (type=3)
    mapping(address => uint256[]) private NFT_H;// ????????? (type=5)

    event staking(address _user, address _nft_addr, uint _nft_id, uint256 _time, uint256 _order_id, uint256 withdraw_time);
    event redeem(address _user, uint256 _end_time, uint256 _order_id, uint256 _amount);
    event cal(uint256 _order_id, uint256 _nft_amount, uint256 _apy, uint256 _start_time, uint256 _end_time, uint256 _days);
    event cancel(address _user, address _nft_addr, uint _nft_id,  uint256 _order_id, uint256 return_time);
    event referrer_amount(address _referrer,uint256 _order_id, uint256 _amount, uint256 r_amount, uint256 referrer_num);
    
    constructor ()  public {
        contract_owner = msg.sender; 
        _set_JBL_TOKEN(0xf6e81be564a53f207081c39b9ce0d8f745d85202);
    }
    
    modifier onlyOwner() {
        require(msg.sender == contract_owner);
        _;
    }
    
    //pay token
    function _set_JBL_TOKEN(address _tokenAddr) internal onlyOwner{
        require(_tokenAddr != 0);
        JBL_token = ERC20(_tokenAddr);
    }
    
    // ??????
    function Staking_NFT(address _nft_addr,uint256 _nft_id) public returns (uint256) {
        NFT_token = ERC721(_nft_addr);
        address c_addr = get_nft_creator(_nft_addr);
        require(NFT_token.ownerOf(_nft_id)==msg.sender,"ERC721: owner query for nonexistent token");
        require(nft_creator[c_addr]==true,"ERC721: The contract is not certified.");

        NFT_token.transferFrom(msg.sender, address(this), _nft_id);

        uint256 _price = NFT_token.GRT_NFT_PRICE(_nft_id);
        uint256 _apy = NFT_token.GRT_NFT_APY(_nft_id);
        uint256 _type = NFT_token.GRT_NFT_TYPE(_nft_id);
        
        uint256 OrderId = Orders.length;
        uint256 insert_time = now;
        uint256 endtime = 0;

        uint256 _type_s = _type % 10; // ??????:????????????...
        uint256 withdraw_time;//??????????????????
        if(_type > 99)
        {
            uint256 _type_d = _type / 100 ; // 
            withdraw_time = now + (_type_d*30*86400);
        }
        else
        {
            withdraw_time = 9999999999;
            add_array_val(_type_s,msg.sender,OrderId);// ??????????????????array
        }

        Orders.push(Order(_nft_addr, _nft_id, _type, msg.sender, _price, _apy, insert_time, endtime, withdraw_time));
        
        user_order[OrderId] = msg.sender;

        _OrderList[msg.sender].push(OrderId);//??????OrderList

        // ????????????
        emit staking(msg.sender, _nft_addr, _nft_id, insert_time, OrderId, withdraw_time);
        
        return OrderId;
    }
    
    // ??????
    function Redeem_NFT(address referrer_1, address referrer_2, bool _rNFT, uint256 _order_id) public returns (bool){
        require(user_order[_order_id]==msg.sender,"This order is not own.");
        require(referrer_1!=msg.sender,"The referrer con not be yourself.(1)");
        require(referrer_2!=msg.sender,"The referrer con not be yourself.(2)");
        
        // ??????????????????
        Order storage order = Orders[_order_id];
        require(order.end_time==0,"This order is completed.");

        uint256 _amount = do_Redeem(_rNFT, _order_id);//????????????or???????????????
        if(_amount > 0)
        {
            uint256 r_amount = 0;
            r_amount = (_amount*referrer)/100;

            if(referrer_1 != address(0))
            {
                // ????????????1??????
                JBL_token.transfer(referrer_1, r_amount);// JBL-token ??????
                user_profit[referrer_1] = user_profit[referrer_1].add(r_amount);//???????????????

                // ????????????
                emit referrer_amount(referrer_1, _order_id, _amount, r_amount, referrer);
            }

            if(referrer_2 != address(0))
            {
                // ????????????2??????
                JBL_token.transfer(referrer_2, r_amount);// JBL-token ??????
                user_profit[referrer_2] = user_profit[referrer_2].add(r_amount);//???????????????

                // ????????????
                emit referrer_amount(referrer_2, _order_id, _amount, r_amount, referrer);
            }
        }
        return true;
    }

    // ????????????
    function do_Redeem(bool _rNFT,uint256 _order_id)internal returns (uint256){
        uint256 _etime = now;
        Order storage order = Orders[_order_id];

        uint256 _amount = 0;
        if(order.nft_type*1 > 99)
        {
            if(order.withdraw_time <= _etime)
            {
                _etime = order.withdraw_time; //??????????????????
            }
            _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);

            JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

            //???????????????
            user_profit[order.user_addr] = user_profit[order.user_addr].add(_amount);

            // ????????????
            emit redeem(msg.sender, _etime, _order_id, _amount);

            if(_rNFT==true) // NFT??????
            {
                NFT_token = ERC721(order.nft_addr);
                NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????

                // ??????????????????
                order.end_time = _etime;

                // ????????????array?????????
                del_array_val(order.nft_type % 10,order.user_addr,_order_id);

                //???user?????????????????? ??????
                delete_orderList(order.user_addr,_order_id);
            }
            else // ???????????????
            {
                // ????????????????????????
                order.start_time = _etime;
                // ??????????????????
                uint256 _type_d = order.nft_type*1 / 100 ; // 
                order.withdraw_time = now + (_type_d*30*86400);
            }
            
            return _amount;
        }
        else
        {
            Order storage order2;
            Order storage order3;
            uint256 order2_id;
            uint256 order3_id;
            uint256 _amount_0;
            uint256 _amount_1;
            uint256 _amount_2;

            if(order.nft_type % 10 ==0)
            {
                //?????????????????????APY
                if(NFT_OF[msg.sender].length >=1 && NFT_IF[msg.sender].length >=1 && NFT_H[msg.sender].length >=1)
                {
                    if(order.nft_type % 10 ==0)
                    {
                        order2 = Orders[NFT_IF[msg.sender][0]];
                        order3 = Orders[NFT_H[msg.sender][0]];

                        order2_id = NFT_IF[msg.sender][0];
                        order3_id = NFT_H[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==1)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_H[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_H[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==5)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_IF[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_IF[msg.sender][0];
                    }

                    if(order.nft_type % 10 ==0 || order.nft_type % 10 ==1 || order.nft_type % 10 ==5)
                    {
                        //APY???????????? 20%
                        order.apy = order.apy + (2*1*10**17); 
                        order2.apy = order2.apy + (2*1*10**17); 
                        order3.apy = order3.apy + (2*1*10**17); 

                        _amount_0 = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                        _amount_1 = cal_amount(order2_id, order2.price, order2.apy, order2.start_time, _etime);
                        _amount_2 = cal_amount(order3_id, order3.price, order3.apy, order3.start_time, _etime);

                        _amount = _amount_0 + _amount_1 + _amount_2;
                        JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                        if(_rNFT==true) // NFT??????
                        {
                            NFT_token = ERC721(order.nft_addr);
                            NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????

                            NFT_token2 = ERC721(order2.nft_addr);
                            NFT_token2.transferFrom(address(this), order2.user_addr, order2.nft_id);// NFT??????2

                            NFT_token3 = ERC721(order3.nft_addr);
                            NFT_token3.transferFrom(address(this), order3.user_addr, order3.nft_id);// NFT??????3

                            // ??????????????????
                            order.end_time = _etime;
                            order2.end_time = _etime;
                            order3.end_time = _etime;

                            // ????????????array?????????
                            del_array_val(order.nft_type % 10,order.user_addr,_order_id);
                            del_array_val(order2.nft_type % 10,order2.user_addr,order2_id);
                            del_array_val(order3.nft_type % 10,order3.user_addr,order3_id);

                            //???user?????????????????? ??????
                            delete_orderList(order.user_addr,_order_id);
                            delete_orderList(order2.user_addr,order2_id);
                            delete_orderList(order3.user_addr,order3_id);
                        }
                        else // ???????????????
                        {
                            // ????????????????????????
                            order.start_time = _etime;
                            order2.start_time = _etime;
                            order3.start_time = _etime;
                        }

                        // ????????????
                        emit redeem(msg.sender, _etime, _order_id, _amount_0);//?????????????????????
                        emit redeem(msg.sender, _etime, order2_id, _amount_1);//?????????????????????
                        emit redeem(msg.sender, _etime, order3_id, _amount_2);//?????????????????????

                        //???????????????
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_0);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_1);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_2);

                        return _amount;
                    }
                    
                }
                else if(NFT_P[msg.sender].length >=1 && NFT_C[msg.sender].length >=1 && NFT_OF[msg.sender].length >=1)
                {
                    if(order.nft_type % 10 ==3)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_C[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_C[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==2)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_P[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_P[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==0)
                    {
                        order2 = Orders[NFT_C[msg.sender][0]];
                        order3 = Orders[NFT_P[msg.sender][0]];

                        order2_id = NFT_C[msg.sender][0];
                        order3_id = NFT_P[msg.sender][0];
                    }

                    if(order.nft_type % 10 ==3 || order.nft_type % 10 ==2 || order.nft_type % 10 ==0)
                    {
                        //APY???????????? 20%
                        order.apy = order.apy + (2*1*10**17); 
                        order2.apy = order2.apy + (2*1*10**17); 
                        order3.apy = order3.apy + (2*1*10**17); 

                        _amount_0 = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                        _amount_1 = cal_amount(order2_id, order2.price, order2.apy, order2.start_time, _etime);
                        _amount_2 = cal_amount(order3_id, order3.price, order3.apy, order3.start_time, _etime);

                        _amount = _amount_0 + _amount_1 + _amount_2;
                        JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                        if(_rNFT==true) // NFT??????
                        {
                            NFT_token = ERC721(order.nft_addr);
                            NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????

                            NFT_token2 = ERC721(order2.nft_addr);
                            NFT_token2.transferFrom(address(this), order2.user_addr, order2.nft_id);// NFT??????2

                            NFT_token3 = ERC721(order3.nft_addr);
                            NFT_token3.transferFrom(address(this), order3.user_addr, order3.nft_id);// NFT??????3

                            // ??????????????????
                            order.end_time = _etime;
                            order2.end_time = _etime;
                            order3.end_time = _etime;

                            // ????????????array?????????
                            del_array_val(order.nft_type % 10,order.user_addr,_order_id);
                            del_array_val(order2.nft_type % 10,order2.user_addr,order2_id);
                            del_array_val(order3.nft_type % 10,order3.user_addr,order3_id);

                            //???user?????????????????? ??????
                            delete_orderList(order.user_addr,_order_id);
                            delete_orderList(order2.user_addr,order2_id);
                            delete_orderList(order3.user_addr,order3_id);
                        }
                        else // ???????????????
                        {
                            // ????????????????????????
                            order.start_time = _etime;
                            order2.start_time = _etime;
                            order3.start_time = _etime;
                        }

                        // ????????????
                        emit redeem(msg.sender, _etime, _order_id, _amount_0);//?????????????????????
                        emit redeem(msg.sender, _etime, order2_id, _amount_1);//?????????????????????
                        emit redeem(msg.sender, _etime, order3_id, _amount_2);//?????????????????????

                        //???????????????
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_0);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_1);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_2);

                        return _amount;
                    }
                    
                }
                else
                {
                    // "???"????????????
                    _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                    JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                    if(_rNFT==true) // NFT??????
                    {
                        NFT_token = ERC721(order.nft_addr);
                        NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????
                        
                        // ??????????????????
                        order.end_time = _etime;

                        // ????????????array?????????
                        del_array_val(order.nft_type % 10,order.user_addr,_order_id);

                        //???user?????????????????? ??????
                        delete_orderList(order.user_addr,_order_id);
                    }
                    else // ???????????????
                    {
                        // ????????????????????????
                        order.start_time = _etime;
                    }

                    // ????????????
                    emit redeem(msg.sender, _etime, _order_id, _amount);

                    //???????????????
                    user_profit[msg.sender] = user_profit[msg.sender].add(_amount);

                    return _amount;
                }
            }
            else if(order.nft_type % 10 ==1 || order.nft_type % 10 ==5)
            {
                //?????????????????????APY
                if(NFT_OF[msg.sender].length >=1 && NFT_IF[msg.sender].length >=1 && NFT_H[msg.sender].length >=1)
                {
                    if(order.nft_type % 10 ==0)
                    {
                        order2 = Orders[NFT_IF[msg.sender][0]];
                        order3 = Orders[NFT_H[msg.sender][0]];

                        order2_id = NFT_IF[msg.sender][0];
                        order3_id = NFT_H[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==1)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_H[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_H[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==5)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_IF[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_IF[msg.sender][0];
                    }

                    if(order.nft_type % 10 ==0 || order.nft_type % 10 ==1 || order.nft_type % 10 ==5)
                    {
                        //APY???????????? 20%
                        order.apy = order.apy + (2*1*10**17); 
                        order2.apy = order2.apy + (2*1*10**17); 
                        order3.apy = order3.apy + (2*1*10**17); 

                        _amount_0 = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                        _amount_1 = cal_amount(order2_id, order2.price, order2.apy, order2.start_time, _etime);
                        _amount_2 = cal_amount(order3_id, order3.price, order3.apy, order3.start_time, _etime);

                        _amount = _amount_0 + _amount_1 + _amount_2;
                        JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                        if(_rNFT==true) // NFT??????
                        {
                            NFT_token = ERC721(order.nft_addr);
                            NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????

                            NFT_token2 = ERC721(order2.nft_addr);
                            NFT_token2.transferFrom(address(this), order2.user_addr, order2.nft_id);// NFT??????2

                            NFT_token3 = ERC721(order3.nft_addr);
                            NFT_token3.transferFrom(address(this), order3.user_addr, order3.nft_id);// NFT??????3

                            // ??????????????????
                            order.end_time = _etime;
                            order2.end_time = _etime;
                            order3.end_time = _etime;

                            // ????????????array?????????
                            del_array_val(order.nft_type % 10,order.user_addr,_order_id);
                            del_array_val(order2.nft_type % 10,order2.user_addr,order2_id);
                            del_array_val(order3.nft_type % 10,order3.user_addr,order3_id);

                            //???user?????????????????? ??????
                            delete_orderList(order.user_addr,_order_id);
                            delete_orderList(order2.user_addr,order2_id);
                            delete_orderList(order3.user_addr,order3_id);
                        }
                        else // ???????????????
                        {
                            // ????????????????????????
                            order.start_time = _etime;
                            order2.start_time = _etime;
                            order3.start_time = _etime;
                        }

                        // ????????????
                        emit redeem(msg.sender, _etime, _order_id, _amount_0);//?????????????????????
                        emit redeem(msg.sender, _etime, order2_id, _amount_1);//?????????????????????
                        emit redeem(msg.sender, _etime, order3_id, _amount_2);//?????????????????????

                        //???????????????
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_0);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_1);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_2);

                        return _amount;
                    }
                    
                }
                else
                {
                    // "???"????????????
                    _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                    JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                    if(_rNFT==true) // NFT??????
                    {
                        NFT_token = ERC721(order.nft_addr);
                        NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????
                        
                        // ??????????????????
                        order.end_time = _etime;

                        // ????????????array?????????
                        del_array_val(order.nft_type % 10,order.user_addr,_order_id);

                        //???user?????????????????? ??????
                        delete_orderList(order.user_addr,_order_id);
                    }
                    else // ???????????????
                    {
                        // ????????????????????????
                        order.start_time = _etime;
                    }

                    // ????????????
                    emit redeem(msg.sender, _etime, _order_id, _amount);

                    //???????????????
                    user_profit[msg.sender] = user_profit[msg.sender].add(_amount);

                    return _amount;
                }
            }
            else if(order.nft_type % 10 ==2 || order.nft_type % 10 ==3)
            {
                //?????????????????????APY
                if(NFT_P[msg.sender].length >=1 && NFT_C[msg.sender].length >=1 && NFT_OF[msg.sender].length >=1)
                {
                    if(order.nft_type % 10 ==3)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_C[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_C[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==2)
                    {
                        order2 = Orders[NFT_OF[msg.sender][0]];
                        order3 = Orders[NFT_P[msg.sender][0]];

                        order2_id = NFT_OF[msg.sender][0];
                        order3_id = NFT_P[msg.sender][0];
                    }
                    else if(order.nft_type % 10 ==0)
                    {
                        order2 = Orders[NFT_C[msg.sender][0]];
                        order3 = Orders[NFT_P[msg.sender][0]];

                        order2_id = NFT_C[msg.sender][0];
                        order3_id = NFT_P[msg.sender][0];
                    }

                    if(order.nft_type % 10 ==3 || order.nft_type % 10 ==2 || order.nft_type % 10 ==0)
                    {
                        //APY???????????? 20%
                        order.apy = order.apy + (2*1*10**17); 
                        order2.apy = order2.apy + (2*1*10**17); 
                        order3.apy = order3.apy + (2*1*10**17); 

                        _amount_0 = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                        _amount_1 = cal_amount(order2_id, order2.price, order2.apy, order2.start_time, _etime);
                        _amount_2 = cal_amount(order3_id, order3.price, order3.apy, order3.start_time, _etime);

                        _amount = _amount_0 + _amount_1 + _amount_2;
                        JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                        if(_rNFT==true) // NFT??????
                        {
                            NFT_token = ERC721(order.nft_addr);
                            NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????

                            NFT_token2 = ERC721(order2.nft_addr);
                            NFT_token2.transferFrom(address(this), order2.user_addr, order2.nft_id);// NFT??????2

                            NFT_token3 = ERC721(order3.nft_addr);
                            NFT_token3.transferFrom(address(this), order3.user_addr, order3.nft_id);// NFT??????3

                            // ??????????????????
                            order.end_time = _etime;
                            order2.end_time = _etime;
                            order3.end_time = _etime;

                            // ????????????array?????????
                            del_array_val(order.nft_type % 10,order.user_addr,_order_id);
                            del_array_val(order2.nft_type % 10,order2.user_addr,order2_id);
                            del_array_val(order3.nft_type % 10,order3.user_addr,order3_id);

                            //???user?????????????????? ??????
                            delete_orderList(order.user_addr,_order_id);
                            delete_orderList(order2.user_addr,order2_id);
                            delete_orderList(order3.user_addr,order3_id);
                        }
                        else // ???????????????
                        {
                            // ????????????????????????
                            order.start_time = _etime;
                            order2.start_time = _etime;
                            order3.start_time = _etime;
                        }

                        // ????????????
                        emit redeem(msg.sender, _etime, _order_id, _amount_0);//?????????????????????
                        emit redeem(msg.sender, _etime, order2_id, _amount_1);//?????????????????????
                        emit redeem(msg.sender, _etime, order3_id, _amount_2);//?????????????????????

                        //???????????????
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_0);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_1);
                        user_profit[msg.sender] = user_profit[msg.sender].add(_amount_2);

                        return _amount;
                    }
                    
                }
                else
                {
                    // "???"????????????
                    _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                    JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                    if(_rNFT==true) // NFT??????
                    {
                        NFT_token = ERC721(order.nft_addr);
                        NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????
                        
                        // ??????????????????
                        order.end_time = _etime;

                        // ????????????array?????????
                        del_array_val(order.nft_type % 10,order.user_addr,_order_id);

                        //???user?????????????????? ??????
                        delete_orderList(order.user_addr,_order_id);
                    }
                    else // ???????????????
                    {
                        // ????????????????????????
                        order.start_time = _etime;
                    }

                    // ????????????
                    emit redeem(msg.sender, _etime, _order_id, _amount);

                    //???????????????
                    user_profit[msg.sender] = user_profit[msg.sender].add(_amount);

                    return _amount;
                }
            }
            else
            {
                // "???"????????????
                _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
                JBL_token.transfer(order.user_addr, _amount);// JBL-token ??????

                if(_rNFT==true) // NFT??????
                {
                    NFT_token = ERC721(order.nft_addr);
                    NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????
                    
                    // ??????????????????
                    order.end_time = _etime;

                    // ????????????array?????????
                    del_array_val(order.nft_type % 10,order.user_addr,_order_id);

                    //???user?????????????????? ??????
                    delete_orderList(order.user_addr,_order_id);
                }
                else // ???????????????
                {
                    // ????????????????????????
                    order.start_time = _etime;
                }

                // ????????????
                emit redeem(msg.sender, _etime, _order_id, _amount);

                //???????????????
                user_profit[msg.sender] = user_profit[msg.sender].add(_amount);

                return _amount;
            }

        }
    }

    // ?????????????????????
    function cal_amount(uint256 _order_id, uint256 _nft_amount, uint256 _apy, uint256 _stime, uint256 _etime)internal returns (uint256){
        uint256 _time = _etime - _stime;
        uint256 oneDay = 86400;

        uint256 _days = _time / oneDay;
        uint256 amount = (((_nft_amount*_apy))/365)*_days;

        // ????????????
        emit cal(_order_id, _nft_amount, _apy, _stime, _etime, _days);

        return amount;

    }

    // ?????????????????????
    function estimate(uint256 _order_id)public view returns (uint256){
        Order storage order = Orders[_order_id];
        uint256 _etime = now;
        uint256 _amount = cal_amount(_order_id, order.price, order.apy, order.start_time, _etime);
        return _amount;
    }

    //??????(JBL-token)
    function withdraw() public onlyOwner{
        address contract_addr = address(this);
        uint256 contract_balance = JBL_token.balanceOf(contract_addr);
        JBL_token.transfer(msg.sender, contract_balance);
        
    }

    //?????? (??????NFT????????????)
    function return_NFT(uint256 _order_id) public onlyOwner{
        Order storage order = Orders[_order_id];

        NFT_token = ERC721(order.nft_addr);
        require(NFT_token.ownerOf(order.nft_id)==address(this),"ERC721: owner query for nonexistent token");
        require(order.end_time==0,"This order is completed.");
        NFT_token.transferFrom(address(this), order.user_addr, order.nft_id);// NFT??????
        
        // ??????????????????
        order.end_time = 999;

        //???user?????????????????? ??????
        delete_orderList(order.user_addr,_order_id);

        emit cancel(order.user_addr, order.nft_addr, order.nft_id, _order_id, now);
    }

    //??????or??????JBL - byOwner
    function Redeem_NFT_byOwner(address referrer_1, address referrer_2, bool _rNFT, uint256 _order_id) public onlyOwner returns (bool){
        // ??????????????????
        Order storage order = Orders[_order_id];
        require(order.end_time==0,"This order is completed.");

        uint256 _amount = do_Redeem(_rNFT, _order_id);//????????????or???????????????
        if(_amount > 0)
        {
            uint256 r_amount = 0;
            r_amount = (_amount*referrer)/100;

            if(referrer_1 != address(0))
            {
                // ????????????1??????
                JBL_token.transfer(referrer_1, r_amount);// JBL-token ??????
                user_profit[referrer_1] = user_profit[referrer_1].add(r_amount);//???????????????

                // ????????????
                emit referrer_amount(referrer_1, _order_id, _amount, r_amount, referrer);
            }

            if(referrer_2 != address(0))
            {
                // ????????????2??????
                JBL_token.transfer(referrer_2, r_amount);// JBL-token ??????
                user_profit[referrer_2] = user_profit[referrer_2].add(r_amount);//???????????????

                // ????????????
                emit referrer_amount(referrer_2, _order_id, _amount, r_amount, referrer);
            }
        }
        return true;
        
    }

    // user????????????(?????????)
    function orderList(address addr) public view returns (uint256[]) {
        return _OrderList[addr];
    }

    // ???user?????????????????? ??????
    function delete_orderList(address addr,uint256 _tokenid) internal {
    
        for (uint j = 0; j < _OrderList[addr].length; j++) {
            if(_OrderList[addr][j]==_tokenid)
            {
                delete _OrderList[addr][j];
                for (uint i = j; i<_OrderList[addr].length-1; i++){
                    _OrderList[addr][i] = _OrderList[addr][i+1];
                }
                delete _OrderList[addr][_OrderList[addr].length-1];
                _OrderList[addr].length--;
            }
        }
    }

    // ?????????
    function get_profit(address _owner) public view returns (uint256){
        return user_profit[_owner];
    }

    // ??????array????????????
    function add_array_val(uint256 _t,address addr,uint256 _oid) internal {
        // 0=?????????(OF), 1=?????????(IF), 2=??????(C), 3=??????(P), 5=?????????(H)
        uint256[] _ar;
        if(_t==0)
        {
            _ar = NFT_OF[addr];
            _ar.push(_oid);
        }
        else if(_t==1)
        {
            _ar = NFT_IF[addr];
            _ar.push(_oid);
        }
        else if(_t==2)
        {
            _ar = NFT_C[addr];
            _ar.push(_oid);
        }
        else if(_t==3)
        {
            _ar = NFT_P[addr];
            _ar.push(_oid);
        }
        else if(_t==5)
        {
            _ar = NFT_H[addr];
            _ar.push(_oid);
        }
    }

    // ??????array????????????
    function del_array_val(uint256 _t,address addr,uint256 _oid) internal {
        // 0=?????????(OF), 1=?????????(IF), 2=??????(C), 3=??????(P), 5=?????????(H)
        uint256[] _ar;
        if(_t==0)
        {
            _ar = NFT_OF[addr];
        }
        else if(_t==1)
        {
            _ar = NFT_IF[addr];
        }
        else if(_t==2)
        {
            _ar = NFT_C[addr];
        }
        else if(_t==3)
        {
            _ar = NFT_P[addr];
        }
        else if(_t==5)
        {
            _ar = NFT_H[addr];
        }

        if(_t==0 || _t==1 || _t==2 || _t==3 || _t==5)
        {
            for (uint j = 0; j < _ar.length; j++) 
            {
                if(_ar[j]==_oid)
                {
                    delete _ar[j];
                    for (uint i = j; i<_ar.length-1; i++){
                        _ar[i] = _ar[i+1];
                    }
                    delete _ar[_ar.length-1];
                    _ar.length--;
                }
            }
        }
    }

    // ????????????or?????????NFT
    function set_nft_creator(address _addr,bool _type)public onlyOwner{
        nft_creator[_addr] = _type;
    }

    // ??????NFT????????????
    function get_nft_creator(address _nft_addr) public view returns (address) {
        return ERC721(_nft_addr).owner();
    }

    // ???????????????????????? (%)
    function set_referrer(uint256 _r)public onlyOwner{
        require(_r >= 0,"Must be a number greater than 0.");
        referrer = _r;
    }

}