//
//  FullscreenImageView.swift
//  Donguri
//
//  Created by John Connery on 8/17/26.
//

import SwiftUI

struct FullscreenImageView: View {
    let url: URL
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(x: offset.width + dragOffset.width,
                                    y: offset.height + dragOffset.height)
                            .gesture(magnifyGesture)
                            .simultaneousGesture(dragGesture)
                            .onTapGesture(count: 2) { toggleZoom() }
                    case .failure:
                        Label("画像を読み込めませんでした", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(.white.opacity(0.7))
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(lastScale * value, 5))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { offset = .zero }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    dragOffset = value.translation
                } else if value.translation.height > 0 {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                if scale <= 1, value.translation.height > 120 {
                    onDismiss()
                    return
                }
                offset.width += dragOffset.width
                offset.height += dragOffset.height
                dragOffset = .zero
            }
    }

    private func toggleZoom() {
        withAnimation(.snappy) {
            if scale > 1 {
                scale = 1
                lastScale = 1
                offset = .zero
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }
}
