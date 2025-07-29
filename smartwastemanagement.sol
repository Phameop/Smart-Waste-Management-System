// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Smart Waste Management System
 * @dev A blockchain-based waste management system that incentivizes proper waste disposal,
 * automates collection processes, and promotes environmental sustainability
 */
contract Project {
    
    // State variables
    address public systemAdmin;
    uint256 public totalWasteCollected; // in grams
    uint256 public totalRewardsDistributed; // in tokens
    uint256 public totalCarbonCreditsIssued;
    
    // Enums
    enum WasteType { PLASTIC, ORGANIC, PAPER, GLASS, ELECTRONIC, HAZARDOUS }
    enum BinStatus { EMPTY, QUARTER_FULL, HALF_FULL, THREE_QUARTER_FULL, FULL }
    enum CollectionStatus { PENDING, IN_PROGRESS, COMPLETED, VERIFIED }
    
    // Structs
    struct Citizen {
        address citizenAddress;
        uint256 totalDeposits;
        uint256 totalRewards;
        uint256 carbonCreditsEarned;
        mapping(WasteType => uint256) wasteContributions; // in grams
        bool isRegistered;
        uint256 registrationDate;
    }
    
    struct SmartBin {
        uint256 binId;
        string location;
        WasteType wasteType;
        BinStatus status;
        uint256 capacity; // in grams
        uint256 currentWeight; // in grams
        address assignedCollector;
        uint256 lastEmptied;
        bool isActive;
        uint256 installationDate;
    }
    
    struct WasteCollector {
        address collectorAddress;
        string companyName;
        uint256 totalCollections;
        uint256 reputationScore; // 0-100
        bool isVerified;
        bool isActive;
        uint256 registrationDate;
    }
    
    struct WasteDeposit {
        uint256 depositId;
        address citizen;
        uint256 binId;
        uint256 weight; // in grams
        WasteType wasteType;
        uint256 rewardAmount;
        uint256 carbonCredits;
        uint256 timestamp;
        bytes32 verificationHash; // IoT sensor verification
    }
    
    struct CollectionTask {
        uint256 taskId;
        uint256 binId;
        address assignedCollector;
        CollectionStatus status;
        uint256 scheduledTime;
        uint256 completionTime;
        uint256 collectedWeight;
        bytes32 proofHash; // Proof of collection
    }
    
    // Mappings
    mapping(address => Citizen) public citizens;
    mapping(uint256 => SmartBin) public smartBins;
    mapping(address => WasteCollector) public collectors;
    mapping(uint256 => WasteDeposit) public deposits;
    mapping(uint256 => CollectionTask) public collectionTasks;
    mapping(WasteType => uint256) public rewardRates; // tokens per gram
    mapping(WasteType => uint256) public carbonRates; // carbon credits per gram
    
    // Counters
    uint256 public nextBinId = 1;
    uint256 public nextDepositId = 1;
    uint256 public nextTaskId = 1;
    
    // Events
    event CitizenRegistered(address indexed citizen, uint256 timestamp);
    event WasteDeposited(address indexed citizen, uint256 indexed binId, uint256 weight, uint256 rewards);
    event BinStatusUpdated(uint256 indexed binId, BinStatus newStatus);
    event CollectionScheduled(uint256 indexed taskId, uint256 indexed binId, address indexed collector);
    event CollectionCompleted(uint256 indexed taskId, address indexed collector, uint256 weight);
    event RewardsDistributed(address indexed citizen, uint256 amount);
    event CarbonCreditsIssued(address indexed citizen, uint256 amount);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == systemAdmin, "Only system admin can call this function");
        _;
    }
    
    modifier onlyRegisteredCitizen() {
        require(citizens[msg.sender].isRegistered, "Citizen not registered");
        _;
    }
    
    modifier onlyVerifiedCollector() {
        require(collectors[msg.sender].isVerified && collectors[msg.sender].isActive, 
                "Only verified collectors can call this function");
        _;
    }
    
    modifier validBin(uint256 binId) {
        require(smartBins[binId].isActive, "Smart bin is not active");
        _;
    }
    
    constructor() {
        systemAdmin = msg.sender;
        
        // Initialize reward rates (tokens per gram)
        rewardRates[WasteType.PLASTIC] = 10; // 10 tokens per gram
        rewardRates[WasteType.ORGANIC] = 5;  // 5 tokens per gram
        rewardRates[WasteType.PAPER] = 8;    // 8 tokens per gram
        rewardRates[WasteType.GLASS] = 12;   // 12 tokens per gram
        rewardRates[WasteType.ELECTRONIC] = 50; // 50 tokens per gram
        rewardRates[WasteType.HAZARDOUS] = 100; // 100 tokens per gram
        
        // Initialize carbon credit rates (credits per gram)
        carbonRates[WasteType.PLASTIC] = 3;     // 3 credits per gram
        carbonRates[WasteType.ORGANIC] = 2;     // 2 credits per gram
        carbonRates[WasteType.PAPER] = 4;       // 4 credits per gram
        carbonRates[WasteType.GLASS] = 2;       // 2 credits per gram
        carbonRates[WasteType.ELECTRONIC] = 10; // 10 credits per gram
        carbonRates[WasteType.HAZARDOUS] = 15;  // 15 credits per gram
    }
    
    /**
     * @dev Core Function 1: Deposit waste into a smart bin and earn rewards
     * @param binId The ID of the smart bin
     * @param weightInGrams Weight of waste being deposited
     * @param verificationHash Hash from IoT sensors for verification
     * Citizens earn tokens and carbon credits based on waste type and weight
     */
    function depositWaste(
        uint256 binId,
        uint256 weightInGrams,
        bytes32 verificationHash
    ) external onlyRegisteredCitizen validBin(binId) {
        require(weightInGrams > 0, "Weight must be greater than 0");
        require(verificationHash != bytes32(0), "Verification hash required");
        
        SmartBin storage bin = smartBins[binId];
        require(bin.status != BinStatus.FULL, "Bin is full");
        require(bin.currentWeight + weightInGrams <= bin.capacity, "Exceeds bin capacity");
        
        Citizen storage citizen = citizens[msg.sender];
        
        // Calculate rewards and carbon credits
        uint256 rewardAmount = weightInGrams * rewardRates[bin.wasteType];
        uint256 carbonCredits = weightInGrams * carbonRates[bin.wasteType];
        
        // Apply bonus multipliers for consistent users
        if (citizen.totalDeposits >= 50) {
            rewardAmount = (rewardAmount * 120) / 100; // 20% bonus
            carbonCredits = (carbonCredits * 115) / 100; // 15% bonus
        } else if (citizen.totalDeposits >= 20) {
            rewardAmount = (rewardAmount * 110) / 100; // 10% bonus
            carbonCredits = (carbonCredits * 105) / 100; // 5% bonus
        }
        
        // Update bin status
        bin.currentWeight += weightInGrams;
        _updateBinStatus(binId);
        
        // Update citizen statistics
        citizen.totalDeposits++;
        citizen.totalRewards += rewardAmount;
        citizen.carbonCreditsEarned += carbonCredits;
        citizen.wasteContributions[bin.wasteType] += weightInGrams;
        
        // Record the deposit
        deposits[nextDepositId] = WasteDeposit({
            depositId: nextDepositId,
            citizen: msg.sender,
            binId: binId,
            weight: weightInGrams,
            wasteType: bin.wasteType,
            rewardAmount: rewardAmount,
            carbonCredits: carbonCredits,
            timestamp: block.timestamp,
            verificationHash: verificationHash
        });
        
        // Update global statistics
        totalWasteCollected += weightInGrams;
        totalRewardsDistributed += rewardAmount;
        totalCarbonCreditsIssued += carbonCredits;
        
        nextDepositId++;
        
        // Schedule collection if bin is full or three-quarter full
        if (bin.status >= BinStatus.THREE_QUARTER_FULL && bin.assignedCollector != address(0)) {
            _scheduleCollection(binId);
        }
        
        emit WasteDeposited(msg.sender, binId, weightInGrams, rewardAmount);
        emit RewardsDistributed(msg.sender, rewardAmount);
        emit CarbonCreditsIssued(msg.sender, carbonCredits);
    }
    
    /**
     * @dev Core Function 2: Schedule and manage waste collection tasks
     * @param binId The ID of the bin to collect from
     * @param scheduledTime When the collection should happen
     * Only verified collectors can be assigned collection tasks
     */
    function scheduleCollection(
        uint256 binId,
        uint256 scheduledTime
    ) external onlyAdmin validBin(binId) {
        SmartBin storage bin = smartBins[binId];
        require(bin.assignedCollector != address(0), "No collector assigned to bin");
        require(bin.status >= BinStatus.THREE_QUARTER_FULL, "Bin doesn't need collection yet");
        require(scheduledTime > block.timestamp, "Scheduled time must be in future");
        
        uint256 taskId = nextTaskId;
        
        collectionTasks[taskId] = CollectionTask({
            taskId: taskId,
            binId: binId,
            assignedCollector: bin.assignedCollector,
            status: CollectionStatus.PENDING,
            scheduledTime: scheduledTime,
            completionTime: 0,
            collectedWeight: 0,
            proofHash: bytes32(0)
        });
        
        nextTaskId++;
        
        emit CollectionScheduled(taskId, binId, bin.assignedCollector);
    }
    
    /**
     * @dev Core Function 3: Complete waste collection and verify
     * @param taskId The ID of the collection task
     * @param actualWeight Weight of waste collected
     * @param proofHash Cryptographic proof of collection completion
     * Collectors complete their assigned collection tasks and get verified
     */
    function completeCollection(
        uint256 taskId,
        uint256 actualWeight,
        bytes32 proofHash
    ) external onlyVerifiedCollector {
        CollectionTask storage task = collectionTasks[taskId];
        require(task.assignedCollector == msg.sender, "Not assigned to you");
        require(task.status == CollectionStatus.PENDING, "Task not in pending status");
        require(actualWeight > 0, "Collected weight must be greater than 0");
        require(proofHash != bytes32(0), "Proof hash required");
        
        SmartBin storage bin = smartBins[task.binId];
        WasteCollector storage collector = collectors[msg.sender];
        
        // Verify the collected weight is reasonable
        require(actualWeight <= bin.currentWeight + (bin.currentWeight / 10), 
                "Collected weight seems incorrect");
        
        // Update task status
        task.status = CollectionStatus.COMPLETED;
        task.completionTime = block.timestamp;
        task.collectedWeight = actualWeight;
        task.proofHash = proofHash;
        
        // Reset bin after collection
        bin.currentWeight = 0;
        bin.status = BinStatus.EMPTY;
        bin.lastEmptied = block.timestamp;
        
        // Update collector statistics
        collector.totalCollections++;
        
        // Improve reputation based on timeliness
        if (block.timestamp <= task.scheduledTime + 1 hours) {
            // On time or early collection
            if (collector.reputationScore < 100) {
                collector.reputationScore += 2;
                if (collector.reputationScore > 100) {
                    collector.reputationScore = 100;
                }
            }
        } else {
            // Late collection - reduce reputation
            if (collector.reputationScore > 0) {
                collector.reputationScore -= 1;
            }
        }
        
        emit CollectionCompleted(taskId, msg.sender, actualWeight);
        emit BinStatusUpdated(task.binId, BinStatus.EMPTY);
    }
    
    // Additional utility functions
    
    /**
     * @dev Register a new citizen in the system
     */
    function registerCitizen() external {
        require(!citizens[msg.sender].isRegistered, "Citizen already registered");
        
        citizens[msg.sender].citizenAddress = msg.sender;
        citizens[msg.sender].isRegistered = true;
        citizens[msg.sender].registrationDate = block.timestamp;
        
        emit CitizenRegistered(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Register a new smart bin
     */
    function registerSmartBin(
        string memory location,
        WasteType wasteType,
        uint256 capacity,
        address assignedCollector
    ) external onlyAdmin returns (uint256) {
        require(collectors[assignedCollector].isVerified, "Collector not verified");
        
        uint256 binId = nextBinId;
        
        smartBins[binId] = SmartBin({
            binId: binId,
            location: location,
            wasteType: wasteType,
            status: BinStatus.EMPTY,
            capacity: capacity,
            currentWeight: 0,
            assignedCollector: assignedCollector,
            lastEmptied: block.timestamp,
            isActive: true,
            installationDate: block.timestamp
        });
        
        nextBinId++;
        return binId;
    }
    
    /**
     * @dev Register and verify a waste collector
     */
    function registerCollector(
        address collectorAddress,
        string memory companyName
    ) external onlyAdmin {
        require(!collectors[collectorAddress].isVerified, "Collector already registered");
        
        collectors[collectorAddress] = WasteCollector({
            collectorAddress: collectorAddress,
            companyName: companyName,
            totalCollections: 0,
            reputationScore: 50, // Start with neutral reputation
            isVerified: true,
            isActive: true,
            registrationDate: block.timestamp
        });
    }
    
    /**
     * @dev Internal function to update bin status based on weight
     */
    function _updateBinStatus(uint256 binId) internal {
        SmartBin storage bin = smartBins[binId];
        uint256 fillPercentage = (bin.currentWeight * 100) / bin.capacity;
        
        BinStatus oldStatus = bin.status;
        
        if (fillPercentage >= 100) {
            bin.status = BinStatus.FULL;
        } else if (fillPercentage >= 75) {
            bin.status = BinStatus.THREE_QUARTER_FULL;
        } else if (fillPercentage >= 50) {
            bin.status = BinStatus.HALF_FULL;
        } else if (fillPercentage >= 25) {
            bin.status = BinStatus.QUARTER_FULL;
        } else {
            bin.status = BinStatus.EMPTY;
        }
        
        if (oldStatus != bin.status) {
            emit BinStatusUpdated(binId, bin.status);
        }
    }
    
    /**
     * @dev Internal function to automatically schedule collection
     */
    function _scheduleCollection(uint256 binId) internal {
        uint256 taskId = nextTaskId;
        SmartBin storage bin = smartBins[binId];
        
        collectionTasks[taskId] = CollectionTask({
            taskId: taskId,
            binId: binId,
            assignedCollector: bin.assignedCollector,
            status: CollectionStatus.PENDING,
            scheduledTime: block.timestamp + 4 hours, // Schedule 4 hours from now
            completionTime: 0,
            collectedWeight: 0,
            proofHash: bytes32(0)
        });
        
        nextTaskId++;
        
        emit CollectionScheduled(taskId, binId, bin.assignedCollector);
    }
    
    /**
     * @dev Get citizen statistics
     */
    function getCitizenStats(address citizenAddress) external view returns (
        uint256 totalDeposits,
        uint256 totalRewards,
        uint256 carbonCreditsEarned,
        bool isRegistered
    ) {
        Citizen storage citizen = citizens[citizenAddress];
        return (
            citizen.totalDeposits,
            citizen.totalRewards,
            citizen.carbonCreditsEarned,
            citizen.isRegistered
        );
    }
    
    /**
     * @dev Get smart bin information
     */
    function getSmartBinInfo(uint256 binId) external view returns (
        string memory location,
        WasteType wasteType,
        BinStatus status,
        uint256 capacity,
        uint256 currentWeight,
        address assignedCollector
    ) {
        SmartBin storage bin = smartBins[binId];
        return (
            bin.location,
            bin.wasteType,
            bin.status,
            bin.capacity,
            bin.currentWeight,
            bin.assignedCollector
        );
    }
    
    /**
     * @dev Get collector information
     */
    function getCollectorInfo(address collectorAddress) external view returns (
        string memory companyName,
        uint256 totalCollections,
        uint256 reputationScore,
        bool isVerified,
        bool isActive
    ) {
        WasteCollector storage collector = collectors[collectorAddress];
        return (
            collector.companyName,
            collector.totalCollections,
            collector.reputationScore,
            collector.isVerified,
            collector.isActive
        );
    }
    
    /**
     * @dev Get system-wide statistics
     */
    function getSystemStats() external view returns (
        uint256 _totalWasteCollected,
        uint256 _totalRewardsDistributed,
        uint256 _totalCarbonCreditsIssued,
        uint256 _totalBins,
        uint256 _totalDeposits
    ) {
        return (
            totalWasteCollected,
            totalRewardsDistributed,
            totalCarbonCreditsIssued,
            nextBinId - 1,
            nextDepositId - 1
        );
    }
    
    /**
     * @dev Update reward rates for different waste types
     */
    function updateRewardRate(WasteType wasteType, uint256 newRate) external onlyAdmin {
        rewardRates[wasteType] = newRate;
    }
    
    /**
     * @dev Update carbon credit rates for different waste types
     */
    function updateCarbonRate(WasteType wasteType, uint256 newRate) external onlyAdmin {
        carbonRates[wasteType] = newRate;
    }
    
    /**
     * @dev Emergency function to deactivate a bin
     */
    function deactivateBin(uint256 binId) external onlyAdmin {
        smartBins[binId].isActive = false;
    }
    
    /**
     * @dev Emergency function to deactivate a collector
     */
    function deactivateCollector(address collectorAddress) external onlyAdmin {
        collectors[collectorAddress].isActive = false;
    }
    
    /**
     * @dev Get waste contribution by citizen for specific waste type
     */
    function getCitizenWasteContribution(
        address citizenAddress, 
        WasteType wasteType
    ) external view returns (uint256) {
        return citizens[citizenAddress].wasteContributions[wasteType];
    }
}
