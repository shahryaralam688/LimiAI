//
//  RGBLEDPreviewView.swift
//  Limi
//
//  RGB LED control screen built around the 3D model preview — the
//  premium counterpart of WLEDView's controls: tap the model (or the
//  power chip) to toggle power, right dial = brightness, left dial =
//  color (hue), plus an effects panel with speed/intensity. Commands
//  ride the same LimiCommand / ThrottledSender pipeline as WLEDView,
//  with the same persistence keys so state carries over.
//

import SwiftUI
import RealityKit
import Combine

struct RGBLEDPreviewView: View {
    let bundledName: String
    let downloadId: String?
    let chennalMac: String?
    let chennelPosition: Int?

    /// Slider-aware throttled sender that talks to LimiTransport.
    @StateObject private var throttle: ThrottledSender
    /// Per-device transport state, used for the offline notice.
    @StateObject private var transportState: DeviceTransportState
    @ObservedObject private var transportMediumPrefs = TransportMediumPreferenceStore.shared

    // Light state
    @State private var isOn = false
    @State private var brightness: Double = 0.85
    @State private var hue: Double = 0.08          // 0…1 around the color wheel
    @State private var selectedEffect: Int?
    @State private var patternSpeed: Double = 50
    @State private var patternIntensity: Double = 50
    @State private var didShowDeviceOfflineNotice = false

    // Controls stay hidden until the user asks for them, then auto-hide.
    @State private var controlsReady = false
    @State private var dialsVisible = false
    @State private var hideWorkItem: DispatchWorkItem?

    /// Drop-in replacement for `WLEDView(chennalMac:chennelPosition:)`.
    /// `bundledName` defaults from Socket.IO `pendantTypes` → art.scnassets pendant USDZ
    /// (UNKNOWN → `ball_Chrome_pendant`, never the old mount1 default).
    init(chennalMac: String?, chennelPosition: Int?, bundledName: String? = nil) {
        self.chennalMac = chennalMac
        self.chennelPosition = chennelPosition
        self.bundledName = bundledName ?? PendantModelCatalog.bundledName(forDeviceId: chennalMac)
        self.downloadId = chennalMac.flatMap { DeviceDownloadStore.shared.get(forMac: $0) }
        let id = (chennalMac ?? "unknown").uppercased()
        _throttle = StateObject(wrappedValue: ThrottledSender(deviceId: id))
        _transportState = StateObject(wrappedValue: DeviceTransportRegistry.shared.state(for: id))
    }

    /// Preview / demo init without a device.
    init(bundledName: String, downloadId: String? = nil) {
        self.bundledName = bundledName
        self.downloadId = downloadId
        self.chennalMac = nil
        self.chennelPosition = nil
        _throttle = StateObject(wrappedValue: ThrottledSender(deviceId: "unknown"))
        _transportState = StateObject(wrappedValue: DeviceTransportRegistry.shared.state(for: "UNKNOWN"))
    }

    private var selectedColor: Color {
        Color(hue: hue, saturation: 1.0, brightness: 1.0)
    }

    private var brightnessAccent: Color {
        Color(red: 0.95, green: 0.95, blue: 0.95)
    }

    var body: some View {
        RGBLEDPreviewContainer(
            bundledName: bundledName,
            downloadId: downloadId,
            brightness: Float(brightness),
            colorHue: Float(hue),
            lightOn: isOn,
            onScreenTap: { showDials() },
            onLightToggle: { on in
                isOn = on
                sendPower(on)
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
                            if !editing { throttle.flush() }
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
                    CrownDial(
                        value: $hue,
                        accent: selectedColor,
                        mirrored: true,
                        title: "Color",
                        onActivity: { scheduleAutoHide() },
                        onEditingChanged: { editing in
                            if !editing { throttle.flush() }
                        }
                    )
                    .disabled(!isOn)
                    .opacity(isOn ? 1 : 0.4)
                    .padding(.leading, 16)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    DialEdgeHandle(mirrored: true, accent: selectedColor) {
                        showDials()
                    }
                    .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if controlsReady && dialsVisible {
                if isOn {
                    effectsPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Tap the lamp to turn it on")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
        .limiScreenBackground()
        .onAppear {
            // Only the model during the entrance; the edge handles fade
            // in once it has settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.7)) {
                    controlsReady = true
                }
            }
        }
        .task(id: persistedStateStorageKey) {
            loadPersistedUIState()
        }
        .onChange(of: brightness) { _, _ in
            if isOn { sendCurrentLight() }
            persistUIState()
        }
        .onChange(of: hue) { _, _ in
            if isOn { sendCurrentLight() }
            persistUIState()
        }
        .onChange(of: patternSpeed) { _, _ in
            guard isOn, selectedEffect != nil else { return }
            sendPattern()
        }
        .onChange(of: patternIntensity) { _, _ in
            guard isOn, selectedEffect != nil else { return }
            sendPattern()
        }
        .deviceControlAvailability(
            transportState: transportState,
            didShowOfflineNotice: $didShowDeviceOfflineNotice
        )
    }

    // MARK: - Header (power chip + transport path)

    /// Small pill at the top: shows and toggles the lamp state, with the
    /// effective control path (MQTT / WebSocket / BLE) underneath.
    private var statusHeader: some View {
        VStack(spacing: 6) {
            Button {
                isOn.toggle()
                sendPower(isOn)
                persistUIState()
                scheduleAutoHide()
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

            if chennalMac != nil {
                DeviceControlPathStatusView(display: pathDisplay)
            }
        }
        .padding(.top, 8)
    }

    /// Shows effective control path (manual override or firmware auto).
    private var pathDisplay: DeviceControlPathDisplay {
        let normalized = chennalMac?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let id = (normalized.isEmpty ? "unknown" : normalized).uppercased()
        return DeviceControlPathDisplay(deviceId: id, preference: transportMediumPrefs.preference)
    }

    // MARK: - Persistence (same keys as WLEDView so state carries over)

    private var persistedStateStorageKey: String {
        let normalizedDeviceID = chennalMac?.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceID = (normalizedDeviceID?.isEmpty == false ? normalizedDeviceID : nil) ?? "unknown"
        return "\(deviceID)-\(chennelPosition ?? 1)"
    }

    private var lampStateStorageKey: String { "rgb-lamp-state-\(persistedStateStorageKey)" }
    private var brightnessStorageKey: String { "rgb-brightness-\(persistedStateStorageKey)" }
    private var selectedColorHexStorageKey: String { "rgb-selected-color-\(persistedStateStorageKey)" }

    private func loadPersistedUIState() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: lampStateStorageKey) != nil {
            isOn = defaults.bool(forKey: lampStateStorageKey)
        }

        if defaults.object(forKey: brightnessStorageKey) != nil {
            // WLEDView stores brightness as 0…100.
            brightness = min(max(defaults.double(forKey: brightnessStorageKey) / 100.0, 0), 1)
        }

        if let storedHex = defaults.string(forKey: selectedColorHexStorageKey) {
            // WLEDView stores the color as a hex string; recover the hue.
            var extractedHue: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if UIColor(Color(hex: storedHex)).getHue(&extractedHue, saturation: &s, brightness: &b, alpha: &a) {
                hue = Double(extractedHue)
            }
        }
    }

    private func persistUIState() {
        let defaults = UserDefaults.standard
        defaults.set(isOn, forKey: lampStateStorageKey)
        defaults.set(brightness * 100, forKey: brightnessStorageKey)
        defaults.set(selectedColor.toHex(), forKey: selectedColorHexStorageKey)
    }

    // MARK: - Effects panel

    private var effectsPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Effects")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .kerning(0.4)
                Spacer()
            }
            .padding(.horizontal, 20)

            if selectedEffect != nil {
                patternSliders
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Self.effects, id: \.id) { effect in
                        effectChip(effect)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func effectChip(_ effect: (id: Int, name: String)) -> some View {
        let isSelected = selectedEffect == effect.id

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                // Deselect → back to solid color.
                selectedEffect = nil
                if isOn { sendCurrentLight() }
            } else {
                selectedEffect = effect.id
                if isOn { sendPattern() }
            }
            scheduleAutoHide()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: Self.effectIcon(for: effect.name))
                    .font(.system(size: 16, weight: .medium))
                Text(effect.name)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? selectedColor : Color.white.opacity(0.65))
            .frame(width: 64, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? selectedColor.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? selectedColor.opacity(0.7) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var patternSliders: some View {
        VStack(spacing: 10) {
            miniSlider(title: "Speed", value: $patternSpeed)
            miniSlider(title: "Intensity", value: $patternIntensity)
        }
        .padding(.horizontal, 20)
    }

    private func miniSlider(title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 52, alignment: .leading)

            Slider(value: value, in: 0...100) { editing in
                if !editing { throttle.flush() }
                scheduleAutoHide()
            }
            .tint(selectedColor)

            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Show / auto-hide

    private func showDials() {
        guard controlsReady else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            dialsVisible = true
        }
        scheduleAutoHide()
    }

    /// (Re)starts the inactivity countdown — every interaction with a
    /// control keeps them on screen a little longer.
    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                dialsVisible = false
            }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    // MARK: - Device commands (same pipeline as WLEDView)

    private var channel: Int { chennelPosition ?? 1 }

    private var currentRGB: (red: Int, green: Int, blue: Int) {
        let uiColor = UIColor(hue: CGFloat(hue), saturation: 1, brightness: 1, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func rgbCommand() -> LimiCommand {
        let rgb = currentRGB
        let bri = Int(min(max((brightness * 100).rounded(), 0), 100))
        return .rgb(channel: channel, brightness: bri,
                    red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Solid color when no effect is selected, otherwise the pattern
    /// re-sent with the current color.
    private func sendCurrentLight() {
        if selectedEffect != nil {
            sendPattern()
        } else {
            throttle.update(rgbCommand())
        }
    }

    private func sendPattern() {
        guard let effectId = selectedEffect else { return }
        let rgb = currentRGB
        // Map 0–100 UI sliders to 0–255 wire range expected by firmware.
        let command: LimiCommand = .pattern(
            channel: channel,
            id: effectId,
            speed: Int((patternSpeed / 100.0) * 255.0),
            intensity: Int((patternIntensity / 100.0) * 255.0),
            color: [rgb.red, rgb.green, rgb.blue]
        )
        throttle.update(command)
    }

    private func sendPower(_ on: Bool) {
        if on {
            throttle.sendOneShot(rgbCommand())
        } else {
            // Spec-compliant power-off; firmware preserves last RGB state.
            throttle.sendOneShot(.power(channel: channel, on: false))
        }
    }

    // MARK: - Effects catalog (mirrors WLEDView's firmware patterns)

    static let effects: [(id: Int, name: String)] = [
        (1, "Solid"), (2, "Pulse"), (3, "Rainbow"), (4, "Rainbow Cycle"),
        (5, "Fade"), (6, "Breathe"), (7, "Chase"), (8, "Sparkle"),
        (9, "Meteor"), (10, "Fire"), (11, "Cylon"), (12, "Rainbow Strobe"),
        (13, "Chase Rainbow"), (14, "Double Chase"), (15, "Wave"),
        (16, "Running Lights"), (17, "Rainbow Pulse"), (18, "Gradient"),
        (19, "Dots"), (20, "Fading Blocks"), (21, "Bouncing Ball"),
        (22, "Flashing"), (23, "Strobe"), (24, "Color Wipe"),
        (25, "Theater Chase"), (26, "Twinkle"), (27, "Rainbow Multi"),
        (28, "Alternating"), (29, "Random Flash"), (30, "Breathing Rainbow"),
        (31, "Segment Rainbow")
    ]

    static func effectIcon(for effectName: String) -> String {
        let name = effectName.lowercased()
        if name.contains("solid") || name.contains("static") {
            return "circle.fill"
        } else if name.contains("blink") || name.contains("strobe") || name.contains("flash") {
            return "bolt.fill"
        } else if name.contains("breath") || name.contains("fade") {
            return "lungs.fill"
        } else if name.contains("rainbow") {
            return "rainbow"
        } else if name.contains("chase") || name.contains("running") {
            return "arrow.right.circle.fill"
        } else if name.contains("twinkle") || name.contains("sparkle") {
            return "sparkles"
        } else if name.contains("fire") || name.contains("flame") {
            return "flame.fill"
        } else if name.contains("wave") || name.contains("ripple") {
            return "water.waves"
        } else if name.contains("meteor") || name.contains("comet") {
            return "star.fill"
        } else {
            return "waveform"
        }
    }
}

// MARK: - 3D container

struct RGBLEDPreviewContainer: UIViewRepresentable {
    let bundledName: String
    let downloadId: String?
    let brightness: Float
    let colorHue: Float
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
        /// One layer of the light pool; its tint is recomputed from the
        /// current hue whenever the color dial moves.
        struct GlowQuad {
            let entity: Entity
            let texture: TextureResource?
            let maxOpacity: Float
            /// Saturation of this layer's tint (the core pool is paler
            /// than the outer spill, like a real light).
            let saturation: CGFloat
        }

        weak var arView: ARView?
        var rigEntity: Entity?
        var sweepLight: PointLight?
        var rimLight: DirectionalLight?
        var glowQuads: [GlowQuad] = []
        var glowLight: PointLight?
        var updateSubscription: Cancellable?

        var baseScale: Float = 1
        var basePosition: SIMD3<Float> = .zero

        // MARK: Glow toggle state

        var brightnessTarget: Float = 0.85
        private var brightnessLevel: Float = 0.85
        var hueTarget: Float = 0.08
        private var hueLevel: Float = 0.08
        private var appliedHue: Float = -1
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

            // Hue is circular (0 and 1 are both red) — always take the
            // shortest path around the wheel.
            var hueDelta = hueTarget - hueLevel
            if hueDelta > 0.5 { hueDelta -= 1 }
            if hueDelta < -0.5 { hueDelta += 1 }
            hueLevel += hueDelta * min(dt * 8, 1)
            if hueLevel < 0 { hueLevel += 1 }
            if hueLevel > 1 { hueLevel -= 1 }

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

            applyHueIfNeeded()
        }

        /// Re-tints the glow layers and light to the selected RGB color.
        /// Materials are only rebuilt when the hue actually moves.
        private func applyHueIfNeeded() {
            guard abs(hueLevel - appliedHue) > 0.002 else { return }
            appliedHue = hueLevel

            for quad in glowQuads {
                let tint = UIColor(hue: CGFloat(hueLevel),
                                   saturation: quad.saturation,
                                   brightness: 1.0, alpha: 1.0)
                let material = RGBLEDPreviewContainer.glowMaterial(tint: tint, texture: quad.texture)
                if var model = quad.entity.components[ModelComponent.self] {
                    model.materials = [material]
                    quad.entity.components.set(model)
                }
            }

            glowLight?.light.color = UIColor(hue: CGFloat(hueLevel),
                                             saturation: 0.85,
                                             brightness: 1.0, alpha: 1.0)
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
        // and a point light that brightens the model itself. Layer tints
        // are recomputed from the hue dial.
        let initialHue = CGFloat(colorHue)
        let spillTint = UIColor(hue: initialHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        let coreTint = UIColor(hue: initialHue, saturation: 0.45, brightness: 1.0, alpha: 1.0)

        let radialTexture = CCTLEDPreviewContainer.makeRadialGradientTexture()

        let glowHalo = Self.makeGlowQuad(width: 2.3, height: 0.85, tint: spillTint, texture: radialTexture)
        glowHalo.position = basePosition + SIMD3<Float>(0, -0.82, -0.03)

        let glowCore = Self.makeGlowQuad(width: 1.1, height: 0.36, tint: coreTint, texture: radialTexture)
        glowCore.position = basePosition + SIMD3<Float>(0, -0.80, 0)

        for glow in [glowHalo, glowCore] {
            glow.components.set(OpacityComponent(opacity: 0))
            anchor.addChild(glow)
        }

        let glowLight = PointLight()
        glowLight.light = PointLightComponent(color: spillTint, intensity: 0, attenuationRadius: 4)
        glowLight.position = basePosition + SIMD3<Float>(0, -0.2, 0.3)
        anchor.addChild(glowLight)

        let coordinator = context.coordinator
        coordinator.arView = arView
        coordinator.onScreenTap = onScreenTap
        coordinator.onLightToggle = onLightToggle
        coordinator.brightnessTarget = brightness
        coordinator.hueTarget = colorHue
        coordinator.glowTarget = lightOn ? 1 : 0
        coordinator.rigEntity = rig
        coordinator.glowQuads = [
            .init(entity: glowHalo, texture: radialTexture,
                  maxOpacity: Motion.glowHaloOpacity, saturation: 1.0),
            .init(entity: glowCore, texture: radialTexture,
                  maxOpacity: Motion.glowCoreOpacity, saturation: 0.45)
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
        context.coordinator.hueTarget = colorHue
        context.coordinator.glowTarget = lightOn ? 1 : 0
    }

    // MARK: - Glow layers

    /// Unlit transparent material for a glow layer. RealityKit ignores
    /// the color texture's alpha channel, so the falloff must live in an
    /// explicit grayscale opacity map.
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
}

#Preview {
    RGBLEDPreviewView(chennalMac: "80b54ee8b228", chennelPosition: 2)
}
