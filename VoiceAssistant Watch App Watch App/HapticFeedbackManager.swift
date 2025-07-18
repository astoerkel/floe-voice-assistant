import Foundation
import SwiftUI
import WatchKit

class HapticFeedbackManager: ObservableObject {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    enum HapticPattern {
        case listening
        case processing
        case success
        case error
        case response(ActionType)
    }
    
    enum ActionType {
        case calendar
        case email
        case task
        case reminder
        case query
        case general
    }
    
    func triggerHaptic(for pattern: HapticPattern) {
        let device = WKInterfaceDevice.current()
        
        switch pattern {
        case .listening:
            device.play(.click)
            
        case .processing:
            device.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                device.play(.click)
            }
            
        case .success:
            device.play(.success)
            
        case .error:
            device.play(.failure)
            
        case .response(let actionType):
            switch actionType {
            case .calendar:
                device.play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    device.play(.click)
                }
                
            case .email:
                device.play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    device.play(.click)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    device.play(.click)
                }
                
            case .task:
                device.play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    device.play(.click)
                }
                
            case .reminder:
                device.play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    device.play(.click)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    device.play(.click)
                }
                
            case .query:
                device.play(.click)
                
            case .general:
                device.play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    device.play(.click)
                }
            }
        }
    }
    
    func triggerContinuousHaptic() {
        let device = WKInterfaceDevice.current()
        
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            device.play(.click)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            device.play(.click)
        }
    }
    
    func stopContinuousHaptic() {
        // Cancel any pending haptic feedback
    }
    
    func determineActionType(from text: String) -> ActionType {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("meeting") || lowercaseText.contains("calendar") || lowercaseText.contains("schedule") || lowercaseText.contains("appointment") {
            return .calendar
        } else if lowercaseText.contains("email") || lowercaseText.contains("message") || lowercaseText.contains("mail") {
            return .email
        } else if lowercaseText.contains("task") || lowercaseText.contains("todo") || lowercaseText.contains("reminder") {
            return .task
        } else if lowercaseText.contains("remind") || lowercaseText.contains("alert") {
            return .reminder
        } else if lowercaseText.contains("what") || lowercaseText.contains("when") || lowercaseText.contains("where") || lowercaseText.contains("how") {
            return .query
        } else {
            return .general
        }
    }
}