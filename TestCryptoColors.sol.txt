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
    
    mapping (address => Player) public addressToPlayer;
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
    
    modifier tableExists(uint32 tableId) {
        bool found = false;
        for (uint32 i = 0; i < tables.length; i++) {
            if (tables[i].tableId == tableId) {
                found = true;
                break;
            }
        }
        require(found == true);
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

    event PlayerWon(address indexed playerAddress);
    event PlayerLost(address indexed playerAddress);
    event PlayerIsPaid(address indexed playerAddress);


    // Constructor
    constructor() public {
        owner = msg.sender;                     // Owner = Address of the publisher
        
        betConstantFinney = 30 finney;          // 0.03 ether, finney = milli-eth 
        minBetMultiplier = 1;                   // minBetVal = 1  * betConstantFinney = 30  finney = 0.03 eth
        maxBetMultiplier = 33;                  // maxBetVal = 33 * betConstantFinney = 990 finney = 0.99 eth  
        
        maxTableNumber = 1;
        maxWaitingTimeForPlayers = 3 minutes;   // wait for players max 3 min
    }
    
    
    // Change the game vars. Only admin (owner) can change
    function setGameVars(uint32 argMinBetMultiplier, uint32 argMaxBetMultiplier, uint32 argMaxTableNumber, uint256 argBetConstantFinney, 
                         uint32 argMaxWaitingTimeForPlayers) public onlyOwner {
                             
        minBetMultiplier = argMinBetMultiplier;
        maxBetMultiplier = argMaxBetMultiplier;
        maxTableNumber = argMaxTableNumber;
        betConstantFinney = argBetConstantFinney;
        maxWaitingTimeForPlayers = argMaxWaitingTimeForPlayers;
    }
    

    function initGamePlay() public onlyOwner {
        // tableId = 0 is reserved.
        for (uint32 i = 1; i <= maxTableNumber; i++) {
            //address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
            //uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
            address[] memory tempPlayerAddresses;
            uint32[] memory tempColorGrid;
            tables.push(GameTable(i, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses));
            //GameTable storage table = tables[i];
            //table.colorGrid = new uint32[](maxColorsAtTable);
            //table.players = new address[](maxNumOfPeopleAtTable);
        }
    }
    
    // Admin can increase the number of tables 
    function addNewTable(uint32 tableId) public onlyOwner tableNotExists(tableId) {
        address[] memory tempPlayerAddresses = new address[](maxNumOfPeopleAtTable);
        uint32[] memory tempColorGrid = new uint32[](maxColorsAtTable);
        tables.push(GameTable(tableId, 0, 0, 0, 0, tempColorGrid, tempPlayerAddresses));
    }
    
    
    // After the game is finished at the given table, clear table. 
    function renewTable(uint32 tableId) internal tableExists(tableId) {
        GameTable storage table = tables[tableId];
        table.playerCount = 0;
        table.firstPlayerArrivedTime = 0;
        
        for (uint32 i = 0; i < maxColorsAtTable; i++) {
            table.colorGrid[i] = 0;           
        }
    }

    function findEmptyTable() private view returns(uint32) {
        for (uint i = 0; i < tables.length; i++) {
            if (tables[i].playerCount < maxNumOfPeopleAtTable) {
                return tables[i].tableId;
            }
        }
        return 0;
    }

    function requestJoinTable(string name, uint32 betMultiplier) external {
        registerPlayer(msg.sender, name, betMultiplier);
        
        uint32 foundTableId = findEmptyTable();
        
        if(foundTableId == 0) {
            // no empty table :(
            emit NoTableFound(msg.sender);
        }
        else {
            // Table found.
            sitToTable(foundTableId, msg.sender);
            emit PlayerInTableForAll(msg.sender, foundTableId); 
            emit PlayerInTable(msg.sender, foundTableId);
        }
    }

    function sitToTable(uint32 tableId, address playerAddress) internal tableExists(tableId) playerExists(playerAddress) {
        GameTable storage table = tables[tableId];
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
    
    
    function startGameAtTable(uint32 tableId) internal {
        emit GameIsStartedAtTable(tableId);
        
        // set the game grid
        calculateNumberOfColorsForPlayersAtTable(tableId);
        
        // randomly pick the number for the winner index
        uint32 random = uint32(uint(keccak256(abi.encodePacked(now, tables[tableId].players[0], tables[tableId].totalColorNumber))) % tables[tableId].totalColorNumber);
        tables[tableId].winnerNumber = random;
        
        emit GameIsEndedAtTable(tableId);
        renewTable(tableId);
    }
    
    
    function calculateNumberOfColorsForPlayersAtTable(uint32 tableId) internal {
        GameTable storage table = tables[tableId];
        
        uint32 totalBetMultiplier = 0;
        for (uint32 i = 0; i < table.playerCount; i++) {
            totalBetMultiplier += addressToPlayer[table.players[i]].betMultiplier;
        }
        
        uint32 colorMultiplier = maxColorsAtTable / totalBetMultiplier;
        uint32 totalColors = colorMultiplier * totalBetMultiplier;
        table.totalColorNumber = totalColors;
        
        uint32[] memory playerRemainingColors = new uint32[](maxNumOfPeopleAtTable);
        
        for (uint32 j = 0; j < table.playerCount; j++) {
            addressToPlayer[table.players[j]].numberOfColors *= colorMultiplier;
            addressToPlayer[table.players[i]].colorId = j + 1;
            playerRemainingColors[j] = addressToPlayer[table.players[j]].numberOfColors;
        }
        
        uint32[] memory playersForRandomArray = new uint32[](maxNumOfPeopleAtTable);
        
        // Set colors randomly in grid
        for (uint32 k = 0; k < totalColors; k++) {
            uint32 p = 0;
            for (uint32 n = 0; n < table.playerCount; n++) {
                if (playerRemainingColors[n] > 0) {
                    playersForRandomArray[p] = n; 
                    p++;
                }                
            }
            
            if (playersForRandomArray.length <= 1) {
                for (uint32 m = k; m < totalColors; m++) {
                    table.colorGrid[k] = addressToPlayer[table.players[playersForRandomArray[0]]].colorId;
                    playersForRandomArray[playersForRandomArray[0]] --;
                }
                
                break;
            } 
            else {
                uint32 random = uint32(uint(keccak256(abi.encodePacked(now, table.players[playersForRandomArray[0]], k))) % playersForRandomArray.length);
                table.colorGrid[k] = addressToPlayer[table.players[playersForRandomArray[random]]].colorId;
                playersForRandomArray[playersForRandomArray[random]] --;
            }
        }
    }
    
    
    function getTableInfo(uint32 tableId) external view tableExists(tableId) returns(uint32, uint32, address[]) {
        GameTable memory table;
        for (uint32 i = 0; i < tables.length; i++) {
            if (tables[i].tableId == tableId) {
                table = tables[i];
            }
        }
        
        address[] memory playerAddresses = new address[](table.playerCount);
        for (uint32 j = 0; j < table.playerCount; j++) {
            playerAddresses[j] = table.players[j];
        }
        
        return (table.playerCount, table.firstPlayerArrivedTime, playerAddresses);
    }
    
    function getPlayerInfo(address playerAddress) external view playerExists(playerAddress) returns(string, uint32) {
        return (addressToPlayer[playerAddress].name, addressToPlayer[playerAddress].betMultiplier);
    }
    
    
    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
}