/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
SwiftUI view for displaying and managing the conversion queue.
*/

import SwiftUI
import AppKit

struct ConversionQueueView: View {
    @ObservedObject var conversionManager: ConversionManager
    let projectionFormat: ProjectionFormat
    let stereoscopicMode: StereoscopicMode
    let baselineInMillimeters: Double
    let horizontalFOV: Double
    let outputDirectory: URL?
    let audioConfiguration: AudioConfiguration
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversion Queue")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(conversionManager.queuedFiles.count) file(s) • \(completedCount) completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if conversionManager.isProcessing {
                            conversionManager.stopProcessing()
                        } else {
                            conversionManager.startProcessing(
                                projectionFormat: projectionFormat,
                                stereoscopicMode: stereoscopicMode,
                                baselineInMillimeters: baselineInMillimeters,
                                horizontalFOV: horizontalFOV,
                                outputDirectory: outputDirectory,
                                audioConfiguration: audioConfiguration
                            )
                        }
                    }) {
                        Label(
                            conversionManager.isProcessing ? "Stop" : "Start",
                            systemImage: conversionManager.isProcessing ? "stop.fill" : "play.fill"
                        )
                    }
                    .disabled(conversionManager.queuedFiles.isEmpty)
                    
                    Button("Clear") {
                        conversionManager.clearQueue()
                    }
                    .disabled(conversionManager.isProcessing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Queue list
            if conversionManager.queuedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No files in queue")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(conversionManager.queuedFiles.indices, id: \.self) { index in
                            ConversionItemView(
                                item: conversionManager.queuedFiles[index],
                                onRemove: {
                                    conversionManager.removeFile(at: index)
                                }
                            )
                            .disabled(conversionManager.isProcessing)
                            
                            if index < conversionManager.queuedFiles.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var completedCount: Int {
        conversionManager.queuedFiles.filter { $0.status == .completed }.count
    }
}

struct ConversionItemView: View {
    let item: ConversionItem
    let onRemove: () -> Void
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon with rotation animation
            Group {
                if item.status == .processing {
                    Image(systemName: item.status.systemImage)
                        .font(.title3)
                        .foregroundColor(statusColor)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                        .onDisappear {
                            rotationAngle = 0
                        }
                } else {
                    Image(systemName: item.status.systemImage)
                        .font(.title3)
                        .foregroundColor(statusColor)
                }
            }
            .frame(width: 24, height: 24)
            
            // File info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 16) {
                    Text(item.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.hasAudioConfiguration {
                        Text("• \(item.audioStatusDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if item.status == .processing && item.totalBytes > 0 {
                        Text("\(item.bytesProcessedFormatted) / \(item.fileSizeFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !item.estimatedTimeRemainingFormatted.isEmpty {
                            Text("• \(item.estimatedTimeRemainingFormatted) remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = item.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
                
                if item.status == .processing {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: min(item.progress, 1.0))
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(maxWidth: 300)
                        
                        if item.audioStatus != .pending {
                            HStack(spacing: 8) {
                                Text("Audio: \(item.audioStatus.displayName)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                if item.audioProgress > 0 {
                                    ProgressView(value: min(item.audioProgress, 1.0))
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(maxWidth: 100)
                                }
                            }
                        }
                        
                        if item.progress > 0 {
                            Text("\(Int(min(item.progress, 1.0) * 100))% complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if item.status == .completed, let outputURL = item.outputURL {
                    Button(action: {
                        NSWorkspace.shared.open(outputURL)
                    }) {
                        Image(systemName: "play.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Open converted file")
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                    }) {
                        Image(systemName: "folder")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from queue")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(item.status == .failed ? Color.red.opacity(0.1) : Color.clear)
        )
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending:
            return .secondary
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}

#Preview {
    ConversionQueueView(
        conversionManager: ConversionManager(),
        projectionFormat: .auto,
        stereoscopicMode: .auto,
        baselineInMillimeters: 64.0,
        horizontalFOV: 180.0,
        outputDirectory: nil,
        audioConfiguration: AudioConfiguration()
    )
}