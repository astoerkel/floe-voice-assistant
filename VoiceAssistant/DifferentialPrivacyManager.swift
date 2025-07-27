import Foundation
import CryptoKit

/// Differential privacy implementation for aggregated usage statistics
/// Adds calibrated noise to protect individual user privacy while preserving statistical utility
public class DifferentialPrivacyManager {
    
    // MARK: - Types
    
    public struct PrivacyParameters {
        let epsilon: Double // Privacy loss parameter (smaller = more private)
        let delta: Double   // Probability of privacy loss (typically very small)
        let sensitivity: Double // Maximum change one individual can make
        
        public init(epsilon: Double = 1.0, delta: Double = 1e-5, sensitivity: Double = 1.0) {
            self.epsilon = epsilon
            self.delta = delta
            self.sensitivity = sensitivity
        }
    }
    
    public enum NoiseType {
        case laplace    // For count queries and histograms
        case gaussian   // For sum queries and continuous data
        case exponential // For selecting from discrete sets
    }
    
    public enum AggregationType {
        case count
        case sum
        case average
        case histogram
        case topK
    }
    
    // MARK: - Properties
    
    private let parameters: PrivacyParameters
    private var randomNumberGenerator: SystemRandomNumberGenerator
    private var privacyBudgetUsed: Double = 0.0
    private let maxPrivacyBudget: Double
    
    // MARK: - Initialization
    
    public init(epsilon: Double = 1.0, delta: Double = 1e-5, maxBudget: Double = 10.0) {
        self.parameters = PrivacyParameters(epsilon: epsilon, delta: delta)
        self.randomNumberGenerator = SystemRandomNumberGenerator()
        self.maxPrivacyBudget = maxBudget
    }
    
    // MARK: - Public Interface
    
    /// Add differential privacy noise to a count query
    public func addNoiseToCount(_ count: Int, sensitivity: Double = 1.0) throws -> Int {
        try checkPrivacyBudget()
        
        let noisyCount = try addLaplaceNoise(
            to: Double(count),
            sensitivity: sensitivity,
            epsilon: parameters.epsilon
        )
        
        privacyBudgetUsed += parameters.epsilon
        return max(0, Int(round(noisyCount)))
    }
    
    /// Add differential privacy noise to a sum query
    public func addNoiseToSum(_ sum: Double, sensitivity: Double = 1.0) throws -> Double {
        try checkPrivacyBudget()
        
        let noisySum = try addLaplaceNoise(
            to: sum,
            sensitivity: sensitivity,
            epsilon: parameters.epsilon
        )
        
        privacyBudgetUsed += parameters.epsilon
        return noisySum
    }
    
    /// Add differential privacy noise to an average
    public func addNoiseToAverage(_ average: Double, count: Int, sensitivity: Double = 1.0) throws -> Double {
        try checkPrivacyBudget()
        
        // For averages, we need to be careful about sensitivity
        let avgSensitivity = sensitivity / Double(count)
        
        let noisyAverage = try addLaplaceNoise(
            to: average,
            sensitivity: avgSensitivity,
            epsilon: parameters.epsilon
        )
        
        privacyBudgetUsed += parameters.epsilon
        return noisyAverage
    }
    
    /// Create a differentially private histogram
    public func createPrivateHistogram<T: Hashable>(
        from data: [T],
        binCount: Int? = nil
    ) throws -> [T: Int] {
        try checkPrivacyBudget()
        
        let histogram = Dictionary(data.map { ($0, 1) }, uniquingKeysWith: +)
        var privateHistogram: [T: Int] = [:]
        
        for (key, count) in histogram {
            let noisyCount = try addLaplaceNoise(
                to: Double(count),
                sensitivity: 1.0,
                epsilon: parameters.epsilon / Double(histogram.count)
            )
            
            privateHistogram[key] = max(0, Int(round(noisyCount)))
        }
        
        privacyBudgetUsed += parameters.epsilon
        return privateHistogram
    }
    
    /// Select top-K items with differential privacy
    public func selectTopK<T: Hashable>(
        from counts: [T: Int],
        k: Int
    ) throws -> [(T, Int)] {
        try checkPrivacyBudget()
        
        var noisyCounts: [T: Double] = [:]
        
        // Add noise to each count
        for (item, count) in counts {
            let noisyCount = try addLaplaceNoise(
                to: Double(count),
                sensitivity: 1.0,
                epsilon: parameters.epsilon / 2.0
            )
            noisyCounts[item] = noisyCount
        }
        
        // Select top-K using exponential mechanism
        let topK = noisyCounts
            .sorted { $0.value > $1.value }
            .prefix(k)
            .map { (key: $0.key, count: max(0, Int(round($0.value)))) }
        
        privacyBudgetUsed += parameters.epsilon
        return Array(topK)
    }
    
    /// Add noise to time-series data points
    public func addNoiseToTimeSeries(
        _ values: [Double],
        sensitivity: Double = 1.0
    ) throws -> [Double] {
        try checkPrivacyBudget()
        
        let epsilonPerPoint = parameters.epsilon / Double(values.count)
        var noisyValues: [Double] = []
        
        for value in values {
            let noisyValue = try addLaplaceNoise(
                to: value,
                sensitivity: sensitivity,
                epsilon: epsilonPerPoint
            )
            noisyValues.append(noisyValue)
        }
        
        privacyBudgetUsed += parameters.epsilon
        return noisyValues
    }
    
    /// Create a private frequency distribution
    public func createFrequencyDistribution<T: Hashable>(
        from data: [T],
        domain: [T]? = nil
    ) throws -> [T: Double] {
        try checkPrivacyBudget()
        
        let counts = Dictionary(data.map { ($0, 1) }, uniquingKeysWith: +)
        let domainSet = Set(domain ?? Array(counts.keys))
        var distribution: [T: Double] = [:]
        
        let total = Double(data.count)
        let epsilonPerItem = parameters.epsilon / Double(domainSet.count)
        
        for item in domainSet {
            let count = counts[item] ?? 0
            let frequency = Double(count) / total
            
            let noisyFrequency = try addLaplaceNoise(
                to: frequency,
                sensitivity: 1.0 / total,
                epsilon: epsilonPerItem
            )
            
            distribution[item] = max(0.0, min(1.0, noisyFrequency))
        }
        
        // Normalize to ensure probabilities sum to 1
        let totalFreq = distribution.values.reduce(0, +)
        if totalFreq > 0 {
            for key in distribution.keys {
                distribution[key] = distribution[key]! / totalFreq
            }
        }
        
        privacyBudgetUsed += parameters.epsilon
        return distribution
    }
    
    /// Check remaining privacy budget
    public func getRemainingPrivacyBudget() -> Double {
        return max(0, maxPrivacyBudget - privacyBudgetUsed)
    }
    
    /// Reset privacy budget (use with caution)
    public func resetPrivacyBudget() {
        privacyBudgetUsed = 0.0
    }
    
    /// Get privacy parameters
    public func getPrivacyParameters() -> PrivacyParameters {
        return parameters
    }
    
    // MARK: - Private Methods
    
    private func checkPrivacyBudget() throws {
        guard privacyBudgetUsed + parameters.epsilon <= maxPrivacyBudget else {
            throw PrivacyError.budgetExhausted
        }
    }
    
    private func addLaplaceNoise(
        to value: Double,
        sensitivity: Double,
        epsilon: Double
    ) throws -> Double {
        guard epsilon > 0 else {
            throw PrivacyError.invalidEpsilon
        }
        
        guard sensitivity > 0 else {
            throw PrivacyError.invalidSensitivity
        }
        
        let scale = sensitivity / epsilon
        let noise = sampleLaplace(scale: scale)
        
        return value + noise
    }
    
    private func addGaussianNoise(
        to value: Double,
        sensitivity: Double,
        epsilon: Double,
        delta: Double
    ) throws -> Double {
        guard epsilon > 0 else {
            throw PrivacyError.invalidEpsilon
        }
        
        guard delta > 0 && delta < 1 else {
            throw PrivacyError.invalidDelta
        }
        
        guard sensitivity > 0 else {
            throw PrivacyError.invalidSensitivity
        }
        
        // Calculate standard deviation for Gaussian mechanism
        let c = sqrt(2 * log(1.25 / delta))
        let sigma = c * sensitivity / epsilon
        
        let noise = sampleGaussian(mean: 0.0, standardDeviation: sigma)
        return value + noise
    }
    
    private func sampleLaplace(scale: Double) -> Double {
        // Sample from uniform distribution [-0.5, 0.5]
        let u = Double.random(in: -0.5...0.5, using: &randomNumberGenerator)
        
        // Transform to Laplace distribution
        if u < 0 {
            return scale * log(1 + 2 * u)
        } else {
            return -scale * log(1 - 2 * u)
        }
    }
    
    private func sampleGaussian(mean: Double, standardDeviation: Double) -> Double {
        // Box-Muller transform for Gaussian sampling
        let u1 = Double.random(in: 0.0...1.0, using: &randomNumberGenerator)
        let u2 = Double.random(in: 0.0...1.0, using: &randomNumberGenerator)
        
        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
        return mean + standardDeviation * z0
    }
}

// MARK: - Error Types

public enum PrivacyError: Error {
    case budgetExhausted
    case invalidEpsilon
    case invalidDelta
    case invalidSensitivity
    case insufficientData
    
    public var localizedDescription: String {
        switch self {
        case .budgetExhausted:
            return "Privacy budget has been exhausted"
        case .invalidEpsilon:
            return "Epsilon must be positive"
        case .invalidDelta:
            return "Delta must be between 0 and 1"
        case .invalidSensitivity:
            return "Sensitivity must be positive"
        case .insufficientData:
            return "Insufficient data for differential privacy analysis"
        }
    }
}

// MARK: - Extensions for Common Operations

extension DifferentialPrivacyManager {
    
    /// Create privacy-preserving usage statistics
    public func createUsageStatistics(
        commands: [String],
        timestamps: [Date]
    ) throws -> [String: Any] {
        try checkPrivacyBudget()
        
        // Command frequency distribution
        let commandFreqs = try createFrequencyDistribution(from: commands)
        
        // Hourly usage pattern
        let hours = timestamps.map { Calendar.current.component(.hour, from: $0) }
        let hourlyPattern = try createPrivateHistogram(from: hours)
        
        // Daily usage count (with noise)
        let dailyUsage = Dictionary(grouping: timestamps) { 
            Calendar.current.startOfDay(for: $0)
        }.mapValues { $0.count }
        
        var noisyDailyUsage: [Date: Int] = [:]
        for (date, count) in dailyUsage {
            noisyDailyUsage[date] = try addNoiseToCount(count)
        }
        
        return [
            "command_frequencies": commandFreqs,
            "hourly_pattern": hourlyPattern,
            "daily_usage": noisyDailyUsage,
            "privacy_parameters": [
                "epsilon": parameters.epsilon,
                "delta": parameters.delta,
                "budget_used": privacyBudgetUsed,
                "budget_remaining": getRemainingPrivacyBudget()
            ]
        ]
    }
    
    /// Create privacy-preserving performance metrics
    public func createPerformanceStatistics(
        responseTimes: [TimeInterval],
        accuracyScores: [Double],
        processingModes: [String]
    ) throws -> [String: Any] {
        try checkPrivacyBudget()
        
        // Average response time with noise
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let noisyAvgResponseTime = try addNoiseToAverage(avgResponseTime, count: responseTimes.count)
        
        // Average accuracy with noise
        let avgAccuracy = accuracyScores.reduce(0, +) / Double(accuracyScores.count)
        let noisyAvgAccuracy = try addNoiseToAverage(avgAccuracy, count: accuracyScores.count)
        
        // Processing mode distribution
        let modeDistribution = try createFrequencyDistribution(from: processingModes)
        
        return [
            "average_response_time": noisyAvgResponseTime,
            "average_accuracy": noisyAvgAccuracy,
            "processing_mode_distribution": modeDistribution,
            "sample_count": try addNoiseToCount(responseTimes.count)
        ]
    }
}