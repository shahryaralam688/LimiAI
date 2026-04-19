import SwiftUI
import Combine

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
            "purposeOfLimi": puroseOfLimi
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
    @State private var isCompleting = false
    /// Step 1: user confirms the typed name before Continue (pairs with voice “say yes when it’s correct”).
    @State private var nameStepConfirmed = false
    /// Steps 2–3: brief AI-selection pulse (white border + scale) when `personalize_set_field` updates a row.
    @State private var pulseUseCaseRaw: String?
    @State private var pulseGoalRaws: Set<String> = []
    @State private var pulseUseCaseGeneration = 0
    @State private var pulseGoalsGeneration = 0

    var body: some View {
        NavigationStack {
            ZStack {
                DeepSpaceBackground(showParticles: true)

                VStack(spacing: 0) {
                    if step <= 3 {
                        OnboardingHeader(step: $step, total: totalSteps)
                    }

                    Spacer().frame(height: 24)

                    Group {
                        switch step {
                        case 1:
                            NameStepView(
                                name: $viewModel.name,
                                nameConfirmed: $nameStepConfirmed,
                                onContinue: {
                                    withAnimation(LimiMotion.smooth) { step += 1 }
                                }
                            )
                        case 2:
                            UseCaseStepView(
                                selectedUseCase: $viewModel.selectedUseCase,
                                pulseHighlightRaw: pulseUseCaseRaw,
                                onContinue: { withAnimation(LimiMotion.smooth) { step += 1 } }
                            )
                        case 3:
                            GoalsStepView(
                                selectedGoals: $viewModel.selectedGoals,
                                pulseHighlightRaws: pulseGoalRaws,
                                onContinue: { withAnimation(LimiMotion.smooth) { step += 1 } }
                            )
                        default:
                            BluetoothStepView(
                                onSkip: {
                                    isCompleting = true
                                    viewModel.bluetoothAllowed = false
                                    viewModel.completeOnboarding()
                                    AuthManager.shared.isAuthenticated = true
                                    persistPendingHomeWelcome()
                                    showHomeView = true
                                },
                                onAllow: {
                                    isCompleting = true
                                    viewModel.bluetoothAllowed = true
                                    viewModel.completeOnboarding()
                                    AuthManager.shared.isAuthenticated = true
                                    persistPendingHomeWelcome()
                                    showDemoScanView = true
                                },
                                isLoading: isCompleting
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
        .onAppear {
            FloatingAssistantManager.shared.setPersonalizeFlowActive(true)
            syncPersonalizeContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                startPersonalizeVoiceIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                guard FloatingAssistantManager.shared.voiceClient.state == .connected else { return }
                FloatingAssistantManager.shared.voiceClient.requestProactiveAssistantTurn()
            }
        }
        .onDisappear {
            FloatingAssistantManager.shared.setPersonalizeFlowActive(false)
        }
        .onChange(of: showHomeView) { _, isShowingHome in
            if isShowingHome { FloatingAssistantManager.shared.setPersonalizeFlowActive(false) }
        }
        .onChange(of: showDemoScanView) { _, isShowingDemo in
            if isShowingDemo { FloatingAssistantManager.shared.setPersonalizeFlowActive(false) }
        }
        .onChange(of: step) { _, newStep in
            if newStep != 1 {
                nameStepConfirmed = false
            }
            pulseUseCaseGeneration += 1
            pulseGoalsGeneration += 1
            pulseUseCaseRaw = nil
            pulseGoalRaws = []
            syncPersonalizeContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard FloatingAssistantManager.shared.voiceClient.state == .connected else { return }
                FloatingAssistantManager.shared.voiceClient.requestProactiveAssistantTurn()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .limiPersonalizeToolUpdate)) { note in
            applyPersonalizeTool(note: note)
        }
    }

    /// Keep realtime voice session active while Personalize is visible (orb “on” when connected).
    private func startPersonalizeVoiceIfNeeded() {
        let voice = FloatingAssistantManager.shared.voiceClient
        switch voice.state {
        case .disconnected, .error:
            voice.start()
        case .connecting, .connected:
            break
        }
    }

    private func schedulePulseUseCaseHighlight(_ raw: String) {
        pulseUseCaseGeneration += 1
        let gen = pulseUseCaseGeneration
        pulseUseCaseRaw = raw
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            if gen == pulseUseCaseGeneration {
                pulseUseCaseRaw = nil
            }
        }
    }

    private func schedulePulseGoalsHighlight(_ raws: Set<String>) {
        pulseGoalsGeneration += 1
        let gen = pulseGoalsGeneration
        pulseGoalRaws = raws
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            if gen == pulseGoalsGeneration {
                pulseGoalRaws = []
            }
        }
    }

    /// First `HomeView` after this flow should run the spoken welcome; also used when user goes to Demo Scan first.
    private func persistPendingHomeWelcome() {
        let ud = UserDefaults.standard
        let k = ContextManager.PendingHomeWelcome.self
        ud.set(true, forKey: k.pendingFlag)
        ud.set(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: k.nameKey)
        ud.set(viewModel.selectedUseCase?.rawValue ?? "", forKey: k.useCaseKey)
        ud.set(viewModel.selectedGoals.map(\.rawValue).joined(separator: ", "), forKey: k.goalsKey)
    }

    private func applyPersonalizeTool(note: Notification) {
        guard let field = note.userInfo?["field"] as? String else { return }
        let value = (note.userInfo?["value"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        switch field.lowercased() {
        case "name":
            viewModel.name = value
            nameStepConfirmed = true
        case "use_case", "usecase":
            if let uc = Self.matchUseCase(from: value) {
                viewModel.selectedUseCase = uc
                schedulePulseUseCaseHighlight(uc.rawValue)
            }
        case "goals", "goal":
            let set = Self.matchGoals(from: value)
            if !set.isEmpty {
                viewModel.selectedGoals = set
                schedulePulseGoalsHighlight(Set(set.map(\.rawValue)))
            }
        default:
            break
        }
    }

    private static func matchUseCase(from raw: String) -> UseCase? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = UseCase.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(t) == .orderedSame }) {
            return exact
        }
        let lower = t.lowercased()
        if lower.contains("home") || lower.contains("house") { return .home }
        if lower.contains("business") || lower.contains("office") || lower.contains("work") { return .business }
        if lower.contains("hospitality") || lower.contains("hotel") { return .hospitality }
        if lower.contains("other") { return .others }
        return UseCase.allCases.first { lower.contains($0.rawValue.lowercased()) }
    }

    private static func matchGoals(from raw: String) -> Set<Goal> {
        let parts = raw.split(whereSeparator: { $0 == "," || $0 == ";" }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var out = Set<Goal>()
        for p in parts {
            if let g = Goal.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(p) == .orderedSame }) {
                out.insert(g)
                continue
            }
            let pl = p.lowercased()
            for g in Goal.allCases where pl.contains(g.rawValue.lowercased()) {
                out.insert(g)
            }
        }
        return out
    }

    private func syncPersonalizeContext() {
        var meta: [String: String] = [
            "step": "\(step)",
            "flow": "personalize",
            "total_steps": "\(totalSteps)"
        ]
        switch step {
        case 1: meta["step_name"] = "name"
        case 2: meta["step_name"] = "use_case"
        case 3: meta["step_name"] = "goals"
        default: meta["step_name"] = "bluetooth"
        }
        let trimmedName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { meta["pref_name"] = trimmedName }
        if let uc = viewModel.selectedUseCase { meta["use_case"] = uc.rawValue }
        if !viewModel.selectedGoals.isEmpty {
            meta["goals"] = viewModel.selectedGoals.map(\.rawValue).joined(separator: ",")
        }
        if let bt = viewModel.bluetoothAllowed {
            meta["bluetooth_pref"] = bt ? "allowed" : "skipped"
        }
        meta["ui_guide"] = Self.personalizeUIGuide(for: step)
        meta["assistant_behavior"] = Self.personalizeAssistantBehavior(for: step)
        meta["optional_tool"] = "If the Realtime session exposes personalize_set_field, call it with {field,value} to sync the UI. field: name | use_case | goals. goals value: comma-separated labels matching on-screen options."
        ContextManager.shared.updateContext(screen: "PersonalizeFlow", metadata: meta)
    }

    private static func personalizeUIGuide(for step: Int) -> String {
        switch step {
        case 1:
            return """
            Personalize step 1 of 4: Name. One large text field (placeholder “Your name”) and a primary “Continue” button at the bottom. \
            A switch “This is how I want to be called” must be on before Continue is enabled. \
            User can type or (if backend tool is enabled) voice can fill the field via personalize_set_field.
            """
        case 2:
            return """
            Personalize step 2 of 4: Where to use Limi. Four tappable rows: Home, Business, Hospitality, Others — single select. \
            Primary “Continue” at the bottom (enabled when one row is selected).
            """
        case 3:
            return """
            Personalize step 3 of 4: Goals. Scrollable list — multi-select rows (AI Automation, Smart Control, Energy Management, Security, Ambient Experience, Experimenting). \
            Primary “Continue” at the bottom (enabled when at least one goal is selected).
            """
        default:
            return """
            Personalize step 4 of 4: Bluetooth. Explains pairing. Two actions only on screen: text “Skip for now” (above) and primary “Allow” (bottom). \
            You cannot tap these buttons for the user.
            """
        }
    }

    private static func personalizeAssistantBehavior(for step: Int) -> String {
        switch step {
        case 1:
            return """
            PHASE 1 — NAME. Ask what they would like to be called. \
            If the session has tool personalize_set_field, use field \"name\" and value = the name they confirm, so the text field updates. \
            Otherwise ask them to type or edit the name in the field. \
            Read it back once and ask if it is correct. If they confirm it is correct, tell them clearly: tap the **Continue** button at the bottom (do not advance the app yourself). \
            Stay concise and spoken-friendly.
            """
        case 2:
            return """
            PHASE 2 — WHERE THEY USE LIMI. Options on screen: Home, Business, Hospitality, Others (pick exactly one). \
            You may ask where they mainly use Limi, or they may tell you without being asked. \
            Map what they say to one row; use tool personalize_set_field with field \"use_case\" and value = the exact label (e.g. Home) if available. \
            If they are unsure, briefly clarify then help them pick one. \
            When the selection matches their intent, tell them to tap **Continue** at the bottom.
            """
        case 3:
            return """
            PHASE 3 — WHY / GOALS. Multiple goals can be selected. \
            Encourage them to explain in their own words what they want Limi for; you can suggest matching on-screen goals. \
            If they ask you to select for them, you may map their words to one or more rows using tool personalize_set_field with field \"goals\" and comma-separated values matching labels (e.g. \"Smart Control, Security\"). \
            They can also tap rows themselves. When ready, tell them to tap **Continue** at the bottom.
            """
        default:
            return """
            PHASE 4 — BLUETOOTH / DEVICES. Explain clearly: Limi uses Bluetooth to find nearby lights and devices for pairing; it is needed for discovery and setup. \
            They may tap **Allow** to grant Bluetooth or **Skip for now** to continue without pairing. \
            If they ask you to choose Allow or Skip for them, say honestly that you cannot tap those buttons or decide for them — only they can press **Allow** or **Skip** on screen. \
            Do not pretend to perform the system permission for them.
            """
        }
    }
}

// MARK: - Shared Header

struct OnboardingHeader: View {
    @Binding var step: Int
    let total: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            LimiBackButton {
                if step > 1 {
                    withAnimation(LimiMotion.smooth) { step -= 1 }
                } else {
                    dismiss()
                }
            }

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
    @Binding var nameConfirmed: Bool
    var onContinue: () -> Void
    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Tell Limi or type below — confirm when it looks right, then tap Continue.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
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

            Toggle(isOn: $nameConfirmed) {
                Text("This is how I want to be called")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
            }
            .tint(.orbGlow4)
            .disabled(trimmedName.isEmpty)

            Spacer()

            PrimaryButton(
                title: "Continue",
                isEnabled: !trimmedName.isEmpty && nameConfirmed,
                action: onContinue
            )
        }
        .padding(.bottom, 32)
        .onAppear { isFocused = true }
        .onChange(of: name) { _, _ in
            if trimmedName.isEmpty { nameConfirmed = false }
        }
    }
}

// MARK: - Step 2: Use Case (single select)

struct UseCaseStepView: View {
    @Binding var selectedUseCase: UseCase?
    /// Matches `UseCase.rawValue` while AI pulse is active.
    var pulseHighlightRaw: String?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where will you use Limi?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Choose one place — tap a card or tell Limi, then Continue below.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 8)

            ForEach(UseCase.allCases) { option in
                SelectableRow(
                    title: option.rawValue,
                    icon: option.icon,
                    isSelected: selectedUseCase == option,
                    isPulseHighlight: pulseHighlightRaw == option.rawValue
                ) {
                    withAnimation(LimiMotion.quick) {
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
    /// `Goal.rawValue` set while AI pulse is active.
    var pulseHighlightRaws: Set<String>
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("What should Limi help with?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Select one or more — you can explain in detail and Limi can help match goals.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Goal.allCases) { goal in
                        SelectableRow(
                            title: goal.rawValue,
                            icon: goal.icon,
                            isSelected: selectedGoals.contains(goal),
                            isPulseHighlight: pulseHighlightRaws.contains(goal.rawValue)
                        ) {
                            withAnimation(LimiMotion.quick) {
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
                title: "Continue",
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
    var isLoading: Bool = false
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
                .animation(LimiMotion.appear.delay(0.1), value: appeared)

            Text("Bluetooth lets Limi scan for nearby lights and controllers so you can pair them securely. You can allow access now for setup, or skip and add devices later from settings.")
                .foregroundColor(.appTextSecondary)
                .font(.system(size: 15))
                .lineSpacing(5)
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)
                .animation(LimiMotion.appear.delay(0.2), value: appeared)

            Text("Only you can tap Allow or Skip — Limi’s voice can explain, but cannot choose for you.")
                .foregroundColor(.appTextMuted)
                .font(.system(size: 13))
                .lineSpacing(4)
                .padding(.top, 4)
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)
                .animation(LimiMotion.appear.delay(0.25), value: appeared)

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
                isLoading: isLoading,
                action: onAllow
            )
        }
        .padding(.bottom, 32)
        .onAppear {
            withAnimation(LimiMotion.appear) {
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
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        LimiPrimaryButton(title: title, isEnabled: isEnabled, isLoading: isLoading, action: action)
    }
}

struct SelectableRow: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    /// Short AI-driven emphasis: white border + slight scale, then returns to normal.
    var isPulseHighlight: Bool = false
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
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isPulseHighlight ? 0.92 : 0), lineWidth: isPulseHighlight ? 2.5 : 0)
                    .shadow(color: .white.opacity(isPulseHighlight ? 0.35 : 0), radius: isPulseHighlight ? 10 : 0)
            )
            .scaleEffect(isPulseHighlight ? 1.045 : 1.0)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isPulseHighlight)
        }
        .tapScale()
    }
}
