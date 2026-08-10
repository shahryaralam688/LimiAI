//
//  VoicePendantMemoryView.swift
//  Limi
//
//  Summary & Memory screen — a searchable timeline that unifies conversation
//  history, AI summaries and notes generated from conversations. Filter chips
//  switch between kinds; tapping an item opens its detail.
//

import SwiftUI

struct VoicePendantMemoryView: View {
    @StateObject private var viewModel: VoicePendantMemoryViewModel
    @State private var showAddNote = false
    @State private var newNoteText = ""
    @State private var selectedSummary: VoicePendantSummary?

    init(pendant: VoicePendant) {
        _viewModel = StateObject(wrappedValue: VoicePendantMemoryViewModel(pendant: pendant))
    }

    var body: some View {
        VStack(spacing: 0) {
            aiSummaryEntry
            searchBar
            filterChips
            timeline
        }
        .background(Color.appCanvasPrimary.ignoresSafeArea())
        .navigationTitle("Summary & Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newNoteText = ""
                    showAddNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.appTextPrimary)
                }
            }
        }
        .task {
            if viewModel.allTimelineItems.isEmpty { await viewModel.load() }
        }
        .alert("New Note", isPresented: $showAddNote) {
            TextField("Write a note…", text: $newNoteText)
            Button("Save") {
                let text = newNoteText
                Task { await viewModel.addNote(text) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add a note to this pendant's memory.")
        }
        .sheet(item: $selectedSummary) { summary in
            summaryDetailSheet(summary)
        }
        .trackScreen("VoicePendantMemoryView", metadata: ["pendant": viewModel.pendant.id])
    }

    // MARK: - AI Summary entry

    private var aiSummaryEntry: some View {
        NavigationLink {
            VoicePendantAISummaryView(pendant: viewModel.pendant)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(LimiTypography.button)
                    .foregroundColor(.brandAction)
                    .frame(width: 40, height: 40)
                    .background(Color.brandHighlight.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Summary")
                        .font(LimiTypography.headline)
                        .foregroundColor(.appTextPrimary)
                    Text("Day / Week / Month — AI-generated overview")
                        .font(LimiTypography.caption)
                        .foregroundColor(Color.appTextTertiary)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(LimiTypography.footnote)
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(14)
            .background(Color.appSurfaceSecondaryAlt)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandHighlight.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(LimiTypography.callout)
                .foregroundColor(Color.appTextMuted)
            TextField("Search memory…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.appTextPrimary)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.appTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .limiPanel(cornerRadius: 14)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", count: viewModel.allTimelineItems.count, isSelected: viewModel.kindFilter == nil) {
                    viewModel.kindFilter = nil
                }
                ForEach(MemoryItemKind.allCases, id: \.self) { kind in
                    chip(title: kind.displayName, count: viewModel.count(for: kind),
                         isSelected: viewModel.kindFilter == kind) {
                        viewModel.kindFilter = viewModel.kindFilter == kind ? nil : kind
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private func chip(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(LimiTypography.footnote)
                Text("\(count)")
                    .font(LimiTypography.caption)
                    .foregroundColor(isSelected ? Color.appCanvasPrimary : Color.appTextMuted)
            }
            .foregroundColor(isSelected ? Color.appCanvasPrimary : .appTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.themeWhite : Color.appSurfaceSecondaryAlt)
            .clipShape(Capsule())
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private var timeline: some View {
        if viewModel.isLoading && viewModel.allTimelineItems.isEmpty {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appBorderSoft))
            Spacer()
        } else {
            let items = viewModel.filteredTimeline
            if items.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            timelineRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func timelineRow(_ item: MemoryTimelineItem) -> some View {
        Button {
            if item.kind == .summary {
                let rawID = String(item.id.dropFirst(2))
                selectedSummary = viewModel.summaries.first { $0.id == rawID }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.kind.icon)
                    .font(LimiTypography.callout)
                    .foregroundColor(accent(for: item.kind))
                    .frame(width: 38, height: 38)
                    .background(accent(for: item.kind).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(LimiTypography.callout)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Text(relativeTime(item.timestamp))
                            .font(LimiTypography.caption2)
                            .foregroundColor(Color.appTextMuted)
                    }
                    Text(item.detail)
                        .font(LimiTypography.footnote)
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .limiPanel(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(LimiTypography.title2)
                .foregroundColor(Color.appTextMuted)
            Text(viewModel.searchText.isEmpty ? "Nothing here yet" : "No matches found")
                .font(LimiTypography.callout)
                .foregroundColor(.appTextPrimary)
            Text(viewModel.searchText.isEmpty
                 ? "Conversations and summaries will appear here."
                 : "Try a different search term.")
                .font(LimiTypography.footnote)
                .foregroundColor(Color.appTextMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Detail Sheet

    private func summaryDetailSheet(_ summary: VoicePendantSummary) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VPSectionCard("Summary") {
                        Text(summary.summary)
                            .font(LimiTypography.body)
                            .foregroundColor(Color.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !summary.highlights.isEmpty {
                        VPSectionCard("Highlights") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(summary.highlights, id: \.self) { highlight in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(LimiTypography.callout)
                                            .foregroundColor(.emerald)
                                        Text(highlight)
                                            .font(LimiTypography.subheadline)
                                            .foregroundColor(.appTextPrimary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appCanvasPrimary.ignoresSafeArea())
            .limiModalNavigationBar(title: summary.title, onClose: { selectedSummary = nil })
        }
    }

    // MARK: - Helpers

    private func accent(for kind: MemoryItemKind) -> Color {
        switch kind {
        case .conversation: return .brandAction
        case .summary: return .emerald
        case .note: return .orange
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        VoicePendantMemoryView(
            pendant: VoicePendant(id: "pendant-001", name: "Living Room Pendant", room: "Living Room",
                                  status: .online, batteryLevel: 92, signalStrength: 4, firmwareVersion: "1.4.2")
        )
    }
}
