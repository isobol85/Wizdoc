import Foundation

@MainActor
class AppState: ObservableObject {
    @Published var userId: String?
    @Published var isProcessing: Bool = false
    @Published var currentCard: Card?
    @Published var archive: [Card] = []
} 