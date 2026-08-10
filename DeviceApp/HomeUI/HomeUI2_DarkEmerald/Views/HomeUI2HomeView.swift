//
//  HomeUI2HomeView.swift
//  LIMI AI Device — Home UI 2 Dark emerald
//

import SwiftUI

struct DeviceHomeUIVariantTwoView: View {
    let userName: String
    let greeting: String
    let items: [DeviceHomeUIPreviewItem]
    var onOpen: (String) -> Void
    var onToggle: (String) -> Void
    var onAdd: () -> Void

    var body: some View {
        ZStack {
            HomeUI2Color.canvas.ignoresSafeArea(edges: .top)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(greeting), \(userName)")
                                .font(HomeUI2Type.title(22))
                                .foregroundStyle(HomeUI2Color.textPrimary)
                            Text("Home UI 2 · Dark emerald")
                                .font(HomeUI2Type.caption(13))
                                .foregroundStyle(HomeUI2Color.focus)
                        }
                        Spacer()
                        Button(action: onAdd) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(HomeUI2Color.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(HomeUI2Color.primaryDeep))
                                .overlay(Circle().stroke(HomeUI2Color.focus.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HomeUI2PrimaryButton(title: "Add device") { onAdd() }
                        .padding(.horizontal, 20)

                    ForEach(items) { item in
                        HomeUI2DeviceRow(
                            item: item,
                            onOpen: { onOpen(item.id) },
                            onToggle: { onToggle(item.id) }
                        )
                        .padding(.horizontal, 20)
                    }

                    Text("Independent Home UI 2 system — dark emerald + motion feedback.")
                        .font(HomeUI2Type.caption(11))
                        .foregroundStyle(HomeUI2Color.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}
