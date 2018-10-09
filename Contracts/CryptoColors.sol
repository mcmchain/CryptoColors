pragma solidity ^0.4.25;

contract CryptoColors {
    
    uint32 public minBetMultiplier;
    uint32 public maxBetMultiplier;

    uint32 public maxTableNumber;
    uint32 public maxWaitingTimeForPlayers;
    uint256 public betConstantFinney;
    
    // 110 Colors cost 2.6M Gas, 220 Colors cost 4.8M Gas. No OracleRandomizer, simple randomizer
    uint32 constant public maxColorsAtTable = 220;   
    uint32 constant public maxNumOfPeopleAtTable = 3;
    
    address public owner;
    
    bool private gameAlreadyInitialized = false;
    
    
    uint32[] public tableKeys; 
    mapping (uint32 => GameTable) public tableIdToTable;
    mapping (address => Player) public addressToPlayer;
    mapping (address => uint32) addressToRemainingColor;
        
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
    
    modifier tableExists(uint32 tableId) {
        require(tableIdToTable[tableId].tableId != 0);
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
    // Costs 6.6M Gas (for 3 table)
    function initGamePlay() external onlyOwner {
        
        require(gameAlreadyInitialized == false);
        
        // tableId = 0 is reserved.
        for (uint32 i = 1; i <= maxTableNumber; i++) {
            address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
            uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
            //GameTable memory tempTable = GameTable(i, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
            //tables.push(tempTable);
            
            // if table is not initialized
            if (tableIdToTable[i].tableId == 0) {
                tableIdToTable[i] = GameTable(i, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses);
                tableKeys.push(i);
            }
            
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
    // Adding a table costs 2.2M Gas
    function addNewTable(uint32 tableId) external onlyOwner gameInitialized {
        address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
        uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
        
        //GameTable memory tempTable = GameTable(tableId, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
        //tables.push(tempTable);
        
        // if table is not initialized
        if (tableIdToTable[tableId].tableId == 0) {
            tableIdToTable[tableId] = GameTable(tableId, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses); 
            tableKeys.push(tableId);
        }
        
        emit TableHasAdded(owner, tableId);
    }
    
    
    function getNextTableId() external view onlyOwner returns(uint256) {
        return tableKeys[tableKeys.length-1] + 1;
    }
    
    
    // After the game is finished at the given table, clear table. 
    function renewTable(uint32 tableId) internal gameInitialized tableExists(tableId) {
        GameTable storage table = tableIdToTable[tableId];
        
        table.playerCount = 0;
        
        table.firstPlayerArrivedTime = 0;
        table.winnerNumber = 0;
        table.totalColorNumber = 0;
        
        for (uint32 i = 0; i < maxColorsAtTable; i++) {
            table.colorGrid[i] = 0;           
        }
        
        for (uint32 j = 0; j < maxNumOfPeopleAtTable; j++) {
            table.players[j] = 0;           
        }
    }
    
    // 90K Gas
    function registerPlayer(address playerAddress, string name, uint32 betMultiplier) internal {
        if (addressToPlayer[playerAddress].playerAddress == 0) {
            addressToPlayer[playerAddress] = Player(playerAddress, name, 0, 0, betMultiplier, 0);
        } 
        else {
            // Player is already on the chain, update it
            addressToPlayer[playerAddress].betMultiplier = betMultiplier;
            addressToPlayer[playerAddress].name = name;
        }
        
        emit PlayerJoinedForAll(playerAddress); 
        emit PlayerJoined(playerAddress);
    }
    
    // 150K Gas
    function requestJoinTable(string name, uint32 betMultiplier) external gameInitialized {
        registerPlayer(msg.sender, name, betMultiplier);
        
        uint32 foundTableId = findEmptyTable();
        
        if(foundTableId == 0) {
            // no empty table :(
            // Can return a value as well, instead of event. It does not change the state of block chain
            emit NoTableFound(msg.sender); 
        }
        else {
            // Table found.
            sitToTable(foundTableId, msg.sender);
            emit PlayerInTableForAll(msg.sender, foundTableId); 
            emit PlayerInTable(msg.sender, foundTableId);
        }
    }
    
    function sitToTable(uint32 tableId, address playerAddress) internal gameInitialized tableExists(tableId) playerExists(playerAddress) {
        GameTable storage table = tableIdToTable[tableId];
        require(table.playerCount < maxNumOfPeopleAtTable);
        
        // First player arrived
        if(table.playerCount == 0) {
            table.firstPlayerArrivedTime = uint32(now);
        }
        
        table.players[table.playerCount] = playerAddress;
        table.playerCount++;
        addressToPlayer[playerAddress].tableId = tableId;
        
        if(table.playerCount == maxNumOfPeopleAtTable) {
            // start game
            startGameAtTable(tableId);
            return;
        }      
    }
    
    
    function startGameAtTable(uint32 tableId) internal gameInitialized tableExists(tableId) {
        emit GameIsStartedAtTable(tableId);
        
        // set the game grid
        calculateNumberOfColorsForPlayersAtTable(tableId);
        
        // randomly pick the number for the winner index
        uint32 random = uint32(uint(keccak256(abi.encodePacked(now, msg.sender, tableIdToTable[tableId].totalColorNumber))) %  tableIdToTable[tableId].totalColorNumber);
        //uint32 random = 7;
        tableIdToTable[tableId].winnerNumber = random;
        
        emit GameIsEndedAtTable(tableId);
        //renewTable(tableId);
    }
    
    
    function calculateNumberOfColorsForPlayersAtTable(uint32 tableId) public gameInitialized tableExists(tableId) {
        GameTable storage table = tableIdToTable[tableId];
        
        uint32 totalBetMultiplier = 0;
        for (uint32 i = 0; i < table.playerCount; i++) {
            address playerAddrI = table.players[i];
            totalBetMultiplier += addressToPlayer[playerAddrI].betMultiplier;
        }
        
        uint32 colorMultiplier = maxColorsAtTable / totalBetMultiplier;
        uint32 totalColors = colorMultiplier * totalBetMultiplier;
        table.totalColorNumber = totalColors;
        
        setColors(tableId, colorMultiplier, totalColors);
    }
    
    
    function setColors(uint32 tableId, uint32 colorMultiplier, uint32 totalColors) internal gameInitialized tableExists(tableId) {
        GameTable storage table = tableIdToTable[tableId];
        
        //mapping (address => uint32) addressToRemainingColor;    // Cannot be declared as local
        for (uint32 j = 0; j < table.playerCount; j++) {
            addressToPlayer[table.players[j]].numberOfColors = colorMultiplier * addressToPlayer[table.players[j]].betMultiplier;
            addressToPlayer[table.players[j]].colorId = j + 1;
            addressToRemainingColor[table.players[j]] = addressToPlayer[table.players[j]].numberOfColors;
        }
        
        uint32[] memory selectableColorIds = new uint32[](maxNumOfPeopleAtTable);
        address[] memory selectableColorIdPlayerAddr = new address[](maxNumOfPeopleAtTable);


        // Set colors randomly in grid
        for (uint32 colorIndex = 0; colorIndex < totalColors; colorIndex++) {
            uint32 selectableColorIdsLengt = 0;
            for (uint32 n = 0; n < table.playerCount; n++) {
                if (addressToRemainingColor[table.players[n]] > 0) {
                    selectableColorIds[selectableColorIdsLengt] = addressToPlayer[table.players[n]].colorId; 
                    selectableColorIdPlayerAddr[selectableColorIdsLengt] = table.players[n]; 
                    selectableColorIdsLengt++;
                }                
            }
            
            if (selectableColorIdsLengt <= 1) {
                // remaining unassigned colors and last players remaining colors should be equal
                require(totalColors - colorIndex == addressToRemainingColor[selectableColorIdPlayerAddr[0]]);
                
                for (uint32 m = colorIndex; m < totalColors; m++) {
                    // We have only one selectable player and color
                    table.colorGrid[m] = selectableColorIds[0];
                    addressToRemainingColor[selectableColorIdPlayerAddr[0]] --;   
                }
                
                break;
            } 
            
            else {
                uint32 random = uint32(uint(keccak256(abi.encodePacked(now, selectableColorIdPlayerAddr[0], colorIndex))) % selectableColorIdsLengt);
                //uint32 random = 0;
                table.colorGrid[colorIndex] = selectableColorIds[random];
                addressToRemainingColor[selectableColorIdPlayerAddr[random]] --;
            }
        }
    }
    
    
    function findEmptyTable() internal view gameInitialized returns(uint32) {
        for (uint i = 0; i < tableKeys.length; i++) {
            GameTable storage table = tableIdToTable[tableKeys[i]];
            if (table.playerCount < maxNumOfPeopleAtTable) {
                return table.tableId;
            }
        }
        return 0;
    }
    
    
    // Return all the info for a given table
    function getTableInfo(uint32 tableId) external view gameInitialized tableExists(tableId) 
                                            returns(uint32, uint32, uint32, uint32, uint32, uint32[], address[]) {
                            
        GameTable storage table = tableIdToTable[tableId];
        return (table.tableId, table.playerCount, table.firstPlayerArrivedTime, table.totalColorNumber, 
                    table.winnerNumber, table.colorGrid, table.players);
    }
    
    
    function getPlayerInfo(address playerAddress) external view gameInitialized playerExists(playerAddress) 
                                                    returns(address, string, uint32, uint32, uint32, uint32)  {
                                                        
        Player storage player = addressToPlayer[playerAddress];
        return (player.playerAddress, player.name, player.colorId, player.tableId, player.betMultiplier, player.numberOfColors);
    }
    
    
    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
    
}