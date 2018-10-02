pragma solidity ^0.4.25;

contract CryptoColors {
    
    uint32 public minBetMultiplier;
    uint32 public maxBetMultiplier;

    uint32 public maxTableNumber;
    uint32 public maxWaitingTimeForPlayers;
    uint256 public betConstantFinney;
    
    uint32 constant public maxColorsAtTable = 330;
    uint32 constant public maxNumOfPeopleAtTable = 3;
    
    address public owner;
    
    bool private gameAlreadyInitialized = false;
    
    
    GameTable[] public tables; 
    mapping (address => Player) public addressToPlayer;

    struct GameTable {
        uint32 tableId;
        uint32 playerCount;
        uint32 firstPlayerArrivedTime;
        uint32 totalColorNumber;
        uint32 winnerNumber;
        uint32[] colorGrid;
        address[] players;
    }
    
     struct Player {
        address playerAddress;
        string name;
        uint32 colorId;
        uint32 tableId;
        uint32 betMultiplier;
        uint32 numberOfColors; 
    }
    
    modifier onlyOwner {
         require (msg.sender == owner);
         _;
    }
    
    modifier gameInitialized {
        require(gameAlreadyInitialized == true);
        _;
    }
    
    modifier tableNotExists(uint32 tableId) {
        bool found = false;
        for (uint32 i = 0; i < tables.length; i++) {
            if (tables[i].tableId == tableId) {
                found = true;
                break;
            }
        }
        require(found == false);
        _;
    }
    
    modifier playerExists(address playerAddress) {
        require(addressToPlayer[playerAddress].playerAddress != 0);
        _;
    }

    modifier isValidBet(uint betValue) {
        require(betValue >= minBetMultiplier && betValue <= maxBetMultiplier);
        _;
    }
     
    
    event PlayerJoinedForAll(address playerAddress); 
    event PlayerJoined(address indexed playerAddress);
    event PlayerInTableForAll(address playerAddress, uint32 tableId); 
    event PlayerInTable(address indexed playerAddress, uint32 tableId);
    
    event NoTableFound(address indexed playerAddress);
    
    event GameIsStartedAtTable(uint32 tableId);
    event GameIsEndedAtTable(uint32 tableId);
    event TableHasAdded(address indexed owner, uint32 tableId);

    event PlayerWon(address indexed playerAddress);
    event PlayerLost(address indexed playerAddress);
    event PlayerIsPaid(address indexed playerAddress);
    
    
    // Constructor
    // Creation costs 2M Gas
    constructor() public {
        owner = msg.sender;                     // Owner = Address of the publisher
        
        betConstantFinney = 30 finney;          // 0.03 ether, finney = milli-eth 
        minBetMultiplier = 1;                   // minBetVal = 1  * betConstantFinney = 30  finney = 0.03 eth
        maxBetMultiplier = 33;                  // maxBetVal = 33 * betConstantFinney = 990 finney = 0.99 eth  
        
        maxTableNumber = 3;                     // Initialization of 3 tables cost 7.5 M Gas  (Max allowed 8M Gas)
        maxWaitingTimeForPlayers = 3 minutes;   // wait for players max 3 min
    }
    
    
    // Init all the tables. This should be called after the contract is constructed
    // Costs 6M Gas (for 3 table)
    function initGamePlay() external onlyOwner {
        
        require(gameAlreadyInitialized == false);
        
        // tableId = 0 is reserved.
        for (uint32 i = 1; i <= maxTableNumber; i++) {
            address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
            uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
            GameTable memory tempTable = GameTable(i, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
            tables.push(tempTable);
        }
        
        gameAlreadyInitialized = true;
    }
    
    
    // Get the game variables, onlyOwner can get it  
    function getConstantGameVariables() external view onlyOwner returns(uint32, uint32, uint32, uint256, uint32) {
        return (minBetMultiplier, maxBetMultiplier, maxTableNumber, betConstantFinney, maxWaitingTimeForPlayers);
    }
    
    
    // Change the game vars. Only admin (owner) can change
    function setGameVars(uint32 argMinBetMultiplier, uint32 argMaxBetMultiplier, uint32 argMaxTableNumber, uint256 argBetConstantFinney, 
                         uint32 argMaxWaitingTimeForPlayers) external onlyOwner {
                             
        minBetMultiplier = argMinBetMultiplier;
        maxBetMultiplier = argMaxBetMultiplier;
        maxTableNumber = argMaxTableNumber;
        betConstantFinney = argBetConstantFinney;
        maxWaitingTimeForPlayers = argMaxWaitingTimeForPlayers;
    }
    
    
    // Admin can increase the number of tables 
    // Adding a table costs 2M Gas
    function addNewTable(uint32 tableId) external onlyOwner gameInitialized tableNotExists(tableId) {
        address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
        uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
        GameTable memory tempTable = GameTable(tableId, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
        tables.push(tempTable);
        
        emit TableHasAdded(owner, tableId);
    }
    
    
    function getNextTableId() external view onlyOwner returns(uint256) {
        return tables.length + 1;
    }
    
    
    // Return all the info for a given table
    function getTableInfo(uint32 tableId) external view gameInitialized returns(uint32, uint32, uint32, uint32, uint32, uint32[], address[]) {
        GameTable storage table = tables[0];
        bool found = false;
        
        for (uint32 i = 0; i < tables.length; i++) {
            if (tables[i].tableId == tableId) {
                found = true;
                table = tables[i];
                break;
            }
        }
        
        require(found == true);
        return (table.tableId, table.playerCount, table.firstPlayerArrivedTime, table.totalColorNumber, table.winnerNumber, table.colorGrid, table.players);
    }
    
    
    function getPlayerInfo(address playerAddress) external view gameInitialized playerExists(playerAddress) returns(string, uint32)  {
        return (addressToPlayer[playerAddress].name, addressToPlayer[playerAddress].betMultiplier);
    }
    
    
    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
    
    
    // Just for test purposes. Set dummy values to the tables.
    function setDummyValuesToTable(uint32 tableId) external gameInitialized {
        GameTable storage table = tables[0];
        bool found = false;
        
        for (uint32 t = 0; t < tables.length; t++) {
            if (tables[t].tableId == tableId) {
                found = true;
                table = tables[t];
                break;
            }
        }
        
        require(found == true);
        
        table.winnerNumber = tableId + maxNumOfPeopleAtTable;
        table.players[tableId % maxNumOfPeopleAtTable] = owner;

        /*
        uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
        for (uint32 i = 0; i < maxColorsAtTable; i++) {
            tempColorGrid[i] = i * tableId * 10;
        }
        table.colorGrid = tempColorGrid;
 
        
        address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
        for (uint32 j = 0; j < maxNumOfPeopleAtTable; j++) {
            tempPlayerAddresses[j] = owner;
        }
        table.players = tempPlayerAddresses;
        */
        
        // Above code and below cost the same  2.6 M gas
        
        for (uint32 i = 0; i < maxColorsAtTable; i++) {
            table.colorGrid[i] = i * tableId * 10;
        }
 
        for (uint32 j = 0; j < maxNumOfPeopleAtTable; j++) {
            table.players[j] = owner;
        }
    }
}