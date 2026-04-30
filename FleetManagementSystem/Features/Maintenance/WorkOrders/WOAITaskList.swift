import Foundation
import SwiftUI 
import FoundationModels
import Combine

// 1. Define the strictly typed structure we want the model to return
@Generable
struct MaintenanceTaskList {
    var tasks: [String]
}

@MainActor
class OnDeviceAIService: ObservableObject {
    @Published var isGenerating = false
    
    // Check if Apple Intelligence is supported and active on the device
    var isSupported: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    // Set up the session with strict system instructions
    private let session = LanguageModelSession(
        instructions: "You are an expert fleet maintenance mechanic. Based on the issue description provided, generate a list of 3 to 5 clear, concise step-by-step diagnostic and repair tasks. Return ONLY the tasks."
    )
    
    func generateTasks(from description: String) async -> [String] {
        guard isSupported, !description.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let response = try await session.respond(
                to: description,
                generating: MaintenanceTaskList.self
            )
            
            return response.content.tasks
            
        } catch {
            print("🚨 AI Generation failed: \(error)")
            return []
        }
    }
}
