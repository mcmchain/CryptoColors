pragma solidity ^0.4.24;

contract CryptoColors {
    
    uint32 public minBetMultiplier;
    uint32 public maxBetMultiplier;

    uint32 public maxTableNumber;
    uint32 public maxWaitingTimeForPlayers;
    uint256 public betConstantFinney;
    
    uint32 constant public maxColorsAtTable = 330;
    uint32 constant public maxNumOfPeopleAtTable = 3;
    
    address public owner;
    
    GameTable[] public tables; 


    struct GameTable {
        uint32 tableId;
        uint32 playerCount;
        uint32 firstPlayerArrivedTime;
        uint32 totalColorNumber;
        uint32 winnerNumber;
        uint32[] colorGrid;
        address[] players;
    }
    
    // Constructor
    constructor() public {
        owner = msg.sender;                     // Owner = Address of the publisher
        
        betConstantFinney = 30 finney;          // 0.03 ether, finney = milli-eth 
        minBetMultiplier = 1;                   // minBetVal = 1  * betConstantFinney = 30  finney = 0.03 eth
        maxBetMultiplier = 33;                  // maxBetVal = 33 * betConstantFinney = 990 finney = 0.99 eth  
        
        maxTableNumber = 3;                     // Initialization of 3 tables cost 7.5 M Gas  (Max allowed 8M Gas)
        maxWaitingTimeForPlayers = 3 minutes;   // wait for players max 3 min
    }
    
    
    function initGamePlay() external {
        // tableId = 0 is reserved.
        for (uint32 i = 1; i <= maxTableNumber; i++) {
            address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
            uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
            GameTable memory tempTable = GameTable(i, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
            tables.push(tempTable);
        }
    }
    
    
    function getTableInfo(uint32 tableId) external view returns(uint32, uint32, uint32, uint32, uint32[], address[]) {
        GameTable storage table = tables[tableId];
        return (table.playerCount, table.firstPlayerArrivedTime, table.totalColorNumber, table.winnerNumber, table.colorGrid, table.players);
    }
}