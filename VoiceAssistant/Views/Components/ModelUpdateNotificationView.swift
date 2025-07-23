import SwiftUI

/// Non-intrusive notification view for model updates
struct ModelUpdateNotificationView: View {
    @ObservedObject var updateManager: ModelUpdateManager
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    
    var body: some View {
        Group {
            if shouldShowNotification {
                notificationContent
                    .offset(y: offset)
                    .opacity(isVisible ? 1 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isVisible = true
                            offset = 0
                        }
                        
                        // Auto-hide after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            hideNotification()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.y < -50 {
                                    hideNotification()
                                }
                            }
                    )
            }
        }
    }
    
    private var shouldShowNotification: Bool {
        switch updateManager.updateStatus {
        case .idle:
            return updateManager.isUpdateAvailable
        case .completed:
            return true
        case .failed(_):
            return true
        default:
            return false
        }
    }
    
    private var notificationContent: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: notificationIcon)
                .font(.title2)
                .foregroundColor(notificationColor)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notificationMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action buttons
            notificationActions
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var notificationActions: some View {
        switch updateManager.updateStatus {
        case .idle where updateManager.isUpdateAvailable:
            HStack(spacing: 8) {
                Button("Later") {
                    hideNotification()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("Update") {
                    Task {
                        await updateManager.startUpdate(strategy: .optimal)
                    }
                    hideNotification()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            
        case .completed:
            Button("Dismiss") {
                hideNotification()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
        case .failed(_):
            Button("Retry") {
                Task {
                    await updateManager.checkForUpdates()
                }
                hideNotification()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            
        default:
            EmptyView()
        }
    }
    
    private var notificationIcon: String {
        switch updateManager.updateStatus {
        case .idle where updateManager.isUpdateAvailable:
            return "arrow.down.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed(_):
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    private var notificationColor: Color {
        switch updateManager.updateStatus {
        case .idle where updateManager.isUpdateAvailable:
            return .blue
        case .completed:
            return .green
        case .failed(_):
            return .orange
        default:
            return .secondary
        }
    }
    
    private var notificationTitle: String {
        switch updateManager.updateStatus {
        case .idle where updateManager.isUpdateAvailable:
            return "Model Update Available"
        case .completed:
            return "Update Complete"
        case .failed(_):
            return "Update Failed"
        default:
            return "Model Update"
        }
    }
    
    private var notificationMessage: String {
        switch updateManager.updateStatus {
        case .idle where updateManager.isUpdateAvailable:
            if let version = updateManager.availableVersion {
                return "Version \(version) is ready to install"
            }
            return "A new model version is available"
            
        case .completed:
            if let version = updateManager.currentVersion {
                return "Successfully updated to version \(version)"
            }
            return "Your model has been updated successfully"
            
        case .failed(let error):
            return error.localizedDescription
            
        default:
            return ""
        }
    }
    
    private func hideNotification() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            offset = -100
            isVisible = false
        }
    }
}

/// Floating update progress indicator for ongoing downloads
struct ModelUpdateProgressView: View {
    @ObservedObject var updateManager: ModelUpdateManager
    @State private var isVisible = false
    
    var body: some View {
        Group {
            if shouldShowProgress {
                progressContent
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .opacity(isVisible ? 1 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isVisible = true
                        }
                    }
                    .onDisappear {
                        isVisible = false
                    }
            }
        }
    }
    
    private var shouldShowProgress: Bool {
        switch updateManager.updateStatus {
        case .downloading, .validating, .installing:
            return true
        default:
            return false
        }
    }
    
    private var progressContent: some View {
        VStack(spacing: 8) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progressValue)
                
                Image(systemName: progressIcon)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Status text
            VStack(spacing: 2) {
                Text(progressTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if case .downloading = updateManager.updateStatus {
                    Text("\(Int(updateManager.downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var progressValue: Double {
        switch updateManager.updateStatus {
        case .downloading:
            return updateManager.downloadProgress
        case .validating:
            return 0.8
        case .installing:
            return 0.95
        default:
            return 0.0
        }
    }
    
    private var progressIcon: String {
        switch updateManager.updateStatus {
        case .downloading:
            return "arrow.down"
        case .validating:
            return "checkmark.shield"
        case .installing:
            return "gear"
        default:
            return "circle"
        }
    }
    
    private var progressTitle: String {
        switch updateManager.updateStatus {
        case .downloading:
            return "Downloading"
        case .validating:
            return "Validating"
        case .installing:
            return "Installing"
        default:
            return "Updating"
        }
    }
}

/// Toast notification for quick status updates
struct ModelUpdateToast: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    
    enum ToastType {
        case success
        case error
        case info
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .info:
                return .blue
            }
        }
    }
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Usage Examples

struct ModelUpdateNotificationContainer: View {
    @StateObject private var updateManager: ModelUpdateManager
    @StateObject private var versionControl: ModelVersionControl
    
    @State private var showSuccessToast = false
    @State private var showErrorToast = false
    @State private var toastMessage = ""
    
    init() {
        let versionControl = ModelVersionControl()
        let updateManager = ModelUpdateManager(
            updateServerURL: URL(string: "https://api.voiceassistant.com/models")!,
            versionControl: versionControl
        )
        
        self._updateManager = StateObject(wrappedValue: updateManager)
        self._versionControl = StateObject(wrappedValue: versionControl)
    }
    
    var body: some View {
        ZStack {
            // Main content
            Color.clear
            
            // Update notifications (top)
            VStack {
                ModelUpdateNotificationView(updateManager: updateManager)
                
                ModelUpdateToast(
                    message: toastMessage,
                    type: showErrorToast ? .error : .success,
                    isShowing: .constant(showSuccessToast || showErrorToast)
                )
                
                Spacer()
            }
            
            // Progress indicator (bottom trailing)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    ModelUpdateProgressView(updateManager: updateManager)
                        .padding(.trailing)
                        .padding(.bottom, 100) // Above tab bar
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ModelUpdateCompleted"))) { _ in
            toastMessage = "Model updated successfully"
            showSuccessToast = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ModelUpdateFailed"))) { notification in
            if let error = notification.userInfo?["error"] as? Error {
                toastMessage = "Update failed: \(error.localizedDescription)"
            } else {
                toastMessage = "Update failed"
            }
            showErrorToast = true
        }
    }
}

// MARK: - Preview

struct ModelUpdateNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        ModelUpdateNotificationContainer()
    }
}