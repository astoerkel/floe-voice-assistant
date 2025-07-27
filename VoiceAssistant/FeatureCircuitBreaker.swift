import Foundation

/// Circuit breaker pattern for feature protection
/// Automatically disables features that fail repeatedly
class FeatureCircuitBreaker {
    private var failureCount = 0
    private let maxFailures: Int
    private let resetInterval: TimeInterval
    private var lastFailureTime: Date?
    private var isOpen = false
    
    /// Initialize circuit breaker
    /// - Parameters:
    ///   - maxFailures: Number of failures before circuit opens (default: 3)
    ///   - resetInterval: Time in seconds before circuit attempts to close (default: 60)
    init(maxFailures: Int = 3, resetInterval: TimeInterval = 60) {
        self.maxFailures = maxFailures
        self.resetInterval = resetInterval
    }
    
    /// Execute a feature with circuit breaker protection
    /// - Parameter feature: The feature closure to execute
    /// - Returns: Success status
    @discardableResult
    func executeFeature(_ feature: () throws -> Void) -> Bool {
        // Check if circuit should be reset
        if let lastFailure = lastFailureTime,
           Date().timeIntervalSince(lastFailure) > resetInterval {
            reset()
        }
        
        // Check if circuit is open
        guard !isOpen else {
            print("🚫 Circuit breaker OPEN - Feature disabled due to repeated failures")
            return false
        }
        
        do {
            try feature()
            // Reset on success
            if failureCount > 0 {
                print("✅ Feature recovered - Resetting circuit breaker")
                reset()
            }
            return true
        } catch {
            failureCount += 1
            lastFailureTime = Date()
            print("⚠️ Feature failed \(failureCount)/\(maxFailures) times: \(error.localizedDescription)")
            
            if failureCount >= maxFailures {
                isOpen = true
                print("🔴 Circuit breaker OPENED - Feature disabled after \(maxFailures) failures")
            }
            return false
        }
    }
    
    /// Execute async feature with circuit breaker protection
    @discardableResult
    func executeFeature(_ feature: () async throws -> Void) async -> Bool {
        // Check if circuit should be reset
        if let lastFailure = lastFailureTime,
           Date().timeIntervalSince(lastFailure) > resetInterval {
            reset()
        }
        
        // Check if circuit is open
        guard !isOpen else {
            print("🚫 Circuit breaker OPEN - Feature disabled due to repeated failures")
            return false
        }
        
        do {
            try await feature()
            // Reset on success
            if failureCount > 0 {
                print("✅ Feature recovered - Resetting circuit breaker")
                reset()
            }
            return true
        } catch {
            failureCount += 1
            lastFailureTime = Date()
            print("⚠️ Feature failed \(failureCount)/\(maxFailures) times: \(error.localizedDescription)")
            
            if failureCount >= maxFailures {
                isOpen = true
                print("🔴 Circuit breaker OPENED - Feature disabled after \(maxFailures) failures")
            }
            return false
        }
    }
    
    /// Reset the circuit breaker
    func reset() {
        failureCount = 0
        lastFailureTime = nil
        isOpen = false
    }
    
    /// Force close the circuit (for manual recovery)
    func forceClose() {
        reset()
        print("🔧 Circuit breaker manually closed")
    }
    
    /// Get current circuit state
    var state: CircuitState {
        if isOpen {
            return .open
        } else if failureCount > 0 {
            return .halfOpen
        } else {
            return .closed
        }
    }
    
    enum CircuitState {
        case open      // Feature is disabled
        case halfOpen  // Feature has failures but still trying
        case closed    // Feature is working normally
    }
}

// MARK: - Feature-Specific Circuit Breakers

/// Singleton circuit breakers for different features
struct FeatureCircuitBreakers {
    static let speechRecognition = FeatureCircuitBreaker(maxFailures: 3, resetInterval: 60)
    static let apiConnection = FeatureCircuitBreaker(maxFailures: 5, resetInterval: 30)
    static let watchConnectivity = FeatureCircuitBreaker(maxFailures: 3, resetInterval: 120)
    static let mlProcessing = FeatureCircuitBreaker(maxFailures: 2, resetInterval: 180)
    static let audioRecording = FeatureCircuitBreaker(maxFailures: 3, resetInterval: 45)
    
    /// Get status of all circuit breakers
    static func printStatus() {
        print("🔌 Circuit Breaker Status:")
        print("  Speech Recognition: \(speechRecognition.state)")
        print("  API Connection: \(apiConnection.state)")
        print("  Watch Connectivity: \(watchConnectivity.state)")
        print("  ML Processing: \(mlProcessing.state)")
        print("  Audio Recording: \(audioRecording.state)")
    }
}

// MARK: - Usage Example

/*
// Basic usage:
FeatureCircuitBreakers.speechRecognition.executeFeature {
    try startSpeechRecognition()
}

// Async usage:
await FeatureCircuitBreakers.apiConnection.executeFeature {
    try await sendAudioToAPI()
}

// Check status:
if FeatureCircuitBreakers.speechRecognition.state == .open {
    // Use fallback method
}

// Manual recovery:
FeatureCircuitBreakers.speechRecognition.forceClose()
*/