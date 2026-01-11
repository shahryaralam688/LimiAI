import SwiftUI

// MARK: - Models

enum UseCase: String, CaseIterable, Codable, Identifiable {
    case home = "Home"
    case business = "Business"
    case hospitality = "Hospitality"
    case others = "Others"

    var id: String { rawValue }
}

enum Goal: String, CaseIterable, Codable, Identifiable {
    case aiAutomation = "AI Automation"
    case smartControl = "Smart Control"
    case energyManagement = "Energy Management"
    case security = "Security"
    case ambientExperience = "Ambient Experience"
    case experimenting = "Experimenting"

    var id: String { rawValue }
}

struct OnboardingData: Codable {
    var name: String = ""
    var useCase: UseCase? = nil
    var goals: [Goal] = []
    var bluetoothAllowed: Bool? = nil
}

// MARK: - ViewModel

final class OnboardingViewModel: ObservableObject {
    @Published var name: String = "" {
        didSet { save() }
    }

    @Published var selectedUseCase: UseCase? = nil {
        didSet { save() }
    }

    @Published var selectedGoals: Set<Goal> = [] {
        didSet { save() }
    }

    @Published var bluetoothAllowed: Bool? = nil {
        didSet { save() }
    }

    private let storageKey = "onboarding_data"

    init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode(OnboardingData.self, from: data) {
            name = decoded.name
            selectedUseCase = decoded.useCase
            selectedGoals = Set(decoded.goals)
            bluetoothAllowed = decoded.bluetoothAllowed
        }
    }

    private func save() {
        let model = OnboardingData(
            name: name,
            useCase: selectedUseCase,
            goals: Array(selectedGoals),
            bluetoothAllowed: bluetoothAllowed
        )

        if let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func completeOnboarding() {
        // Prepare payload for backend user preference API
        let userName = name
        let whereLimiUsed = selectedUseCase?.rawValue
        let puroseOfLimi = Array(selectedGoals).map { $0.rawValue }

        guard let url = URL(string: "https://dev.api.limitless-lighting.co.uk/sendUserPreference") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.getToken(), !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "userName": userName,
            "whereLimiUsed": whereLimiUsed as Any,
            "puroseOfLimi": puroseOfLimi
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Onboarding] sendUserPreference error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("[Onboarding] sendUserPreference status: \(http.statusCode)")
            }

            if let data = data, let raw = String(data: data, encoding: .utf8) {
                print("[Onboarding] sendUserPreference response: \(raw)")
            }
        }.resume()
    }
}

// MARK: - Root App

#Preview{
            OnboardingFlowView()
}

// MARK: - Flow Container

struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var step: Int = 1
    private let totalSteps: Int = 4
    @State private var showHomeView = false
    @State private var showDemoScanView = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if step <= 3 {
                        OnboardingHeader(step: step, total: totalSteps)
                    }

                    Spacer().frame(height: 24)

                    switch step {
                    case 1:
                        NameStepView(
                            name: $viewModel.name,
                            onContinue: { step += 1 }
                        )
                    case 2:
                        UseCaseStepView(
                            selectedUseCase: $viewModel.selectedUseCase,
                            onContinue: { step += 1 }
                        )
                    case 3:
                        GoalsStepView(
                            selectedGoals: $viewModel.selectedGoals,
                            onContinue: { step += 1 }
                        )
                    default:
                        BluetoothStepView(
                            onSkip: {
                                viewModel.bluetoothAllowed = false
                                viewModel.completeOnboarding()
                                AuthManager.shared.isAuthenticated = true
                                showHomeView = true
                            },
                            onAllow: {
                                viewModel.bluetoothAllowed = true
                                viewModel.completeOnboarding()
                                AuthManager.shared.isAuthenticated = true
                                showDemoScanView = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .fullScreenCover(isPresented: $showHomeView) {
            HomeView()
        }
        .fullScreenCover(isPresented: $showDemoScanView) {
            DemoScanDevicesView()
        }
    }
}

// MARK: - Shared Header

struct OnboardingHeader: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack {
            Button(action: {
                // let parent handle back if needed
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

                Text("Personalize")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

            Spacer()
            
            Text("\(step) of \(total)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "43EB25"))      // text color
                .padding(.horizontal, 12)                   // Figma: padding X = 12
                .padding(.vertical, 6)                      // Figma: padding Y = 6
                .background(
                    RoundedRectangle(cornerRadius: 11)      // Figma: corner radius = 11
                        .fill(Color(hex: "17543B"))         // Figma: fill color
                )

            

//            Spacer().frame(width: 44) // balance chevron space
        }
        .padding(.top, 16)
    }
}

// MARK: - Step 1: Name

struct NameStepView: View {
    @Binding var name: String
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("What should we call you?")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField("Enter Your Name", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .font(.system(size: 30, weight: .medium))
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.white.opacity(0.3)),
                    alignment: .bottom
                )

            Spacer()

            PrimaryButton(
                title: "Continue",
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                action: onContinue
            )
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Step 2: Use Case (single select)

struct UseCaseStepView: View {
    @Binding var selectedUseCase: UseCase?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where will you use LIMI?")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("(Select any one)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer().frame(height: 12)

            ForEach(UseCase.allCases) { option in
                SelectableRow(
                    title: option.rawValue,
                    isSelected: selectedUseCase == option
                ) {
                    selectedUseCase = option
                }
            }

            Spacer()

            PrimaryButton(
                title: "Continue",
                isEnabled: selectedUseCase != nil,
                action: onContinue
            )
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Step 3: Goals (multi select)

struct GoalsStepView: View {
    @Binding var selectedGoals: Set<Goal>
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("What do you want LIMI to help with?")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("(Select one or more)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer().frame(height: 12)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Goal.allCases) { goal in
                        SelectableRow(
                            title: goal.rawValue,
                            isSelected: selectedGoals.contains(goal)
                        ) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }

            PrimaryButton(
                title: "Finish",
                isEnabled: !selectedGoals.isEmpty,
                action: onContinue
            )
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Step 4: Bluetooth permission

struct BluetoothStepView: View {
    var onSkip: () -> Void
    var onAllow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 40)

            Text("Allow LIMI AI to use\nBluetooth")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            Text("LIMI AI needs permission to use your mobile device's Bluetooth connection so nearby products can be automatically discovered.")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16))
                .lineSpacing(4)

            Spacer()

            Button(action: onSkip) {
                Text("Skip")
                    .underline()
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 12)

            PrimaryButton(
                title: "Allow",
                isEnabled: true,
                action: onAllow
            )
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Reusable UI

struct PrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled { action() }
        }) {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isEnabled ? Color.green : Color.gray.opacity(0.5))
                .foregroundColor(.black)
                .cornerRadius(28)
        }
        .disabled(!isEnabled)
    }
}

struct SelectableRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )
                .cornerRadius(28)
        }
    }
}
