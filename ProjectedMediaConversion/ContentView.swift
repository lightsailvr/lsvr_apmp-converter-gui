/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Main SwiftUI view for the Projected Media Conversion application.
*/

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation

struct ContentView: View {
    @StateObject private var conversionManager = ConversionManager()
    @State private var selectedProjection: ProjectionFormat = .auto
    @State private var selectedStereoscopicMode: StereoscopicMode = .auto
    @State private var showingAdvancedSettings = false
    @State private var baselineInMillimeters: Double = 64.0
    @State private var horizontalFOV: Double = 180.0
    @State private var showingFileImporter = false
    @State private var outputDirectory: URL?
    
    // Audio configuration state
    @State private var showingAudioSettings = false
    @State private var externalAudioURL: URL?
    @State private var selectedAmbisonicOrder: AmbisonicOrder = .first
    @State private var overrideAudioOrder = false
    @State private var showingAudioFileImporter = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with settings
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(.accentColor)
                        Text("Conversion Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Configure how your videos will be converted to Apple Projected Media Profile format.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            Text("Video Format")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Picker("Projection Format", selection: $selectedProjection) {
                            ForEach(ProjectionFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "eye.trianglebadge.exclamationmark")
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            Text("Stereoscopic Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Picker("Stereoscopic Mode", selection: $selectedStereoscopicMode) {
                            ForEach(StereoscopicMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                
                DisclosureGroup(isExpanded: $showingAdvancedSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text("Baseline (mm)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            TextField("64.0", value: $baselineInMillimeters, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text("Horizontal FOV (degrees)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            TextField("180.0", value: $horizontalFOV, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Text("Advanced settings for stereoscopic calibration and field of view adjustment.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                        Text("Advanced Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Divider()
                
                // Audio Configuration Section
                DisclosureGroup(isExpanded: $showingAudioSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("External Audio File")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text(externalAudioURL?.lastPathComponent ?? "No file selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                
                                Button("Browse...") {
                                    showingAudioFileImporter = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            
                            if externalAudioURL != nil {
                                Button("Clear") {
                                    externalAudioURL = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ambisonic Order")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Ambisonic Order", selection: $selectedAmbisonicOrder) {
                                ForEach(AmbisonicOrder.allCases, id: \.self) { order in
                                    Text(order.displayName).tag(order)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .disabled(externalAudioURL == nil && !overrideAudioOrder)
                        }
                        
                        Toggle("Override detected audio order", isOn: $overrideAudioOrder)
                            .font(.caption)
                        
                        Text("Select an external ambisonic audio file to replace the video's audio track. Supports 1st (4ch), 2nd (9ch), and 3rd (16ch) order ambisonic files.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.secondary)
                        Text("Audio Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text("Output Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(outputDirectory?.lastPathComponent ?? "Same as source files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Choose Folder...") {
                            selectOutputDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("Converted files will be saved with '_apmp.mov' suffix.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 280, maxWidth: 300)
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // File drop area and queue
                if conversionManager.queuedFiles.isEmpty {
                    FileDropView(onFilesDropped: { urls in
                        conversionManager.addFiles(urls)
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ConversionQueueView(
                        conversionManager: conversionManager,
                        projectionFormat: selectedProjection,
                        stereoscopicMode: selectedStereoscopicMode,
                        baselineInMillimeters: baselineInMillimeters,
                        horizontalFOV: horizontalFOV,
                        outputDirectory: outputDirectory,
                        audioConfiguration: AudioConfiguration(
                            externalAudioURL: externalAudioURL,
                            detectedOrder: nil,
                            overrideOrder: overrideAudioOrder ? selectedAmbisonicOrder : nil
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Projected Media Conversion")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingFileImporter = true
                }) {
                    Label("Add Files", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                conversionManager.addFiles(urls)
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingAudioFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let audioURL = urls.first {
                    externalAudioURL = audioURL
                    // Auto-detect ambisonic order based on filename or channel count
                    detectAmbisonicOrder(from: audioURL)
                }
            case .failure(let error):
                print("Audio file import failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    private func detectAmbisonicOrder(from url: URL) {
        Task {
            do {
                let asset = AVURLAsset(url: url)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                
                if let audioTrack = tracks.first {
                    let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                    
                    if let formatDescription = formatDescriptions.first {
                        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                        
                        if let streamDescription = audioStreamBasicDescription {
                            let channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
                            
                            DispatchQueue.main.async {
                                switch channelCount {
                                case 4:
                                    self.selectedAmbisonicOrder = .first
                                case 9:
                                    self.selectedAmbisonicOrder = .second
                                case 16:
                                    self.selectedAmbisonicOrder = .third
                                default:
                                    print("⚠️ Unsupported channel count: \(channelCount)")
                                }
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error detecting ambisonic order: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
