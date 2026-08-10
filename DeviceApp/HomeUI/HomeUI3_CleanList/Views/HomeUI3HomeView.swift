//
//  HomeUI3HomeView.swift
//  LIMI AI Device — Home UI 3 Clean list
//

import SwiftUI

struct DeviceHomeUIVariantThreeView: View {
    let userName: String
    let items: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onAdd: () -> Void

    var body: some View {
        // Do NOT wrap in NavigationStack — DeviceHomeView already provides one.
        // Nested stacks have caused EXC_BAD_ACCESS on theme switch.
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home UI 3")
                        .font(HomeUI3Type.title)
                        .foregroundStyle(HomeUI3Color.text)
                    Text("Hi \(userName) — Clean list")
                        .font(HomeUI3Type.caption)
                        .foregroundStyle(HomeUI3Color.secondary)
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(HomeUI3Color.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                Section("Devices") {
                    if items.isEmpty {
                        Text("No devices yet")
                            .foregroundStyle(HomeUI3Color.secondary)
                    } else {
                        ForEach(items) { item in
                            Button { onOpen(item.id) } label: {
                                HStack {
                                    Image(systemName: "lightbulb.led")
                                        .foregroundStyle(item.isOnline ? HomeUI3Color.accent : HomeUI3Color.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(HomeUI3Type.row)
                                            .foregroundStyle(HomeUI3Color.text)
                                        Text(item.subtitle)
                                            .font(HomeUI3Type.caption)
                                            .foregroundStyle(HomeUI3Color.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { item.isPowerOn },
                                        set: { _ in onToggle(item.id) }
                                    ))
                                    .labelsHidden()
                                    .tint(HomeUI3Color.accent)
                                    .disabled(!item.isOnline)
                                }
                            }
                            .listRowBackground(HomeUI3Color.surface)
                            .opacity(item.isOnline ? 1 : 0.5)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(HomeUI3Color.canvas.ignoresSafeArea())
    }
}
