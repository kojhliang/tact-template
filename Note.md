# 完成作业过程中，需要注意的点：    
 1.receive函数中的处理，如果不reply的话，不会返回多余的Ton给发送者。  
   
 2.如果想让返回的消息更加让人理解，需要使用StringBuilder手动构造返回的字符串内容。 
   
 3.contract.write.ts的代码中，如果发送多次write交易，只有第一次的会成功，其他都会失败。需要确保结束一次交易后，再发送下一次交易。      
   
 4.合约/账户地址的显示格式，在测试网中有0Q和KQ开头的地址两种格式的地址，但都是对应同一个合约。这点一个合约有多种地址格式，很容易让初学者比较困惑。 
   以下是4种地址格式的说明：主网有 EQ（业务合约）和UQ（钱包）的前缀，测试网络有KQ（业务合约）和0Q（钱包）的前缀
   <img width="905" alt="主网业务合约地址 EQA XoUfrerc2eJwW62L9U7ZW_ BiA6VUWTQec" src="https://github.com/kojhliang/tact-template/assets/24265284/d4085a0b-3bfb-4e20-8ca4-b923a0eb0b3c">

   
 5. 使用以下代码后：  
    const walletContract = client.open(wallet);  
    const walletSender = walletContract.sender(key.secretKey);  
    如果使用walletSender.address as Address 这样的方式，获取到的address会为undefined，因此不能使用这样的方式获取钱包地址。
  
 6.测试FT的Jetton转帐时，如果新注册一个钱包账户，即使已经使用机器人水龙头获得一定的测试Ton coin，并且调用Jetton Master合约mint了一定Jetton币到这个钱包账户，这个钱包账户的状态依然是uninit状态，必须要主动使用这个钱包执行一次交易，可以是发送Ton coin或者发送Jetton 币到其他地址后，这样钱包的状态才会更改成Active.  
  
 7.get 的方法只是给链下的客户端去调用的，不是给合约调用的，如果想让合约调用获取数据，必须要使用receive方法。  
  
 8.发送消息时如果Mode包含SendPayGasSeparately，如果加上的话，发送消息给其他合约时，直接从当前合约的余额Ton coin中扣，如果不加上的话，从发送消息附带的余额中扣。  
