# 完成作业过程中，需要注意的点：    
 1.receive函数中的处理，如果不reply的话，不会返回多余的Ton给发送者。  
   
 2.如果想让返回的消息更加让人理解，需要使用StringBuilder手动构造返回的字符串内容。 
   
 3.contract.write.ts的代码中，如果发送多次write交易，只有第一次的会成功，其他都会失败。需要确保结束一次交易后，再发送下一次交易。      
   
 4.合约/账户地址的显示格式，在测试网中有0Q和EQ开头的地址两种格式的地址，但都是对应同一个合约。这点一个合约有多种地址格式，很容易让初学者比较困惑。 
   
 5. 使用以下代码后：  
    const walletContract = client.open(wallet);  
    const walletSender = walletContract.sender(key.secretKey);  
    如果使用walletSender.address as Address 这样的方式，获取到的address会为undefined，因此不能使用这样的方式获取钱包地址。  
