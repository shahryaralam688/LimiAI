//
//  PlexusOrbView.swift
//  Limi
//
//  Cyan plexus sphere — Fibonacci nodes, proximity edges, depth glow.
//

import SwiftUI
import simd

struct PlexusOrbView: View {
    let size: CGFloat
    var isActive: Bool = true
    var nodeCount: Int = 110
    var connectionDistance: Float = 0.36
    var maxNeighbors: Int = 5
    /// 1 = default spin; higher = faster globe rotation.
    var spinSpeed: Float = 1.0

    private let mesh: PlexusMesh

    /// Brand eton — bright node cores (Color.brandHighlight #93CFA2)
    private var orbCore: Color {
        Color.brandHighlight
    }

    /// Brand emerald — lines and glow halos (Color.brandAction #54BB74)
    private var orbGlow: Color {
        Color.brandAction
    }

    init(
        size: CGFloat,
        isActive: Bool = true,
        nodeCount: Int = 110,
        connectionDistance: Float = 0.36,
        maxNeighbors: Int = 5,
        spinSpeed: Float = 1.0
    ) {
        self.size = size
        self.isActive = isActive
        self.nodeCount = nodeCount
        self.connectionDistance = connectionDistance
        self.maxNeighbors = maxNeighbors
        self.spinSpeed = spinSpeed
        self.mesh = PlexusMesh(
            nodeCount: nodeCount,
            connectionDistance: connectionDistance,
            maxNeighbors: maxNeighbors
        )
    }

    @State private var appearDate: Date = .now

    /// Intro timeline: tiny dot grows (0...dotDuration), then nodes double out
    /// while the sphere expands (dotDuration...dotDuration+revealDuration).
    private static let dotDuration: TimeInterval = 0.9
    private static let revealDuration: TimeInterval = 2.4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            Canvas { context, canvasSize in
                guard canvasSize.width > 1, canvasSize.height > 1 else { return }

                let time = timeline.date.timeIntervalSinceReferenceDate
                let elapsed = timeline.date.timeIntervalSince(appearDate)
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let scale = min(canvasSize.width, canvasSize.height) * 0.46

                let pulse = 0.82 + 0.18 * sin(time * 2.1)

                // Phase 1 — a single tiny dot grows to node size at the center.
                if elapsed < Self.dotDuration {
                    let progress = max(0, elapsed / Self.dotDuration)
                    let eased = 1 - pow(1 - progress, 3)
                    let coreR = max(0.6, PlexusMesh.coreRadius(for: 1, base: size) * CGFloat(eased))
                    drawNode(
                        context: context,
                        x: center.x,
                        y: center.y,
                        coreR: coreR,
                        depthOpacity: 0.4 + 0.6 * eased,
                        pulse: pulse
                    )
                    return
                }

                // Phase 2 — nodes double out while the sphere expands; rotation already running.
                let revealProgress = min(1, (elapsed - Self.dotDuration) / Self.revealDuration)
                let expansion = CGFloat(1 - pow(1 - revealProgress, 3))
                // Exponential growth 1 → N gives the "1, 2, 4, 8..." doubling feel.
                let visibleNodes = pow(Double(mesh.nodes.count), revealProgress)

                let projected = mesh.projectedPoints(
                    at: time,
                    center: center,
                    scale: scale,
                    isActive: isActive,
                    spinSpeed: spinSpeed
                )

                // Collapse positions toward center while expanding.
                let placed: [CGPoint] = projected.map { p in
                    CGPoint(
                        x: center.x + (p.point.x - center.x) * expansion,
                        y: center.y + (p.point.y - center.y) * expansion
                    )
                }

                func introAlpha(_ index: Int) -> Double {
                    min(1, max(0, visibleNodes - Double(index)))
                }

                let lineScale = (isActive ? 1.0 : 0.5) * Double(revealProgress)
                let nodeScale = isActive ? 1.0 : 0.55

                // Lines first (back → front); only between already-revealed nodes.
                for edge in mesh.sortedEdges(projected: projected) {
                    let edgeAlpha = min(introAlpha(edge.a), introAlpha(edge.b))
                    guard edgeAlpha > 0.01 else { continue }

                    let p1 = projected[edge.a]
                    let p2 = projected[edge.b]
                    let depth = (p1.z + p2.z) * 0.5
                    let opacity = PlexusMesh.depthOpacity(depth, kind: .line) * lineScale * edgeAlpha

                    var path = Path()
                    path.move(to: placed[edge.a])
                    path.addLine(to: placed[edge.b])
                    context.stroke(
                        path,
                        with: .color(orbGlow.opacity(opacity)),
                        lineWidth: PlexusMesh.lineWidth(for: depth, base: size)
                    )
                }

                // Nodes (back → front) — layered halos like reference
                let drawOrder = projected.indices.sorted { projected[$0].z < projected[$1].z }
                for index in drawOrder {
                    let alpha = introAlpha(index)
                    guard alpha > 0.01 else { continue }

                    let point = projected[index]
                    let depthOpacity = PlexusMesh.depthOpacity(point.z, kind: .node) * nodeScale * alpha
                    // New nodes grow in from tiny to full size.
                    let coreR = PlexusMesh.coreRadius(for: point.z, base: size) * CGFloat(0.3 + 0.7 * alpha)

                    drawNode(
                        context: context,
                        x: placed[index].x,
                        y: placed[index].y,
                        coreR: coreR,
                        depthOpacity: depthOpacity,
                        pulse: pulse
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { appearDate = .now }
    }

    private func drawNode(
        context: GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        coreR: CGFloat,
        depthOpacity: Double,
        pulse: Double
    ) {
        let halos: [(CGFloat, Double)] = [
            (coreR * 5.0, 0.05 * pulse),
            (coreR * 3.2, 0.10 * pulse),
            (coreR * 2.0, 0.20 * pulse),
            (coreR * 1.2, 0.45 * pulse)
        ]

        for (haloR, haloAlpha) in halos {
            let rect = CGRect(x: x - haloR, y: y - haloR, width: haloR * 2, height: haloR * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(orbGlow.opacity(depthOpacity * haloAlpha))
            )
        }

        let coreRect = CGRect(x: x - coreR, y: y - coreR, width: coreR * 2, height: coreR * 2)
        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(orbCore.opacity(min(1, depthOpacity * 1.1)))
        )
    }
}

// MARK: - 3D mesh

private struct PlexusMesh {
    struct Node {
        let base: SIMD3<Float>
        let phaseX: Float
        let phaseY: Float
        let phaseZ: Float
        let driftAmp: Float
    }

    struct Edge: Hashable {
        let a: Int
        let b: Int
    }

    struct ProjectedPoint {
        let point: CGPoint
        let z: Float
    }

    enum DepthKind {
        case line
        case node
    }

    let nodes: [Node]
    let edges: [Edge]

    init(nodeCount: Int, connectionDistance: Float, maxNeighbors: Int) {
        let count = max(20, nodeCount)
        var built: [Node] = []
        built.reserveCapacity(count)

        let golden = Float.pi * (3 - sqrt(5))
        for index in 0..<count {
            let y = 1 - (Float(index) / Float(count - 1)) * 2
            let radius = sqrt(max(0, 1 - y * y))
            let theta = golden * Float(index)
            let base = SIMD3(cos(theta) * radius, y, sin(theta) * radius)
            built.append(
                Node(
                    base: base,
                    phaseX: Float(index) * 1.37,
                    phaseY: Float(index) * 2.11,
                    phaseZ: Float(index) * 0.83,
                    driftAmp: 0.008 + Float(index % 9) * 0.0018
                )
            )
        }
        nodes = built

        var edgeSet = Set<Edge>()
        var uniqueEdges: [Edge] = []
        for i in 0..<count {
            var neighbors: [(Int, Float)] = []
            neighbors.reserveCapacity(8)
            for j in 0..<count where i != j {
                let distance = simd_distance(nodes[i].base, nodes[j].base)
                if distance <= connectionDistance {
                    neighbors.append((j, distance))
                }
            }
            neighbors.sort { $0.1 < $1.1 }
            for (j, _) in neighbors.prefix(max(1, maxNeighbors)) {
                let edge = i < j ? Edge(a: i, b: j) : Edge(a: j, b: i)
                if edgeSet.insert(edge).inserted {
                    uniqueEdges.append(edge)
                }
            }
        }
        edges = uniqueEdges
    }

    func sortedEdges(projected: [ProjectedPoint]) -> [Edge] {
        edges.sorted { lhs, rhs in
            let z1 = (projected[lhs.a].z + projected[lhs.b].z) * 0.5
            let z2 = (projected[rhs.a].z + projected[rhs.b].z) * 0.5
            return z1 < z2
        }
    }

    func projectedPoints(
        at time: TimeInterval,
        center: CGPoint,
        scale: CGFloat,
        isActive: Bool,
        spinSpeed: Float
    ) -> [ProjectedPoint] {
        // timeIntervalSinceReferenceDate is ~8e8s; converting directly to Float loses
        // sub-minute precision and freezes the animation. Wrap into a small range first.
        let t = Float(time.truncatingRemainder(dividingBy: 86_400))
        // Main spin around Y (globe-style) with gentle X/Z wobble for 3D feel.
        let rotY = t * 0.85 * spinSpeed
        let rotX = t * 0.18 * spinSpeed
        let rotZ = t * 0.06 * spinSpeed
        let breathe = 1 + (isActive ? 0.028 : 0.012) * sin(t * 1.55)
        let driftScale: Float = isActive ? 1.0 : 0.4

        return nodes.map { node in
            var point = node.base

            // Organic micro-drift on the shell
            point.x += node.driftAmp * driftScale * sin(t * 1.25 + node.phaseX)
            point.y += node.driftAmp * driftScale * cos(t * 1.05 + node.phaseY)
            point.z += node.driftAmp * driftScale * sin(t * 0.85 + node.phaseZ)
            point = Self.normalize(point) * breathe

            point = Self.rotateZ(Self.rotateX(Self.rotateY(point, angle: rotY), angle: rotX), angle: rotZ)

            let perspective: Float = 1.2 / (1.2 - point.z * 0.25)
            return ProjectedPoint(
                point: CGPoint(
                    x: center.x + CGFloat(point.x * perspective) * scale,
                    y: center.y + CGFloat(point.y * perspective) * scale
                ),
                z: point.z
            )
        }
    }

    static func depthOpacity(_ z: Float, kind: DepthKind) -> Double {
        let front = Double((z + 1) * 0.5)
        switch kind {
        case .line:
            return 0.08 + front * 0.62
        case .node:
            return 0.15 + front * 0.85
        }
    }

    static func coreRadius(for z: Float, base: CGFloat) -> CGFloat {
        let front = CGFloat((z + 1) * 0.5)
        return max(0.9, base * 0.006 + front * base * 0.016)
    }

    static func lineWidth(for z: Float, base: CGFloat) -> CGFloat {
        let front = CGFloat((z + 1) * 0.5)
        return max(0.35, base * 0.0012 + front * base * 0.002)
    }

    private static func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let length = max(sqrt(v.x * v.x + v.y * v.y + v.z * v.z), 1e-6)
        return v / length
    }

    private static func rotateY(_ v: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }

    private static func rotateX(_ v: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
    }

    private static func rotateZ(_ v: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
    }
}

// MARK: - Previews

#Preview("Plexus Orb — Reference") {
    ZStack {
        Color.black.ignoresSafeArea()
        PlexusOrbView(size: 300, isActive: true)
    }
    .preferredColorScheme(.dark)
}

#Preview("Plexus Orb — Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        PlexusOrbView(size: 260, isActive: false)
    }
    .preferredColorScheme(.dark)
}

#Preview("Plexus Orb — Sign-In Size") {
    GeometryReader { geo in
        ZStack {
            Color.black.ignoresSafeArea()
            PlexusOrbView(
                size: min(geo.size.width, geo.size.height) * 0.55,
                isActive: true
            )
        }
    }
    .preferredColorScheme(.dark)
}
