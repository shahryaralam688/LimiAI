//
//  CCTLEDPreviewView.swift
//  Limi
//
//  CCT (warm ↔ cool white) LED control screen built around the 3D
//  model preview: tap the model (or the power chip) to toggle the
//  light, right dial = brightness, left dial = colour temperature.
//  Controls auto-hide. Device commands ride the same LimiCommand /
//  ThrottledSender pipeline as CCTLEDView, with the same persistence
//  keys, so state carries over between the two screens.
//

import SwiftUI
import SwiftData
import RealityKit
import Combine

struct CCTLEDPreviewView: View {
    let bundledName: String
    let downloadId: String?
    let chennalMac: String?
    let chennelPosition: Int?
    /// When set, commands emit `virtual_light_control` instead of per-MAC transport.
    let virtualDeviceID: String?

    @Environment(\.modelContext) private var modelContext

    /// Slider-aware throttled sender (device transport or virtual socket).
    @StateObject private var commandRouter: CommandRouter
    /// Per-device transport state, used for the offline notice.
    @StateObject private var transportState: DeviceTransportState
    @ObservedObject private var transportMediumPrefs = TransportMediumPreferenceStore.shared

    // Dial values live in 0…1; device payloads (0…100) are derived on send.
    @State private var isOn = false
    @State private var brightness: Double = 0.85     // == led2Brightness / 100
    @State private var temperature: Double = 0.15    // == led1warmCold / 100
    @State private var isWarmCoolReversed = false
    @State private var didShowDeviceOfflineNotice = false

    // Dials stay hidden until the user asks for them, then auto-hide.
    @State private var controlsReady = false
    @State private var dialsVisible = false
    @State private var hideWorkItem: DispatchWorkItem?

    /// Drop-in replacement for `CCTLEDView(chennalMac:chennelPosition:)`.
    /// `bundledName` defaults from Socket.IO `pendantTypes` → art.scnassets pendant USDZ
    /// (UNKNOWN → `ball_Chrome_pendant`, never the old mount1 default).
    init(chennalMac: String?, chennelPosition: Int?, bundledName: String? = nil) {
        self.virtualDeviceID = nil
        self.chennalMac = chennalMac
        self.chennelPosition = chennelPosition
        self.bundledName = bundledName ?? PendantModelCatalog.bundledName(forDeviceId: chennalMac)
        self.downloadId = chennalMac.flatMap { DeviceDownloadStore.shared.get(forMac: $0) }
        let id = LimiDeviceNaming.normalizedHardwareId(chennalMac ?? "unknown")
        _commandRouter = StateObject(wrappedValue: CommandRouter(deviceId: id, virtualDeviceId: nil))
        _transportState = StateObject(wrappedValue: DeviceTransportRegistry.shared.state(for: id))
    }

    /// Virtual master hub All tab — `VirtualHub3DModel` only, never a member pendant.
    init(virtualDeviceID: String, bundledName: String? = nil) {
        self.virtualDeviceID = virtualDeviceID
        self.chennalMac = nil
        self.chennelPosition = 1
        self.bundledName = bundledName ?? VirtualHub3DModel.bundledName
        self.downloadId = nil
        _commandRouter = StateObject(wrappedValue: CommandRouter(deviceId: nil, virtualDeviceId: virtualDeviceID))
        _transportState = StateObject(wrappedValue: DeviceTransportRegistry.shared.state(for: "VIRTUAL"))
    }

    /// Preview / demo init without a device.
    init(bundledName: String, downloadId: String? = nil) {
        self.virtualDeviceID = nil
        self.bundledName = bundledName
        self.downloadId = downloadId
        self.chennalMac = nil
        self.chennelPosition = nil
        _commandRouter = StateObject(wrappedValue: CommandRouter(deviceId: "unknown", virtualDeviceId: nil))
        _transportState = StateObject(wrappedValue: DeviceTransportRegistry.shared.state(for: "UNKNOWN"))
    }

    private var brightnessAccent: Color {
        Color(red: 1.0, green: 0.93, blue: 0.78)
    }

    /// Temperature the on-screen light shows: follows the dial, flipped
    /// when the user reverses the warm/cool direction. Mirrors the old
    /// CCT slider, whose gradient flips while the wire mapping stays put
    /// (the reverse option exists to compensate for swapped ww/cw wiring).
    private var visualTemperature: Double {
        isWarmCoolReversed ? 1 - temperature : temperature
    }

    // Dial accent shifts between amber and cool blue-white with the value.
    private var temperatureAccent: Color {
        let t = visualTemperature
        return Color(red: 1.0 + (0.75 - 1.0) * t,
                     green: 0.88 + (0.87 - 0.88) * t,
                     blue: 0.68 + (1.0 - 0.68) * t)
    }

    private var topTemperatureLabel: String { isWarmCoolReversed ? "Warm" : "Cool" }
    private var bottomTemperatureLabel: String { isWarmCoolReversed ? "Cool" : "Warm" }

    var body: some View {
        CCTLEDPreviewContainer(
            bundledName: bundledName,
            downloadId: downloadId,
            brightness: Float(brightness),
            temperature: Float(visualTemperature),
            lightOn: isOn,
            onScreenTap: { showDials() },
            onLightToggle: { on in
                isOn = on
                sendLampState()
                persistUIState()
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if controlsReady && dialsVisible {
                statusHeader
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            if controlsReady {
                if dialsVisible {
                    CrownDial(
                        value: $brightness,
                        accent: brightnessAccent,
                        title: "Brightness",
                        label: { "\(Int(($0 * 100).rounded()))" },
                        onActivity: { scheduleAutoHide() },
                        onEditingChanged: { editing in
                            if !editing { commandRouter.flush() }
                        }
                    )
                    .disabled(!isOn)
                    .opacity(isOn ? 1 : 0.4)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    DialEdgeHandle(mirrored: false, accent: brightnessAccent) {
                        showDials()
                    }
                    .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .leading) {
            if controlsReady {
                if dialsVisible {
                    VStack(spacing: 12) {
                        CrownDial(
                            value: $temperature,
                            accent: temperatureAccent,
                            mirrored: true,
                            title: "Temperature",
                            endLabels: (top: topTemperatureLabel, bottom: bottomTemperatureLabel),
                            onActivity: { scheduleAutoHide() },
                            onEditingChanged: { editing in
                                if !editing { commandRouter.flush() }
                            }
                        )
                        .disabled(!isOn)
                        .opacity(isOn ? 1 : 0.4)

                        reverseButton
                    }
                    .padding(.leading, 16)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    DialEdgeHandle(mirrored: true, accent: temperatureAccent) {
                        showDials()
                    }
                    .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if controlsReady && dialsVisible && !isOn {
                Text("Tap the lamp to turn it on")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .limiScreenBackground()
        .onAppear {
            if virtualDeviceID == nil, let mac = chennalMac {
                let key = LimiDeviceNaming.normalizedHardwareId(mac)
                LightControllingSocket.shared.connect()
                _ = DeviceTransportRegistry.shared.state(for: key)
                DevicePresenceCoordinator.shared.requestRefresh(
                    deviceIds: [key],
                    reason: .homeAppear,
                    force: true
                )
            }
            // Only the model during the entrance; the edge handles fade
            // in once it has settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.7)) {
                    controlsReady = true
                }
            }
        }
        .task(id: warmCoolPreferenceStorageKey) {
            loadWarmCoolPreference()
        }
        .task(id: persistedStateStorageKey) {
            loadPersistedUIState()
        }
        .onChange(of: brightness) { _, _ in
            if isOn { sendBrightness() }
            persistUIState()
        }
        .onChange(of: temperature) { _, _ in
            if isOn { sendColor() }
            persistUIState()
        }
        .modifier(CCTDeviceAvailabilityModifier(
            virtualDeviceID: virtualDeviceID,
            transportState: transportState,
            didShowOfflineNotice: $didShowDeviceOfflineNotice
        ))
    }

    // MARK: - Header (power chip + transport path)

    /// Small pill at the top: shows and toggles the lamp state, with the
    /// effective control path (MQTT / WebSocket / BLE) underneath.
    private var statusHeader: some View {
        VStack(spacing: 6) {
            Button {
                togglePower()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isOn ? Color(red: 0.55, green: 0.95, blue: 0.6) : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .shadow(color: isOn ? Color.green.opacity(0.8) : .clear, radius: 4)
                    Text(isOn ? "Light On" : "Light Off")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            if virtualDeviceID != nil {
                Text("Virtual · Cloud")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
            } else if chennalMac != nil {
                DeviceControlPathStatusView(display: pathDisplay)
            }
        }
        .padding(.top, 8)
    }

    /// Same reverse control as CCTLEDView's menu — swaps which end of
    /// the dial is warm and which is cool.
    private var reverseButton: some View {
        Menu {
            Button {
                updateWarmCoolDirection(isReversed: false)
            } label: {
                if isWarmCoolReversed {
                    Text("Warm to Cool")
                } else {
                    Label("Warm to Cool", systemImage: "checkmark")
                }
            }

            Button {
                updateWarmCoolDirection(isReversed: true)
            } label: {
                if isWarmCoolReversed {
                    Label("Cool to Warm", systemImage: "checkmark")
                } else {
                    Text("Cool to Warm")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down.circle")
                Text("Reverse")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
    }

    private func togglePower() {
        isOn.toggle()
        sendLampState()
        persistUIState()
        scheduleAutoHide()
    }

    private func showDials() {
        guard controlsReady else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            dialsVisible = true
        }
        scheduleAutoHide()
    }

    /// (Re)starts the inactivity countdown — every interaction with a
    /// dial keeps them on screen a little longer.
    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                dialsVisible = false
            }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
    }

    // MARK: - Device senders (same pipeline as CCTLEDView)

    /// Channel position (1-based). Single-channel devices use 1.
    private var channel: Int { chennelPosition ?? 1 }

    private func warmCoolLevels(for sliderValue: Double) -> (cool: Int, warm: Int) {
        let clampedValue = min(max(sliderValue, 0), 100)

        if clampedValue == 50 {
            return (cool: 100, warm: 100)
        } else if clampedValue < 50 {
            let progressToWarm = (50 - clampedValue) / 50.0
            let coolLevel = Int((1.0 - progressToWarm) * 100.0)
            return (cool: max(0, min(100, coolLevel)), warm: 100)
        } else {
            let progressToCool = (clampedValue - 50) / 50.0
            let warmLevel = Int((1.0 - progressToCool) * 100.0)
            return (cool: 100, warm: max(0, min(100, warmLevel)))
        }
    }

    /// Build a `.cct` LimiCommand from the current UI state.
    private func currentCCTCommand(brightness: Int? = nil) -> LimiCommand {
        let levels = warmCoolLevels(for: temperature * 100)
        let bri = brightness ?? Int(min(max((self.brightness * 100).rounded(), 0), 100))
        return .cct(channel: channel, brightness: bri, ww: levels.warm, cw: levels.cool)
    }

    /// Temperature dial drag — coalesce through ThrottledSender.
    private func sendColor() {
        let command = currentCCTCommand()
        commandRouter.update(command)
    }

    /// Brightness dial drag — throttled, final value flushed on release.
    private func sendBrightness() {
        commandRouter.update(currentCCTCommand())
    }

    private func sendLampState() {
        if isOn {
            // Restore last brightness/colour by sending a fresh CCT frame.
            let command = currentCCTCommand()
            commandRouter.sendOneShot(command)
        } else {
            // Spec-compliant power-off; firmware preserves last colour state.
            let command: LimiCommand = .power(channel: channel, on: false)
            commandRouter.sendOneShot(command)
        }
    }

    // MARK: - Persistence (same keys as CCTLEDView so state carries over)

    private var warmCoolPreferenceDeviceID: String? {
        guard let rawDeviceID = chennalMac?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDeviceID.isEmpty else {
            return nil
        }
        return rawDeviceID
    }

    private var warmCoolPreferenceChannelPosition: Int {
        chennelPosition ?? 1
    }

    private var warmCoolPreferenceStorageKey: String {
        if let virtualDeviceID {
            return "virtual-\(virtualDeviceID)"
        }
        return "\(warmCoolPreferenceDeviceID ?? "unknown")-\(warmCoolPreferenceChannelPosition)"
    }

    private var persistedStateStorageKey: String { warmCoolPreferenceStorageKey }

    private var warmColdStorageKey: String { "cct-warm-cold-\(persistedStateStorageKey)" }
    private var brightnessStorageKey: String { "cct-brightness-\(persistedStateStorageKey)" }
    private var lampStateStorageKey: String { "cct-lamp-state-\(persistedStateStorageKey)" }

    /// Shows effective control path (manual override or firmware auto).
    private var pathDisplay: DeviceControlPathDisplay {
        let normalized = chennalMac?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let id = (normalized.isEmpty ? "unknown" : normalized).uppercased()
        return DeviceControlPathDisplay(deviceId: id, preference: transportMediumPrefs.preference)
    }

    private func loadPersistedUIState() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: warmColdStorageKey) != nil {
            temperature = min(max(defaults.double(forKey: warmColdStorageKey) / 100.0, 0), 1)
        }

        if defaults.object(forKey: brightnessStorageKey) != nil {
            brightness = min(max(defaults.double(forKey: brightnessStorageKey) / 100.0, 0), 1)
        }

        if defaults.object(forKey: lampStateStorageKey) != nil {
            isOn = defaults.bool(forKey: lampStateStorageKey)
        }
    }

    private func persistUIState() {
        let defaults = UserDefaults.standard
        defaults.set(temperature * 100, forKey: warmColdStorageKey)
        defaults.set(brightness * 100, forKey: brightnessStorageKey)
        defaults.set(isOn, forKey: lampStateStorageKey)
    }

    // MARK: - Warm/Cool direction preference (SwiftData, same as CCTLEDView)

    private func updateWarmCoolDirection(isReversed: Bool) {
        guard isWarmCoolReversed != isReversed else { return }
        isWarmCoolReversed = isReversed
        persistWarmCoolPreference()
        scheduleAutoHide()
    }

    private func loadWarmCoolPreference() {
        guard let deviceID = warmCoolPreferenceDeviceID else {
            isWarmCoolReversed = false
            return
        }

        let channelPosition = warmCoolPreferenceChannelPosition
        let descriptor = FetchDescriptor<WarmCoolSliderPreference>(
            predicate: #Predicate { preference in
                preference.deviceID == deviceID && preference.channelPosition == channelPosition
            }
        )

        do {
            let preference = try modelContext.fetch(descriptor).first
            isWarmCoolReversed = preference?.isReversed ?? false
        } catch {
            isWarmCoolReversed = false
        }
    }

    private func persistWarmCoolPreference() {
        guard let deviceID = warmCoolPreferenceDeviceID else { return }

        let channelPosition = warmCoolPreferenceChannelPosition
        let descriptor = FetchDescriptor<WarmCoolSliderPreference>(
            predicate: #Predicate { preference in
                preference.deviceID == deviceID && preference.channelPosition == channelPosition
            }
        )

        do {
            let storedPreference = try modelContext.fetch(descriptor).first

            if let storedPreference {
                storedPreference.isReversed = isWarmCoolReversed
            } else {
                let preference = WarmCoolSliderPreference(
                    deviceID: deviceID,
                    channelPosition: channelPosition,
                    isReversed: isWarmCoolReversed
                )
                modelContext.insert(preference)
            }

            try modelContext.save()
        } catch { /* ignored */ }
    }
}

// MARK: - Edge handle

/// Slim capsule pinned to the screen border while a dial is hidden —
/// a quiet hint that tapping brings the control back.
/// Shared by the CCT and RGB LED control screens.
struct DialEdgeHandle: View {
    let mirrored: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(accent.opacity(0.55))
                .frame(width: 4, height: 56)
                .shadow(color: accent.opacity(0.4), radius: 6)
                .padding(mirrored ? .leading : .trailing, 6)
                .contentShape(Rectangle().inset(by: -20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Crown dial

/// Watch-crown style vertical dial: a tick ruler that scrolls under a
/// fixed center marker, with the current value shown in a circular badge
/// beside it. Every tick crossed gives a crown-like haptic detent.
/// Shared by the CCT and RGB LED control screens.
struct CrownDial: View {
    @Binding var value: Double
    let accent: Color
    var mirrored: Bool = false
    /// Small caption above the dial ("Brightness", "Temperature", "Color").
    var title: String? = nil
    /// Labels for the two ends of the ruler (e.g. Cool on top, Warm below).
    var endLabels: (top: String, bottom: String)? = nil
    /// Badge text; when nil the badge shows the accent color itself
    /// (used by the temperature/color dials as a live color preview).
    var label: ((Double) -> String)? = nil
    var onActivity: (() -> Void)? = nil
    /// Reports drag begin/end — hosts flush their throttled sender on release.
    var onEditingChanged: ((Bool) -> Void)? = nil

    // One tick = 2.5% — 40 detents across the full range.
    private let tickStep: Double = 0.025
    private let tickSpacing: CGFloat = 8
    private let dialHeight: CGFloat = 260
    private let dialWidth: CGFloat = 30

    @State private var dragStartValue: Double?
    @State private var isDragging = false

    private var detentIndex: Int { Int((value / tickStep).rounded()) }

    var body: some View {
        VStack(spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .kerning(0.4)
            }

            if let endLabels {
                endLabelText(endLabels.top)
            }

            HStack(spacing: 12) {
                if mirrored {
                    ruler
                    numberBadge
                } else {
                    numberBadge
                    ruler
                }
            }

            if let endLabels {
                endLabelText(endLabels.bottom)
            }
        }
        .contentShape(Rectangle().inset(by: -20))
        .gesture(dragGesture)
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDragging)
        .onChange(of: detentIndex) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func endLabelText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.4))
    }

    // Circular badge centered on the dial: shows the value as text, or —
    // when no label is given — the current color itself.
    private var numberBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
            Circle()
                .strokeBorder(accent.opacity(isDragging ? 0.7 : 0.35), lineWidth: 1)

            if let label {
                Text(label(value))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 5)
                    .contentTransition(.numericText(value: value))
                    .animation(.snappy(duration: 0.2), value: label(value))
            } else {
                // Live color preview — fills as the dial moves.
                Circle()
                    .fill(accent)
                    .frame(width: 24, height: 24)
                    .shadow(color: accent.opacity(0.9), radius: isDragging ? 8 : 4)
            }
        }
        .frame(width: 44, height: 44)
        .shadow(color: accent.opacity(isDragging ? 0.35 : 0), radius: 10)
    }

    // Scrolling tick ruler; the accent center marker is the fixed cursor.
    private var ruler: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            let pxPerValue = tickSpacing / CGFloat(tickStep)
            let tickCount = Int((1.0 / tickStep).rounded())

            for index in 0...tickCount {
                let tickValue = Double(index) * tickStep
                let y = centerY - CGFloat(tickValue - value) * pxPerValue
                guard y >= 0, y <= size.height else { continue }

                let isMajor = index % 4 == 0   // every 10%
                // Ticks dissolve toward the ruler's ends.
                let edgeFade = 1 - abs(y - centerY) / (size.height / 2)
                let opacity = Double(0.1 + 0.45 * edgeFade)
                let width: CGFloat = isMajor ? 22 : 13

                let rect = CGRect(x: mirrored ? 0 : size.width - width,
                                  y: y - 0.75, width: width, height: 1.5)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.75),
                             with: .color(.white.opacity(opacity)))
            }

            // Fixed center marker — the dial's cursor.
            let marker = CGRect(x: mirrored ? 0 : size.width - 28,
                                y: centerY - 1, width: 28, height: 2)
            context.fill(Path(roundedRect: marker, cornerRadius: 1),
                         with: .color(accent))
        }
        .frame(width: dialWidth, height: dialHeight)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if dragStartValue == nil {
                    dragStartValue = value
                    onEditingChanged?(true)
                }
                isDragging = true
                let pxPerValue = tickSpacing / CGFloat(tickStep)
                let delta = Double(-gesture.translation.height / pxPerValue)
                value = min(max((dragStartValue ?? value) + delta, 0), 1)
                onActivity?()
            }
            .onEnded { _ in
                dragStartValue = nil
                isDragging = false
                onEditingChanged?(false)
                onActivity?()
            }
    }
}

struct CCTLEDPreviewContainer: UIViewRepresentable {
    let bundledName: String
    let downloadId: String?
    let brightness: Float
    let temperature: Float
    /// Lamp state owned by SwiftUI, so the power chip and persisted
    /// state drive the 3D glow too (not just taps on the model).
    var lightOn: Bool = false
    var onScreenTap: (() -> Void)? = nil
    var onLightToggle: ((Bool) -> Void)? = nil

    // MARK: - Motion design constants

    /// Tuned for a calm, premium "materialize" feel: soft springs with a
    /// slight overshoot, then a barely-there idle drift so the model never
    /// looks frozen.
    fileprivate enum Motion {
        // Entrance
        static let startScale: Float = 0.75
        static let startYOffset: Float = -0.09            // gentle rise (~25pt on screen)
        static let startYaw: Float = -7 * .pi / 180       // settles in from a slight turn
        static let fadeDuration: TimeInterval = 1.3

        // Springs (stiffness + damping ratio). ζ < 1 gives the 2–3% overshoot.
        static let scaleStiffness: Float = 55
        static let scaleDamping: Float = 0.78
        static let riseStiffness: Float = 45
        static let riseDamping: Float = 0.9
        static let yawStiffness: Float = 40
        static let yawDamping: Float = 0.85

        // Reveal lighting
        static let sweepStart: TimeInterval = 0.25
        static let sweepDuration: TimeInterval = 1.1
        static let sweepPeakIntensity: Float = 35_000     // lumens, kept subtle
        static let rimDuration: TimeInterval = 1.6
        static let rimPeakIntensity: Float = 1_200        // lux

        // Idle
        static let idleRampStart: TimeInterval = 1.9
        static let idleRampDuration: TimeInterval = 1.5
        static let breathingAmplitude: Float = 0.01       // 0.99 ↔ 1.01
        static let breathingPeriod: Float = 6.2
        static let floatAmplitude: Float = 0.02
        static let floatPeriod: Float = 4.7
        static let idleYawSpeed: Float = 0.35 * .pi / 180 // degrees per second

        // Tap-to-toggle glow (light "on" state)
        static let glowStiffness: Float = 45
        static let glowDamping: Float = 0.88              // slight surge when switching on
        static let glowLightIntensity: Float = 45_000     // lumens when fully on
        static let glowShimmer: Float = 0.02              // living-light flicker, barely visible
        static let glowShimmerSpeed: Float = 2.1
        static let glowCoreOpacity: Float = 0.95          // bright pool directly under the lamp
        static let glowHaloOpacity: Float = 0.38          // wide soft spill around it
    }

    final class Coordinator {
        /// One layer of the light pool, with its tints at both ends of
        /// the temperature range.
        struct GlowQuad {
            let entity: Entity
            let texture: TextureResource?
            let maxOpacity: Float
            let warmTint: UIColor
            let coolTint: UIColor
        }

        weak var arView: ARView?
        var rigEntity: Entity?
        var sweepLight: PointLight?
        var rimLight: DirectionalLight?
        var glowQuads: [GlowQuad] = []
        var glowLight: PointLight?
        var warmLightColor = UIColor(red: 1.0, green: 0.82, blue: 0.55, alpha: 1)
        var coolLightColor = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1)
        var updateSubscription: Cancellable?

        var baseScale: Float = 1
        var basePosition: SIMD3<Float> = .zero

        // MARK: Glow toggle state

        var brightnessTarget: Float = 0.85
        private var brightnessLevel: Float = 0.85
        var temperatureTarget: Float = 0.15
        private var temperatureLevel: Float = 0.15
        private var appliedTemperature: Float = -1
        var glowTarget: Float = 0
        private var glowLevel: Float = 0
        private var glowVelocity: Float = 0

        var onScreenTap: (() -> Void)?
        var onLightToggle: ((Bool) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = gesture.location(in: arView)

            // Any tap surfaces the control dials in SwiftUI.
            onScreenTap?()

            // Prefer a precise hit-test; fall back to "near the model on
            // screen" because collision shapes on some USDZ hierarchies
            // don't cover every part of the mesh.
            var didHitModel = arView.entity(at: location) != nil
            if !didHitModel, let projected = arView.project(basePosition) {
                let dx = location.x - projected.x
                let dy = location.y - projected.y
                let radius = min(arView.bounds.width, arView.bounds.height) * 0.35
                didHitModel = (dx * dx + dy * dy) < radius * radius
            }
            guard didHitModel else { return }

            glowTarget = glowTarget > 0.5 ? 0 : 1
            onLightToggle?(glowTarget > 0.5)
        }

        // MARK: Animation state

        private var elapsed: TimeInterval = 0
        private var fadeComplete = false
        private var idleClock: Float = 0
        private var idleYawAngle: Float = 0

        private var scaleValue = Motion.startScale
        private var scaleVelocity: Float = 0
        private var riseValue = Motion.startYOffset
        private var riseVelocity: Float = 0
        private var yawValue = Motion.startYaw
        private var yawVelocity: Float = 0

        // MARK: Per-frame update (runs at display refresh rate)

        func tick(deltaTime: TimeInterval) {
            guard let rig = rigEntity else { return }
            elapsed += deltaTime
            let dt = Float(min(deltaTime, 1.0 / 30.0))

            stepSpring(&scaleValue, &scaleVelocity, target: 1,
                       stiffness: Motion.scaleStiffness, dampingRatio: Motion.scaleDamping, dt: dt)
            stepSpring(&riseValue, &riseVelocity, target: 0,
                       stiffness: Motion.riseStiffness, dampingRatio: Motion.riseDamping, dt: dt)
            stepSpring(&yawValue, &yawVelocity, target: 0,
                       stiffness: Motion.yawStiffness, dampingRatio: Motion.yawDamping, dt: dt)

            // Idle motion fades in only after the entrance has settled,
            // so there is never a visible hand-off between the two.
            let idleAmount = smoothstep(Float((elapsed - Motion.idleRampStart) / Motion.idleRampDuration))
            if idleAmount > 0 {
                idleClock += dt
                idleYawAngle += Motion.idleYawSpeed * dt * idleAmount
            }
            let breathing = 1 + Motion.breathingAmplitude
                * sin(idleClock * 2 * .pi / Motion.breathingPeriod) * idleAmount
            let floating = Motion.floatAmplitude
                * sin(idleClock * 2 * .pi / Motion.floatPeriod) * idleAmount

            rig.scale = SIMD3(repeating: baseScale * scaleValue * breathing)
            rig.position = basePosition + SIMD3<Float>(0, riseValue + floating, 0)
            rig.orientation = simd_quatf(angle: yawValue + idleYawAngle, axis: SIMD3<Float>(0, 1, 0))

            updateFade(rig: rig)
            updateRevealLights()
            updateGlow(dt: dt)
        }

        private func updateGlow(dt: Float) {
            stepSpring(&glowLevel, &glowVelocity, target: glowTarget,
                       stiffness: Motion.glowStiffness, dampingRatio: Motion.glowDamping, dt: dt)
            let level = min(max(glowLevel, 0), 1)

            // Smoothly follow both dials so changes glide instead of jump.
            brightnessLevel += (brightnessTarget - brightnessLevel) * min(dt * 10, 1)
            temperatureLevel += (temperatureTarget - temperatureLevel) * min(dt * 8, 1)

            // A barely-perceptible shimmer keeps the light feeling alive
            // instead of frozen once it is on.
            let shimmer = 1 + Motion.glowShimmer * sin(idleClock * Motion.glowShimmerSpeed) * level

            // The light itself uses the unclamped spring value, so the
            // slight overshoot reads as a real bulb's turn-on surge.
            glowLight?.light.intensity = Motion.glowLightIntensity
                * max(glowLevel, 0) * shimmer * brightnessLevel

            // Like a real lamp: the light pool grows with the dimmer.
            let poolScale = 0.85 + 0.15 * brightnessLevel
            for quad in glowQuads {
                let opacity = min(max(quad.maxOpacity * level * shimmer * brightnessLevel, 0), 1)
                quad.entity.components.set(OpacityComponent(opacity: opacity))
                quad.entity.scale = SIMD3<Float>(repeating: poolScale)
            }

            applyTemperatureIfNeeded()
        }

        /// Re-tints the glow layers and light between warm and cool white.
        /// Materials are only rebuilt when the value actually moves.
        private func applyTemperatureIfNeeded() {
            guard abs(temperatureLevel - appliedTemperature) > 0.002 else { return }
            appliedTemperature = temperatureLevel

            for quad in glowQuads {
                let tint = Self.blend(quad.warmTint, quad.coolTint, temperatureLevel)
                let material = CCTLEDPreviewContainer.glowMaterial(tint: tint, texture: quad.texture)
                if var model = quad.entity.components[ModelComponent.self] {
                    model.materials = [material]
                    quad.entity.components.set(model)
                }
            }

            glowLight?.light.color = Self.blend(warmLightColor, coolLightColor, temperatureLevel)
        }

        private static func blend(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            let t = CGFloat(min(max(t, 0), 1))
            return UIColor(red: ar + (br - ar) * t,
                           green: ag + (bg - ag) * t,
                           blue: ab + (bb - ab) * t,
                           alpha: aa + (ba - aa) * t)
        }

        private func updateFade(rig: Entity) {
            guard !fadeComplete else { return }
            let progress = Float(min(elapsed / Motion.fadeDuration, 1))
            let eased = 1 - pow(1 - progress, 3)   // ease-out cubic
            if progress >= 1 {
                rig.components.remove(OpacityComponent.self)
                fadeComplete = true
            } else {
                rig.components.set(OpacityComponent(opacity: eased))
            }
        }

        private func updateRevealLights() {
            if let sweep = sweepLight {
                let progress = Float((elapsed - Motion.sweepStart) / Motion.sweepDuration)
                if progress >= 1 {
                    sweep.removeFromParent()
                    sweepLight = nil
                } else if progress > 0 {
                    // Light travels left → right across the surface while its
                    // intensity rises and falls, reading as a soft sheen.
                    sweep.position.x = basePosition.x - 1.8 + 3.6 * smoothstep(progress)
                    sweep.light.intensity = Motion.sweepPeakIntensity * sin(progress * .pi)
                }
            }

            if let rim = rimLight {
                let progress = Float(min(elapsed / Motion.rimDuration, 1))
                if progress >= 1 {
                    rim.removeFromParent()
                    rimLight = nil
                } else {
                    rim.light.intensity = Motion.rimPeakIntensity * (1 - progress * progress)
                }
            }
        }

        // Semi-implicit Euler spring integrator — real physics, frame-rate independent.
        private func stepSpring(_ value: inout Float, _ velocity: inout Float,
                                target: Float, stiffness: Float, dampingRatio: Float, dt: Float) {
            let damping = 2 * sqrt(stiffness) * dampingRatio
            let acceleration = -stiffness * (value - target) - damping * velocity
            velocity += acceleration * dt
            value += velocity * dt
        }

        private func smoothstep(_ x: Float) -> Float {
            let t = min(max(x, 0), 1)
            return t * t * (3 - 2 * t)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.cameraMode = .nonAR
        arView.environment.background = .color(UIColor(Color.appCanvasPrimary))

        guard let loadedEntity = ConfiguratorModelStore.loadPreviewEntity(
            downloadId: downloadId,
            bundledName: bundledName
        ) else {
            return arView
        }

        // Fix the upside-down orientation first, THEN recenter using the
        // rotated bounds. Doing it in the opposite order leaves the visual
        // center far from the origin, which puts the model outside the
        // fixed camera's frame.
        loadedEntity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        let bounds = loadedEntity.visualBounds(relativeTo: nil)
        loadedEntity.position -= bounds.center

        // Collision shapes are needed so taps on the model can be hit-tested.
        let modelEntity = ModelEntity()
        modelEntity.addChild(loadedEntity)
        modelEntity.generateCollisionShapes(recursive: true)

        let size = bounds.extents
        let largestDimension = max(size.x, max(size.y, size.z))
        let targetHeight: Float = 1.2
        let uniformScale = largestDimension > 0 ? targetHeight / largestDimension : 1

        let basePosition = SIMD3<Float>(0, 2.5, -0.5)
        let rig = Entity()
        rig.addChild(modelEntity)

        // Initial state: fully transparent, slightly smaller, lower and turned —
        // the model materializes instead of popping in.
        rig.scale = SIMD3(repeating: uniformScale * Motion.startScale)
        rig.position = basePosition + SIMD3<Float>(0, Motion.startYOffset, 0)
        rig.orientation = simd_quatf(angle: Motion.startYaw, axis: SIMD3<Float>(0, 1, 0))
        rig.components.set(OpacityComponent(opacity: 0))

        let anchor = AnchorEntity()
        anchor.addChild(rig)
        arView.scene.addAnchor(anchor)

        // Fixed camera so the reveal never shifts the framing.
        // The camera aims below the model's center, which places the
        // model in the upper part of the screen.
        let camera = PerspectiveCamera()
        let cameraTarget = basePosition + SIMD3<Float>(0, -0.4, 0)
        let cameraPosition = cameraTarget + SIMD3<Float>(0, 0, 2.4)
        camera.look(at: cameraTarget, from: cameraPosition, relativeTo: nil)
        anchor.addChild(camera)

        // Reveal lighting: a travelling sheen plus a soft rim from behind,
        // both removed once the entrance finishes.
        let sweep = PointLight()
        sweep.light = PointLightComponent(color: .white, intensity: 0, attenuationRadius: 6)
        sweep.position = basePosition + SIMD3<Float>(-1.8, 0.4, 1.0)
        anchor.addChild(sweep)

        let rim = DirectionalLight()
        rim.light = DirectionalLightComponent(color: .white, intensity: Motion.rimPeakIntensity)
        rim.look(at: basePosition, from: basePosition + SIMD3<Float>(0, 2.5, -2.5), relativeTo: nil)
        anchor.addChild(rim)

        // Tap-to-toggle glow: a wide faint halo plus a bright core pool,
        // and a point light that brightens the model itself. Each layer
        // carries warm and cool tints; the temperature dial blends them.
        let warmCore = UIColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 1.0)
        let warmSpill = UIColor(red: 1.0, green: 0.82, blue: 0.55, alpha: 1.0)
        let coolCore = UIColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1.0)
        let coolSpill = UIColor(red: 0.75, green: 0.86, blue: 1.0, alpha: 1.0)

        let radialTexture = Self.makeRadialGradientTexture()

        let glowHalo = Self.makeGlowQuad(width: 2.3, height: 0.85, tint: warmSpill, texture: radialTexture)
        glowHalo.position = basePosition + SIMD3<Float>(0, -0.82, -0.03)

        let glowCore = Self.makeGlowQuad(width: 1.1, height: 0.36, tint: warmCore, texture: radialTexture)
        glowCore.position = basePosition + SIMD3<Float>(0, -0.80, 0)

        for glow in [glowHalo, glowCore] {
            glow.components.set(OpacityComponent(opacity: 0))
            anchor.addChild(glow)
        }

        let glowLight = PointLight()
        glowLight.light = PointLightComponent(color: warmSpill, intensity: 0, attenuationRadius: 4)
        glowLight.position = basePosition + SIMD3<Float>(0, -0.2, 0.3)
        anchor.addChild(glowLight)

        let coordinator = context.coordinator
        coordinator.arView = arView
        coordinator.onScreenTap = onScreenTap
        coordinator.onLightToggle = onLightToggle
        coordinator.brightnessTarget = brightness
        coordinator.temperatureTarget = temperature
        coordinator.glowTarget = lightOn ? 1 : 0
        coordinator.rigEntity = rig
        coordinator.glowQuads = [
            .init(entity: glowHalo, texture: radialTexture,
                  maxOpacity: Motion.glowHaloOpacity,
                  warmTint: warmSpill, coolTint: coolSpill),
            .init(entity: glowCore, texture: radialTexture,
                  maxOpacity: Motion.glowCoreOpacity,
                  warmTint: warmCore, coolTint: coolCore)
        ]
        coordinator.glowLight = glowLight
        coordinator.sweepLight = sweep
        coordinator.rimLight = rim
        coordinator.baseScale = uniformScale
        coordinator.basePosition = basePosition

        coordinator.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator] event in
            coordinator?.tick(deltaTime: event.deltaTime)
        }

        let tapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.brightnessTarget = brightness
        context.coordinator.temperatureTarget = temperature
        context.coordinator.glowTarget = lightOn ? 1 : 0
    }

    // MARK: - Glow layers

    /// Unlit transparent material for a glow layer. RealityKit ignores
    /// the color texture's alpha channel, so the falloff must live in an
    /// explicit grayscale opacity map. Also used by the coordinator when
    /// re-tinting layers as the temperature dial moves.
    static func glowMaterial(tint: UIColor, texture: TextureResource?) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: tint)
        if let texture {
            material.blending = .transparent(
                opacity: .init(scale: 1.0, texture: .init(texture))
            )
        } else {
            material.blending = .transparent(opacity: 0.4)
        }
        return material
    }

    /// A camera-facing quad rendered with `glowMaterial`.
    private static func makeGlowQuad(width: Float, height: Float,
                                     tint: UIColor, texture: TextureResource?) -> Entity {
        let entity = Entity()
        let mesh = MeshResource.generatePlane(width: width, height: height)
        entity.components.set(ModelComponent(
            mesh: mesh,
            materials: [glowMaterial(tint: tint, texture: texture)]
        ))
        return entity
    }

    /// Soft radial falloff used by the light pool layers. Shared with the
    /// RGB control screen.
    static func makeRadialGradientTexture() -> TextureResource? {
        let size = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))

            let colors = [UIColor.white.cgColor, UIColor.black.cgColor]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else { return }
            let center = CGPoint(x: size / 2, y: size / 2)
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: CGFloat(size) / 2,
                options: []
            )
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(
            image: cgImage,
            options: .init(semantic: .raw)
        )
    }

}

// MARK: - Virtual vs per-device availability

private struct CCTDeviceAvailabilityModifier: ViewModifier {
    let virtualDeviceID: String?
    @ObservedObject var transportState: DeviceTransportState
    @Binding var didShowOfflineNotice: Bool

    func body(content: Content) -> some View {
        if virtualDeviceID != nil {
            content
        } else {
            content.deviceControlAvailability(
                transportState: transportState,
                didShowOfflineNotice: $didShowOfflineNotice
            )
        }
    }
}

#Preview {
    CCTLEDPreviewView(chennalMac: "80b54ee8b228", chennelPosition: 2)
        .modelContainer(for: WarmCoolSliderPreference.self, inMemory: true)
}
