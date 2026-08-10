//
//  HomeUI4HomeView.swift
//  LIMI AI Device — Home UI 4 2-column grid
//

import SwiftUI

struct DeviceHomeUIVariantFourView: View {
    let userName: String
    let items: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onAdd: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Home UI 4")
                            .font(HomeUI4Type.title)
                            .foregroundStyle(HomeUI4Color.text)
                        Text("Hi \(userName) · Grid layout")
                            .font(HomeUI4Type.caption)
                            .foregroundStyle(HomeUI4Color.secondary)
                    }
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(HomeUI4Color.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        Button { onOpen(item.id) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lightbulb.led.fill")
                                        .foregroundStyle(item.isOnline ? HomeUI4Color.accent : HomeUI4Color.secondary)
                                    Spacer()
                                    Circle()
                                        .fill(item.isOnline ? HomeUI4Color.accent : HomeUI4Color.secondary.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                }
                                Text(item.name)
                                    .font(HomeUI4Type.cardTitle)
                                    .foregroundStyle(HomeUI4Color.text)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Toggle(item.isPowerOn ? "On" : "Off", isOn: Binding(
                                    get: { item.isPowerOn },
                                    set: { _ in onToggle(item.id) }
                                ))
                                .tint(HomeUI4Color.accent)
                                .disabled(!item.isOnline)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                            .background {
                                RoundedRectangle(cornerRadius: HomeUI4Radius.card, style: .continuous)
                                    .fill(HomeUI4Color.card)
                                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(item.isOnline ? 1 : 0.55)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(HomeUI4Color.canvas.ignoresSafeArea(edges: .top))
    }
}
