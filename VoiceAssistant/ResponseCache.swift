import Foundation
import CryptoKit
import os.log

/// LRU cache for storing frequently used responses with encryption for sensitive data
@MainActor
class ResponseCache: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cacheStatistics = CacheStatistics()
    @Published var isClearing = false
    
    // MARK: - Private Properties
    private var cache: [String: CacheNode]
    private var head: CacheNode?
    private var tail: CacheNode?
    private let maxSize: Int
    private let encryptionKey: SymmetricKey
    private let logger = Logger(subsystem: "com.voiceassistant.cache", category: "ResponseCache")
    
    // MARK: - Configuration
    private let encryptSensitiveResponses = true
    private let maxResponseSize = 10000 // Characters
    private let cacheTTL: TimeInterval = 3600 // 1 hour default TTL
    
    // MARK: - Cache Performance Metrics
    private var accessTimes: [TimeInterval] = []
    private let maxAccessTimeHistory = 100
    
    // MARK: - Initialization
    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
        self.cache = [:]
        self.encryptionKey = ResponseCache.getOrCreateEncryptionKey()
        
        // Set up cache maintenance timer
        setupMaintenanceTimer()
        
        logger.info("ResponseCache initialized with max size: \(maxSize)")
    }
    
    // MARK: - Main Cache Operations
    
    /// Retrieves a cached response for the given key
    /// - Parameter key: The cache key
    /// - Returns: The cached response if found, nil otherwise
    func getResponse(for key: String) async -> String? {
        let startTime = Date()
        defer {
            let accessTime = Date().timeIntervalSince(startTime)
            recordAccessTime(accessTime)
        }
        
        guard let node = cache[key] else {
            cacheStatistics.misses += 1
            logger.debug("Cache miss for key: \(key, privacy: .public)")
            return nil
        }
        
        // Check if expired
        if isExpired(node) {
            await removeExpiredEntry(key: key, node: node)
            cacheStatistics.misses += 1
            cacheStatistics.expiredEntries += 1
            logger.debug("Cache entry expired for key: \(key, privacy: .public)")
            return nil
        }
        
        // Move to front (most recently used)
        moveToFront(node)
        
        // Update access statistics
        node.accessCount += 1
        node.lastAccessed = Date()
        
        cacheStatistics.hits += 1
        
        // Decrypt response if it's encrypted
        let response = await decryptIfNeeded(node.response, isEncrypted: node.isEncrypted)
        
        logger.debug("Cache hit for key: \(key, privacy: .public)")
        return response
    }
    
    /// Caches a response with the given key
    /// - Parameters:
    ///   - response: The response to cache
    ///   - key: The cache key
    ///   - ttl: Time to live for this entry (optional, uses default if not provided)
    func cacheResponse(
        _ response: String,
        for key: String,
        ttl: TimeInterval? = nil
    ) async {
        
        // Validate response size
        guard response.count <= maxResponseSize else {
            logger.warning("Response too large to cache: \(response.count) characters")
            return
        }
        
        let shouldEncrypt = shouldEncryptResponse(response)
        let processedResponse = await encryptIfNeeded(response, shouldEncrypt: shouldEncrypt)
        
        let expiresAt = Date().addingTimeInterval(ttl ?? cacheTTL)
        
        if let existingNode = cache[key] {
            // Update existing entry
            existingNode.response = processedResponse
            existingNode.isEncrypted = shouldEncrypt
            existingNode.expiresAt = expiresAt
            existingNode.lastAccessed = Date()
            existingNode.accessCount += 1
            
            moveToFront(existingNode)
            logger.debug("Updated cache entry for key: \(key, privacy: .public)")
        } else {
            // Create new entry
            let newNode = CacheNode(
                key: key,
                response: processedResponse,
                isEncrypted: shouldEncrypt,
                expiresAt: expiresAt
            )
            
            cache[key] = newNode
            addToFront(newNode)
            
            cacheStatistics.totalEntries += 1
            logger.debug("Added new cache entry for key: \(key, privacy: .public)")
            
            // Check if we need to evict
            if cache.count > maxSize {
                await evictLeastRecentlyUsed()
            }
        }
        
        cacheStatistics.writes += 1
    }
    
    /// Removes a specific entry from the cache
    /// - Parameter key: The key to remove
    func removeEntry(for key: String) async {
        guard let node = cache[key] else { return }
        
        await removeNode(node)
        cache.removeValue(forKey: key)
        
        cacheStatistics.totalEntries -= 1
        logger.debug("Removed cache entry for key: \(key, privacy: .public)")
    }
    
    /// Clears all cached responses
    func clearCache() async {
        isClearing = true
        defer { isClearing = false }
        
        logger.info("Clearing entire response cache")
        
        cache.removeAll()
        head = nil
        tail = nil
        
        // Reset statistics but preserve historical data
        let previousHits = cacheStatistics.hits
        let previousMisses = cacheStatistics.misses
        
        cacheStatistics = CacheStatistics()
        cacheStatistics.totalClears += 1
        cacheStatistics.lifetimeHits = previousHits
        cacheStatistics.lifetimeMisses = previousMisses
        
        logger.info("Cache cleared successfully")
    }
    
    /// Clears only expired entries
    func clearExpiredEntries() async {
        logger.debug("Clearing expired cache entries")
        
        let currentTime = Date()
        var expiredKeys: [String] = []
        
        for (key, node) in cache {
            if currentTime > node.expiresAt {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            if let node = cache[key] {
                await removeExpiredEntry(key: key, node: node)
            }
        }
        
        logger.info("Cleared \(expiredKeys.count) expired entries")
    }
    
    // MARK: - Cache Analytics
    
    /// Returns detailed cache performance metrics
    func getCachePerformanceMetrics() -> CachePerformanceMetrics {
        let hitRate = cacheStatistics.totalRequests > 0 ?
            Double(cacheStatistics.hits) / Double(cacheStatistics.totalRequests) : 0.0
        
        let averageAccessTime = accessTimes.isEmpty ? 0.0 :
            accessTimes.reduce(0, +) / Double(accessTimes.count)
        
        let memoryUsage = estimateMemoryUsage()
        
        return CachePerformanceMetrics(
            hitRate: hitRate,
            totalEntries: cacheStatistics.totalEntries,
            averageAccessTime: averageAccessTime,
            memoryUsageBytes: memoryUsage,
            encryptedEntries: countEncryptedEntries(),
            expiredEntriesCleared: cacheStatistics.expiredEntries
        )
    }
    
    // MARK: - Private Methods
    
    private func setupMaintenanceTimer() {
        // Clean up expired entries every 10 minutes
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performMaintenance()
            }
        }
    }
    
    private func performMaintenance() async {
        await clearExpiredEntries()
        optimizeCacheLayout()
    }
    
    private func optimizeCacheLayout() {
        // Reorder cache based on access patterns
        let sortedNodes = cache.values.sorted { first, second in
            // Primary: Access frequency
            if first.accessCount != second.accessCount {
                return first.accessCount > second.accessCount
            }
            // Secondary: Recency
            return first.lastAccessed > second.lastAccessed
        }
        
        // Rebuild linked list with optimized order
        head = nil
        tail = nil
        
        for node in sortedNodes {
            node.prev = nil
            node.next = nil
            addToFront(node)
        }
    }
    
    private func shouldEncryptResponse(_ response: String) -> Bool {
        guard encryptSensitiveResponses else { return false }
        
        // Encrypt responses containing potentially sensitive information
        let sensitiveKeywords = [
            "password", "token", "key", "secret", "credential",
            "email", "phone", "address", "ssn", "credit card",
            "personal", "private", "confidential"
        ]
        
        let lowercaseResponse = response.lowercased()
        return sensitiveKeywords.contains { lowercaseResponse.contains($0) }
    }
    
    private func encryptIfNeeded(_ response: String, shouldEncrypt: Bool) async -> String {
        guard shouldEncrypt else { return response }
        
        do {
            let data = response.data(using: .utf8) ?? Data()
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            let encryptedData = sealedBox.combined ?? Data()
            return encryptedData.base64EncodedString()
        } catch {
            logger.error("Failed to encrypt response: \(error)")
            return response // Fallback to unencrypted
        }
    }
    
    private func decryptIfNeeded(_ response: String, isEncrypted: Bool) async -> String {
        guard isEncrypted else { return response }
        
        do {
            guard let encryptedData = Data(base64Encoded: response) else {
                logger.error("Invalid base64 encrypted data")
                return response
            }
            
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8) ?? response
        } catch {
            logger.error("Failed to decrypt response: \(error)")
            return response // Fallback to encrypted string
        }
    }
    
    private func isExpired(_ node: CacheNode) -> Bool {
        return Date() > node.expiresAt
    }
    
    private func removeExpiredEntry(key: String, node: CacheNode) async {
        await removeNode(node)
        cache.removeValue(forKey: key)
        cacheStatistics.totalEntries -= 1
    }
    
    private func evictLeastRecentlyUsed() async {
        guard let lruNode = tail else { return }
        
        await removeNode(lruNode)
        cache.removeValue(forKey: lruNode.key)
        
        cacheStatistics.evictions += 1
        cacheStatistics.totalEntries -= 1
        
        logger.debug("Evicted LRU entry: \(lruNode.key, privacy: .public)")
    }
    
    private func addToFront(_ node: CacheNode) {
        if head == nil {
            head = node
            tail = node
        } else {
            node.next = head
            head?.prev = node
            head = node
        }
    }
    
    private func removeNode(_ node: CacheNode) async {
        if node.prev != nil {
            node.prev?.next = node.next
        } else {
            head = node.next
        }
        
        if node.next != nil {
            node.next?.prev = node.prev
        } else {
            tail = node.prev
        }
    }
    
    private func moveToFront(_ node: CacheNode) {
        // Remove from current position
        if node.prev != nil {
            node.prev?.next = node.next
        } else {
            head = node.next
        }
        
        if node.next != nil {
            node.next?.prev = node.prev
        } else {
            tail = node.prev
        }
        
        // Add to front
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func recordAccessTime(_ time: TimeInterval) {
        accessTimes.append(time)
        
        if accessTimes.count > maxAccessTimeHistory {
            accessTimes.removeFirst()
        }
    }
    
    private func estimateMemoryUsage() -> Int {
        var totalSize = 0
        
        for (key, node) in cache {
            totalSize += key.utf8.count
            totalSize += node.response.utf8.count
            totalSize += MemoryLayout<CacheNode>.size
        }
        
        return totalSize
    }
    
    private func countEncryptedEntries() -> Int {
        return cache.values.filter { $0.isEncrypted }.count
    }
    
    // MARK: - Static Methods
    
    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keyData = UserDefaults.standard.data(forKey: "response_cache_encryption_key")
        
        if let existingKey = keyData {
            return SymmetricKey(data: existingKey)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            UserDefaults.standard.set(
                newKey.withUnsafeBytes { Data($0) },
                forKey: "response_cache_encryption_key"
            )
            return newKey
        }
    }
}

// MARK: - Supporting Types

/// Node in the doubly-linked list for LRU cache
class CacheNode {
    let key: String
    var response: String
    var isEncrypted: Bool
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    var expiresAt: Date
    
    var prev: CacheNode?
    var next: CacheNode?
    
    init(
        key: String,
        response: String,
        isEncrypted: Bool = false,
        expiresAt: Date
    ) {
        self.key = key
        self.response = response
        self.isEncrypted = isEncrypted
        self.createdAt = Date()
        self.lastAccessed = Date()
        self.accessCount = 1
        self.expiresAt = expiresAt
    }
}

/// Statistics about cache performance
struct CacheStatistics {
    var hits: Int = 0
    var misses: Int = 0
    var writes: Int = 0
    var evictions: Int = 0
    var totalEntries: Int = 0
    var expiredEntries: Int = 0
    var totalClears: Int = 0
    
    // Lifetime statistics
    var lifetimeHits: Int = 0
    var lifetimeMisses: Int = 0
    
    var totalRequests: Int {
        return hits + misses
    }
    
    var hitRate: Double {
        return totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0.0
    }
}

/// Detailed performance metrics for cache analysis
struct CachePerformanceMetrics {
    let hitRate: Double
    let totalEntries: Int
    let averageAccessTime: TimeInterval
    let memoryUsageBytes: Int
    let encryptedEntries: Int
    let expiredEntriesCleared: Int
    
    var memoryUsageKB: Double {
        return Double(memoryUsageBytes) / 1024.0
    }
    
    var memoryUsageMB: Double {
        return memoryUsageKB / 1024.0
    }
    
    var encryptionRate: Double {
        return totalEntries > 0 ? Double(encryptedEntries) / Double(totalEntries) : 0.0
    }
}

// MARK: - Cache Extensions

extension ResponseCache {
    
    /// Preloads common responses into cache
    func preloadCommonResponses() async {
        let commonResponses = [
            ("greeting_morning", "Good morning! How can I help you today?"),
            ("greeting_afternoon", "Good afternoon! What can I do for you?"),
            ("greeting_evening", "Good evening! How may I assist you?"),
            ("confirmation_ok", "Okay, I'll take care of that for you."),
            ("confirmation_done", "All done! Is there anything else you need?"),
            ("error_general", "I'm sorry, I couldn't complete that request. Please try again."),
            ("clarification", "Could you please provide more details about what you need?")
        ]
        
        for (key, response) in commonResponses {
            await cacheResponse(response, for: key, ttl: 7200) // Cache for 2 hours
        }
        
        logger.info("Preloaded \(commonResponses.count) common responses")
    }
    
    /// Exports cache statistics for analytics
    func exportStatistics() -> [String: Any] {
        let metrics = getCachePerformanceMetrics()
        
        return [
            "hit_rate": metrics.hitRate,
            "total_entries": metrics.totalEntries,
            "memory_usage_mb": metrics.memoryUsageMB,
            "encrypted_entries": metrics.encryptedEntries,
            "encryption_rate": metrics.encryptionRate,
            "average_access_time_ms": metrics.averageAccessTime * 1000,
            "total_hits": cacheStatistics.hits,
            "total_misses": cacheStatistics.misses,
            "total_evictions": cacheStatistics.evictions,
            "expired_entries_cleared": cacheStatistics.expiredEntries
        ]
    }
}