import AVFoundation

class MinimalAudioRecorder: ObservableObject {
    @Published var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    
    func startRecording() {
        // Basic recording setup
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord)
        try? session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return audioRecorder?.url
    }
}