import SwiftUI

// MARK: - Models

enum UseCase: String, CaseIterable, Codable, Identifiable {
    case home = "Home"
    case business = "Business"
    case hospitality = "Hospitality"
    case others = "Others"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .business: return "building.2.fill"
        case .hospitality: return "bed.double.fill"
        case .others: return "sparkles"
        }
    }
}

enum Goal: String, CaseIterable, Codable, Identifiable {
    case aiAutomation = "AI Automation"
    case smartControl = "Smart Control"
    case energyManagement = "Energy Management"
    case security = "Security"
    case ambientExperience = "Ambient Experience"
    case experimenting = "Experimenting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aiAutomation: return "cpu"
        case .smartControl: return "slider.horizontal.3"
        case .energyManagement: return "bolt.fill"
        case .security: return "shield.fill"
        case .ambientExperience: return "light.max"
        case .experimenting: return "flask.fill"
        }
    }
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
        let userName = name
        let whereLimiUsed = selectedUseCase?.rawValue
        let puroseOfLimi = Array(selectedGoals).map { $0.rawValue }

        guard let url = URL(string: APIConstants.sendUserPreference) else { return }

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

// MARK: - Root Preview

#Preview {
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
                DeepSpaceBackground(showParticles: true)

                VStack(spacing: 0) {
                    if step <= 3 {
                        OnboardingHeader(step: step, total: totalSteps)
                    }

                    Spacer().frame(height: 24)

                    Group {
                        switch step {
                        case 1:
                            NameStepView(
                                name: $viewModel.name,
                                onContinue: { withAnimation(.easeInOut(duration: 0.35)) { step += 1 } }
                            )
                        case 2:
                            UseCaseStepView(
                                selectedUseCase: $viewModel.selectedUseCase,
                                onContinue: { withAnimation(.easeInOut(duration: 0.35)) { step += 1 } }
                            )
                        case 3:
                            GoalsStepView(
                                selectedGoals: $viewModel.selectedGoals,
                                onContinue: { withAnimation(.easeInOut(duration: 0.35)) { step += 1 } }
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
            LimiBackButton {}

            Spacer()

            Text("Personalize")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.appTextPrimary)

            Spacer()

            Text("\(step) of \(total)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orbGlow4)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orbGlow4.opacity(0.12))
                )
        }
        .padding(.top, 16)
    }
}

// MARK: - Step 1: Name

struct NameStepView: View {
    @Binding var name: String
    var onContinue: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Limi will use this to greet you")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            TextField("", text: $name, prompt: Text("Your name").foregroundColor(.appTextPlaceholder))
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .foregroundColor(.appTextPrimary)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .padding(.vertical, 12)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(isFocused ? Color.orbGlow4.opacity(0.5) : Color.white.opacity(0.12)),
                    alignment: .bottom
                )
                .focused($isFocused)

            Spacer()

            PrimaryButton(
                title: "Continue",
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                action: onContinue
            )
        }
        .padding(.bottom, 32)
        .onAppear { isFocused = true }
    }
}

// MARK: - Step 2: Use Case (single select)

struct UseCaseStepView: View {
    @Binding var selectedUseCase: UseCase?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where will you use Limi?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Select one")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer().frame(height: 8)

            ForEach(UseCase.allCases) { option in
                SelectableRow(
                    title: option.rawValue,
                    icon: option.icon,
                    isSelected: selectedUseCase == option
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedUseCase = option
                    }
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
                Text("What should Limi help with?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Select one or more")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer().frame(height: 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Goal.allCases) { goal in
                        SelectableRow(
                            title: goal.rawValue,
                            icon: goal.icon,
                            isSelected: selectedGoals.contains(goal)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
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
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(Color.orbGlow2.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.orbGlow4)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            Text("Allow Limi to use\nBluetooth")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.appTextPrimary)
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

            Text("Limi needs Bluetooth to discover nearby devices and bring your space to life.")
                .foregroundColor(.appTextSecondary)
                .font(.system(size: 15))
                .lineSpacing(5)
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 8)

            PrimaryButton(
                title: "Allow",
                isEnabled: true,
                action: onAllow
            )
        }
        .padding(.bottom, 32)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Reusable UI

// PrimaryButton is now an alias for the global LimiPrimaryButton
typealias PrimaryButton = LimiPrimaryButtonWrapper

struct LimiPrimaryButtonWrapper: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        LimiPrimaryButton(title: title, isEnabled: isEnabled, action: action)
    }
}

struct SelectableRow: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .orbGlow4 : .appTextMuted)
                        .frame(width: 24)
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orbGlow4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassCard(
                cornerRadius: 16,
                strokeOpacity: isSelected ? 0.2 : 0.06,
                fillOpacity: isSelected ? 0.08 : 0.04
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                        ? LinearGradient(colors: [.orbGlow4.opacity(0.4), .orbGlow1.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
        }
        .tapScale()
    }
}
