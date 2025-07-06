/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
SwiftUI view for drag and drop file selection.
*/

import SwiftUI
import UniformTypeIdentifiers

struct FileDropView: View {
    let onFilesDropped: ([URL]) -> Void
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 72))
                    .foregroundColor(isDragOver ? .accentColor : .secondary)
                    .scaleEffect(isDragOver ? 1.1 : 1.0)
                
                VStack(spacing: 8) {
                    Text("Drop Video Files Here")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Or click the + button in the toolbar to browse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Supported Video Formats")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 12) {
                        ForEach(["MP4", "MOV", "M4V", "AVI"], id: \.self) { format in
                            Text(format)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("What is Apple Projected Media Profile?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("APMP is Apple's format for immersive 180° and 360° videos, optimized for Vision Pro and other devices. Convert your equirectangular or half-equirectangular videos for the best viewing experience.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                        )
                )
        )
        .padding(32)
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            let urls = providers.compactMap { provider in
                var url: URL?
                let semaphore = DispatchSemaphore(value: 0)
                
                _ = provider.loadObject(ofClass: URL.self) { loadedURL, _ in
                    url = loadedURL
                    semaphore.signal()
                }
                
                semaphore.wait()
                return url
            }
            
            if !urls.isEmpty {
                onFilesDropped(urls)
            }
            
            return true
        }
        .animation(.easeInOut(duration: 0.2), value: isDragOver)
    }
}

#Preview {
    FileDropView { urls in
        print("Files dropped: \(urls)")
    }
    .frame(width: 600, height: 400)
}