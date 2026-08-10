//
//  VoicePendantAISummaryView.swift
//  Limi
//
//  Real, LLM-generated conversation summary with Day / Week / Month filters.
//  Sections: Overview, Key points, Action items, Topics. Supports manual
//  refresh, loading + error states, and an offline cache indicator.
//

import SwiftUI

struct VoicePendantAISummaryView: View {
    @StateObject private var viewModel: VoicePendantAISummaryViewModel

    init(pendant: VoicePendant) {
        _viewModel = StateObject(wrappedValue: VoicePendantAISummaryViewModel(pendant: pendant))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                rangePicker
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                content
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("AI Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.brandAction)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading
                                   ? .linear(duration: 1).repeatForever(autoreverses: false)
                                   : .default, value: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear { viewModel.onAppear() }
        .trackScreen("VoicePendantAISummaryView")
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.range) {
            ForEach(SummaryRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if let summary = viewModel.summary {
            summaryBody(summary)
        } else if viewModel.isLoading {
            loadingState
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func summaryBody(_ summary: VoicePendantAISummary) -> some View {
        if viewModel.isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                    .scaleEffect(0.8)
                Text("Updating summary…")
                    .font(LimiTypography.caption)
                    .foregroundColor(Color.appTextMuted)
            }
        } else if viewModel.isFromCache {
            Label("Showing last saved summary (offline)", systemImage: "wifi.slash")
                .font(LimiTypography.caption)
                .foregroundColor(Color.appTextMuted)
        }

        VPSectionCard("Overview") {
            Text(summary.overview.isEmpty ? "No overview available." : summary.overview)
                .font(LimiTypography.body)
                .foregroundColor(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !summary.keyPoints.isEmpty {
            VPSectionCard("Key Points") {
                bulletList(summary.keyPoints, icon: "circle.fill", tint: .brandAction)
            }
        }

        if !summary.actionItems.isEmpty {
            VPSectionCard("Action Items") {
                bulletList(summary.actionItems, icon: "checkmark.circle.fill", tint: .emerald)
            }
        }

        if !summary.topics.isEmpty {
            VPSectionCard("Topics Discussed") {
                topicTags(summary.topics)
            }
        }

        Text("Generated \(generatedString(summary.generatedAt))")
            .font(LimiTypography.caption2)
            .foregroundColor(Color.appTextMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    private func bulletList(_ items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: icon == "circle.fill" ? 7 : 14, weight: .semibold))
                        .foregroundColor(tint)
                        .padding(.top, icon == "circle.fill" ? 6 : 1)
                    Text(item)
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func topicTags(_ topics: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(topics, id: \.self) { topic in
                Text(topic)
                    .font(LimiTypography.caption)
                    .foregroundColor(.brandAction)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandHighlight.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
                .scaleEffect(1.2)
            Text("Generating AI summary…")
                .font(LimiTypography.callout)
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(LimiTypography.title2)
                .foregroundColor(Color.appTextMuted)
            Text("No summary yet")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
            Text("Tap refresh to generate an AI summary of your conversations.")
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
                .multilineTextAlignment(.center)
            Button {
                viewModel.refresh()
            } label: {
                Text("Generate Summary")
                    .font(LimiTypography.callout)
                    .foregroundColor(.brandAction)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 360)
                            .stroke(Color.brandAction, lineWidth: 1.5)
                    )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 24)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.appWarning)
            Text(message)
                .font(LimiTypography.caption)
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(3)
            Spacer()
            Button("Retry") { viewModel.refresh() }
                .font(LimiTypography.caption)
                .foregroundColor(.brandAction)
        }
        .padding(12)
        .limiPanel(cornerRadius: 12)
    }

    private func generatedString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Simple flow layout for topic tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += rowHeight + spacing
                rows.append([])
                rowWidth = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        VoicePendantAISummaryView(
            pendant: VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                                  status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2")
        )
    }
    .preferredColorScheme(.dark)
}
