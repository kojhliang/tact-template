import "@stdlib/deploy";

message Add {
    amount: Int as uint32;
}

message TestNumber {
    number: Int as uint32 ;
}

contract SampleTactContract with Deployable {

    owner: Address;
    counter: Int as uint32;
    testNumber: Int as uint32;

    init(owner: Address) {
        self.owner = owner;
        self.counter = 0;
        self.testNumber=0;
    }

    fun add(v: Int) {      
        // Check sender
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");
        
        // Update counter
        self.counter = (self.counter + v);
    }

    receive(msg: Add) {
        self.add(msg.amount);
    }

    receive("increment") {
        self.add(1);
        self.reply("incremented".asComment());
    }

    receive(msg: TestNumber) {
        self.testNumber=msg.number;
    }

    get fun counter(): Int {
        return self.counter;
    }

    get fun testNumber(): Int {
         return self.testNumber;
    }
}
