import SwiftUI

// MARK: - Navigation buttons

/// Standard back / dismiss button — 40×40 raised neumorphic rounded square.
struct LimiBackButton: View {
    var icon: String = "chevron.left"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(LimiTypography.headline)
                .foregroundColor(.appTextPrimary)
                .frame(width: 40, height: 40)
                .neuCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modal navigation chrome

/// Secondary line under a modal navigation title (nav bar owns title + close).
struct LimiModuleSubtitle: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(LimiTypography.subheadline)
                .foregroundColor(Color.appTextTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Native Close action for modal presentations (sheets and fullScreenCovers).
struct LimiCloseToolbarButton: View {
    var title: String = "Close"
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(LimiTypography.callout)
            .foregroundColor(.brandHighlight)
            .accessibilityLabel("Close")
    }
}

extension View {
    /// Native modal navigation bar: Close in the cancellation slot and optional inline title.
    func limiModalNavigationBar(
        title: String = "",
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        showsCloseButton: Bool = true,
        onClose: @escaping () -> Void
    ) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        LimiCloseToolbarButton(action: onClose)
                    }
                }
            }
            .toolbarBackground(Color.appCanvasPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// Standard sheet presentation chrome aligned with DeviceControlNavigationShell.
    func limiModalSheetStyle() -> some View {
        presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.appCanvasPrimary)
    }

    /// Extra bottom inset so scroll content clears the global floating voice orb.
    func limiFloatingOrbClearance() -> some View {
        padding(.bottom, LimiSpacing.floatingOrbClearance)
    }
}

/// Reusable modal shell: NavigationStack with native Close toolbar.
struct LimiModalNavigationShell<Content: View>: View {
    let title: String
    var displayMode: NavigationBarItem.TitleDisplayMode = .inline
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.appCanvasPrimary)
                .limiModalNavigationBar(title: title, displayMode: displayMode, onClose: onClose)
        }
        .limiModalSheetStyle()
    }
}
