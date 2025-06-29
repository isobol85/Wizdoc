//
//  ContentView.swift
//  WizDoc
//
//  Created by Ilya Sobol on 6/23/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: AppState
    @State private var selectedTab = 3 // Default to Record tab (now tag 3)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                // Placeholder for Settings interface
                Text("Settings Interface Coming Soon")
                    .navigationTitle("Settings")
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(0)

            CardView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Card")
                }
                .tag(1)
                .disabled(state.currentCard == nil)

            NavigationView {
                // Placeholder for Archive interface
                Text("Archive Interface Coming Soon")
                    .navigationTitle("Teaching Archive")
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tabItem {
                Image(systemName: "folder.fill")
                Text("Archive")
            }
            .tag(2)
            
            RecordingView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
                .tag(3)
        }
        .preferredColorScheme(.light) // Force light mode for now
        .accentColor(Color(hex: "#007AFF"))
        .onChange(of: state.currentCard) { _, newCard in
            // When a new card is created, switch to the Card tab
            if newCard != nil {
                selectedTab = 1 // Card tab is now tag 1
            }
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(hex: "#F2F2F7")
    }
}

// Helper to use hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

// MARK: - RecordingView
struct RecordingView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var audioManager = AudioRecorderManager()
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var isProcessing = false
    @State private var processingStage: String? = nil // e.g., "recording", "transcribing", etc.
    @State private var selectedPromptName: String = "Default Prompt"
    @State private var selectedModelName: String = "Default Model"
    @State private var showPromptSelector = false
    @State private var showModelSelector = false
    @State private var randomTip: String = ""
    
    // Pulse animation
    @State private var pulse = false
    
    // Placeholder for recent recordings
    let medicalTips = [
        "WizDoc automatically formats clinical wisdom for easy reference.",
        "Teaching moments captured now can benefit learners for years to come.",
        "The best medical documentation captures both facts and clinical reasoning.",
        "Regular teaching improves both the teacher's and learner's knowledge retention.",
        "Modern medical education blends traditional teaching with digital tools.",
        "Clear documentation is essential for knowledge transfer in medicine.",
        "Sharing clinical pearls helps standardize best practices across an organization."
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                // Timer
                if isRecording {
                    Text(formattedDuration)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                } else {
                    Spacer().frame(height: 32)
                }
                // Pulse + Record Button (even bigger and higher)
                ZStack {
                    if isRecording {
                        Circle()
                            .fill(Color.red.opacity(0.25))
                            .frame(width: 320, height: 320)
                            .scaleEffect(pulse ? 1.15 : 0.9)
                            .opacity(pulse ? 0.5 : 0.25)
                            .animation(Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                            .onAppear { pulse = true }
                            .onDisappear { pulse = false }
                    }
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color(hex: "#007AFF"))
                                .frame(width: 200, height: 200)
                                .shadow(radius: 24)
                            if isRecording {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 90, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Stop")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .offset(y: 80)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 90, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Record")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .offset(y: 80)
                            }
                        }
                    }
                    .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
                }
                .padding(.bottom, 32)
                // Instructions
                Text("Tap record to capture teaching moment")
                    .font(.footnote)
                    .foregroundColor(Color(.systemGray3))
                    .padding(.bottom, 40)
                Spacer(minLength: 0)
                // Move selector buttons further down
                VStack(spacing: 16) {
                    Button(action: { showPromptSelector = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("Using: ")
                                .foregroundColor(.primary)
                            Text(selectedPromptName)
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray5), lineWidth: 1))
                    }
                    .padding(.horizontal)
                    Button(action: { showModelSelector = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .foregroundColor(.accentColor)
                            Text("Model: ")
                                .foregroundColor(.primary)
                            Text(selectedModelName)
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray5), lineWidth: 1))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Loading Overlay
            if state.isProcessing, let stage = processingStage {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 32) {
                    // Animated icon (placeholder)
                    Image(systemName: iconForStage(stage))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor)
                        .padding(.top, 40)
                        .transition(.scale)
                    Text(messageForStage(stage))
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(randomTip)
                        .font(.body.italic())
                        .foregroundColor(Color(.systemGray3))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    Spacer()
                }
                .onAppear {
                    randomTip = medicalTips.randomElement() ?? "" 
                }
            }
        }
    }
    // MARK: - Timer & Recording Logic
    func startRecording() {
        state.isProcessing = false
        processingStage = "recording"
        // TODO: Integrate real audio recording
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Mock timer
        }
    }
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        processingStage = "transcribing"
        state.isProcessing = true
        
        // Simulate processing stages and card creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            processingStage = "analyzing"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                processingStage = "generating"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    processingStage = "refining"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        // Create a dummy card and set it on the app state
                        let dummyCard = Card(id: UUID(), userId: state.userId ?? "previewUser", title: "New Teaching Moment", evidence: "", wisdom: "", transcript: "This is a dummy transcript.", createdAt: Date())
                        state.currentCard = dummyCard
                        state.isProcessing = false
                        processingStage = nil
                    }
                }
            }
        }
    }
    var formattedDuration: String {
        let duration = audioManager.currentTime
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    func iconForStage(_ stage: String) -> String {
        switch stage {
        case "recording": return "waveform"
        case "transcribing": return "brain.head.profile"
        case "analyzing": return "stethoscope"
        case "generating": return "heart.text.square"
        case "refining": return "pills"
        default: return "hourglass"
        }
    }
    func messageForStage(_ stage: String) -> String {
        switch stage {
        case "recording": return "Recording audio..."
        case "transcribing": return "Transcribing your recording..."
        case "analyzing": return "Analyzing medical content..."
        case "generating": return "Generating WizDoc..."
        case "refining": return "Refining content..."
        default: return "Processing..."
        }
    }
}

// MARK: - Animated Red Dot
struct AnimatedRedDot: View {
    @State private var scale: CGFloat = 1.0
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .animation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: scale)
            .onAppear { scale = 1.4 }
    }
}

// MARK: - Audio Level Bar (Placeholder)
struct AudioLevelBar: View {
    var level: CGFloat // 0.0 to 1.0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray4))
                Capsule()
                    .fill(Color(hex: "#007AFF"))
                    .frame(width: geo.size.width * level)
            }
        }
    }
}
