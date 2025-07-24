import SwiftUI

struct PatternLearningView: View {
    let patternLearning: SpeechPatternLearning
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Pattern Learning")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("View and manage learned speech patterns and recognition improvements")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Pattern Learning")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PatternLearningView_Previews: PreviewProvider {
    static var previews: some View {
        PatternLearningView(patternLearning: SpeechPatternLearning())
    }
}