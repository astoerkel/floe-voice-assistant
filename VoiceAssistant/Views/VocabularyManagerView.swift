import SwiftUI

struct VocabularyManagerView: View {
    let vocabularyManager: VocabularyManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "textbook")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Vocabulary Manager")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Manage custom vocabulary and pronunciation preferences")
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
            .navigationTitle("Vocabulary")
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

#Preview {
    VocabularyManagerView(vocabularyManager: VocabularyManager())
}