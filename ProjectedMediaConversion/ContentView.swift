/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Main SwiftUI view for the Projected Media Conversion application.
*/

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var conversionManager = ConversionManager()
    @State private var selectedProjection: ProjectionFormat = .auto
    @State private var selectedStereoscopicMode: StereoscopicMode = .auto
    @State private var showingAdvancedSettings = false
    @State private var baselineInMillimeters: Double = 64.0
    @State private var horizontalFOV: Double = 180.0
    @State private var showingFileImporter = false
    @State private var outputDirectory: URL?
    
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
                        outputDirectory: outputDirectory
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
}

#Preview {
    ContentView()
}