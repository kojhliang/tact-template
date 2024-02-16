//**** message
message(0x693d3950) GetRoyaltyParams {
    query_id: Int as uint64;
}
message(0xa8cb00ad) ReportRoyaltyParams {
    query_id: Int as uint64;
    numerator: Int as uint16;
    denominator: Int as uint16;
    destination: Address;
}
struct CollectionData {
    next_item_index: Int;
    collection_content: Cell;
    owner_address: Address;
}
struct RoyaltyParams {
    numerator: Int;
    denominator: Int;
    destination: Address;
}
message(0x5fcc3d14) Transfer {
    query_id: Int as uint64;
    new_owner: Address;
    response_destination: Address;
    custom_payload: Cell?;
    forward_amount: Int as coins;
    forward_payload: Slice as remaining;
}

message(0x05138d91) OwnershipAssigned {
    query_id: Int as uint64;
    prev_owner: Address;
    forward_payload: Slice as remaining;
}
message(0xd53276db) Excesses {
    query_id: Int as uint64;
}
message(0x2fcb26a2) GetStaticData {
    query_id: Int as uint64;
}
message(0x8b771735) ReportStaticData {
    query_id: Int as uint64;
    index_id: Int;
    collection: Address;
}
struct GetNftData {
    is_initialized: Bool;
    index: Int;
    collection_address: Address;
    owner_address: Address;
    individual_content: Cell;
}

//*****NftItem contract

contract NftItem {
    collection_address: Address;
    item_index: Int;  //即NFT ID
    is_initialized: Bool;

    owner: Address?;
    individual_content: Cell?;

    init(collection_address: Address, item_index: Int){
        self.collection_address = collection_address;
        self.item_index = item_index;
        self.is_initialized = false;
    }

    receive(msg: Transfer){
        let ctx: Context = context();     
        // require(ctx.sender == self.owner, "not owner");
        let msgValue: Int = ctx.value; // Check the gasCost for storage
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        msgValue = msgValue - (storageFee + gasConsumption);
        
        if (self.is_initialized == false) {  // Initial Transfer, aka the "Minting" of the NFT
            //require(ctx.sender == self.collection_address, "initialized tx need from collection");
            self.is_initialized = true;
            self.owner = msg.new_owner;
            send(SendParameters{
                to: msg.response_destination,
                value: 0,
                mode: SendIgnoreErrors + SendRemainingValue,
                body: Excesses { query_id: msg.query_id }.toCell()
            });
        } else {
            require(ctx.sender==self.owner,"Only owner can tansfer the NFT");
            self.owner = msg.new_owner;  // change current owner to the new_owner
            if (msg.forward_amount > 0) {   
                send(SendParameters{     //发送通知给NFT的新的Owner
                    to: msg.new_owner,
                    value: msg.forward_amount,
                    mode: SendIgnoreErrors + SendPayGasSeparately, 
                    bounce: true,
                    body: OwnershipAssigned{
                        query_id: msg.query_id,
                        prev_owner: ctx.sender,
                        forward_payload: msg.forward_payload
                    }.toCell()
                }); 
            }

            msgValue = msgValue - ctx.readForwardFee();  
            if (msg.response_destination != null) {  //把多余的gas fee返还给原来的NFT拥有者（即发起这次交易的发起者）
                send(SendParameters{ 
                    to: msg.response_destination,   //这里本质是原来的拥有者的钱包地址
                    value: msgValue - msg.forward_amount,
                    mode: SendPayGasSeparately,
                    bounce: true,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            } 
        }
    }
    
    receive(msg: GetStaticData){ 
        let ctx: Context = context();
        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: 64,  // (return msg amount except gas fees) 
            bounce: true,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.item_index,
                collection: self.collection_address
            }.toCell()
        });
    }

    // --------- Get Function  --------- //
    get fun get_nft_data(): GetNftData {
        let b: StringBuilder = beginString();
        let collectionData: String = (self.individual_content!!).asSlice().asString();
        b.append(collectionData);
        b.append(self.item_index.toString());
        b.append(".json");

        return GetNftData {
            is_initialized: self.is_initialized, 
            index: self.item_index, 
            collection_address: self.collection_address, 
            owner_address: self.owner!!,
            individual_content: b.toCell()
        };
    }
}

//****** CollectionUser Contract

message CheckAndMint {
    sender: Address;
    item_index: Int;
}
message ExceedMaxMintTimes {
    query_id:Int;
}



contract CollectionUser {
    mint_times: Int as uint32 = 0;
    user_address: Address;
    collection_address: Address;
    init(collection_address: Address, user_address: Address){
        self.collection_address = collection_address;
        self.user_address = user_address;
    }

    receive(msg: CheckAndMint){
        //因为如果使用bounced的方式无法附带数据，所以这里不使用bounced的方式，只能使用手动把多余的gas fee返回给最初的发送者
        // require(self.mint_times>=3,"Exceed max mint times:3");
        if (self.mint_times >= 3) {
            send(SendParameters{
                    to: msg.sender, //address("0QAxELnSBTtQqBeKaD6NZ9tLc4D15K_uuQXZ8ZSUIPrQ9a6i")
                    value: 0,
                    mode: (SendIgnoreErrors + SendRemainingValue),
                    body: ExceedMaxMintTimes{query_id:0}.toCell()
                }
            );
            return ;
        } else {          
            let nft_init: StateInit = initOf NftItem(self.collection_address, msg.item_index);
            send(SendParameters{
                    to: contractAddress(nft_init),
                    value: 0,
                    bounce: false,
                    mode: (SendIgnoreErrors + SendRemainingValue),
                    body: Transfer{
                        query_id: 0,
                        new_owner: self.user_address,
                        response_destination: msg.sender,
                        custom_payload: emptyCell(),
                        forward_amount: 0,
                        forward_payload: emptySlice()
                    }.toCell(),
                    code: nft_init.code,
                    data: nft_init.data
                }
            );
            self.mint_times = (self.mint_times + 1);
        }
    }

    get fun get_mint_times(): Int {
        return self.mint_times;
    }
}

//**** NFT collection Contract
const minTonsForStorage: Int = ton("0.03");
const gasConsumption: Int = ton("0.03");

message EventMintRecord {
    minter: Address;
    item_id: Int;
    generate_number: Int;
}

message EventMintForOtherRecord {
    minter: Address;
    nft_owner:Address;
    item_id: Int;
    generate_number: Int;
}

message MintNftForOther{
     nft_owner:Address;
 }


contract NftCollection {
    next_item_index: Int as uint32 = 0;
    owner_address: Address;
    royalty_params: RoyaltyParams?;                      
    collection_content: Cell;   

    init(owner_address: Address, collection_content: Cell, royalty_params: RoyaltyParams){
        self.owner_address = owner_address;
        self.collection_content = collection_content; 
        self.royalty_params = royalty_params;
    }

    //调用逻辑 collection合约--》collectionUser合约---》NftItem合约
    receive(msg:MintNftForOther){
        let ctx: Context = context(); // get sender Info

        //check if this nft_owner exceed the max mint times(3 times)
        let msgValue: Int = ctx.value;
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        msgValue = msgValue - (storageFee + gasConsumption);
        self.mintForOther(ctx.sender, msgValue,msg.nft_owner);
    }

     // ===== Private Methods ===== //
    fun mintForOther(sender: Address, msgValue: Int,nftOwner:Address) {
        require(self.next_item_index >= 0, "non-sequential NFTs");
        let collection_user_init: StateInit = self.getCollectionUserInit(nftOwner);    
        self.next_item_index = self.next_item_index + 1;  
        send(SendParameters{
                to: contractAddress(collection_user_init), 
                value: msgValue, 
                bounce: true,
                mode: SendIgnoreErrors,
                body: CheckAndMint {
                    sender:sender,
                    item_index:self.next_item_index
                }.toCell(),
                code: collection_user_init.code,
                data: collection_user_init.data
            });
        // dump(self.next_item_index);
        
    }

   
    receive("Mint"){
        let ctx: Context = context(); // get sender Info
        let msgValue: Int = ctx.value;
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        msgValue = msgValue - (storageFee + gasConsumption);
        self.mint(ctx.sender, msgValue);

        emit(EventMintRecord{
            minter: sender(), 
            item_id: self.next_item_index, 
            generate_number: nativeRandom() 
        }.toCell());
        
    }

    // ===== Private Methods ===== //
    fun mint(sender: Address, msgValue: Int) {
        require(self.next_item_index >= 0, "non-sequential NFTs");
        let nft_init: StateInit = self.getNftItemInit(self.next_item_index);
        send(SendParameters{
                to: contractAddress(nft_init), 
                value: msgValue, 
                bounce: false,
                mode: SendIgnoreErrors,
                body: Transfer {
                    query_id: 0,
                    new_owner: sender,
                    response_destination: self.owner_address,
                    custom_payload: emptyCell(),
                    forward_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: nft_init.code,
                data: nft_init.data
            });
        // dump(self.next_item_index);
        self.next_item_index = self.next_item_index + 1;
    }

    receive(msg: GetRoyaltyParams) {   
        let ctx: Context = context(); // get sender Info
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            mode: 64, 
            bounce: false,
            body: ReportRoyaltyParams {
                query_id: msg.query_id,
                numerator:  (self.royalty_params!!).numerator,
                denominator: (self.royalty_params!!).denominator,
                destination: self.owner_address
            }.toCell()
        });        
    }

    // ------------------ Get Function  ------------------ //
    get fun get_collection_data(): CollectionData {     
        let b: StringBuilder = beginString();
        let collectionDataString: String = self.collection_content.asSlice().asString();
        b.append(collectionDataString);
        b.append("meta.json"); // You can changed this your self.
        return CollectionData{
            next_item_index: self.next_item_index, 
            collection_content: b.toCell(), 
            owner_address: self.owner_address
        };
    }

    get fun get_nft_address_by_index(item_index: Int): Address?{      
        let initCode: StateInit = self.getNftItemInit(item_index);
        return contractAddress(initCode);
    }

    get fun getNftItemInit(item_index: Int): StateInit {
        return initOf NftItem(myAddress(), item_index);
    }

    get fun getCollectionUserInit(user_address:Address): StateInit {
        return initOf CollectionUser(myAddress(), user_address);
    }
    
    get fun get_nft_content(index: Int, individual_content: Cell): Cell { 
        let b: StringBuilder = beginString();
        let ic: String = individual_content.asSlice().asString();
        b.append(ic);
        return b.toCell();
    }

    get fun royalty_params(): RoyaltyParams {
        return self.royalty_params!!;
    }
}
