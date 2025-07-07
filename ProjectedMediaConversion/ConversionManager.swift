/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Manages the queue of video conversions and coordinates with the conversion logic.
*/

import Foundation
import SwiftUI

@MainActor
class ConversionManager: ObservableObject {
    @Published var queuedFiles: [ConversionItem] = []
    @Published var isProcessing = false
    
    private var processingTask: Task<Void, Never>?
    
    func addFiles(_ urls: [URL]) {
        let videoURLs = urls.filter { url in
            // Filter for video files
            let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey])
            return resourceValues?.contentType?.conforms(to: .movie) == true ||
                   resourceValues?.contentType?.conforms(to: .video) == true
        }
        
        let newItems = videoURLs.map { url in
            var item = ConversionItem(sourceURL: url)
            // Get file size
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                item.totalBytes = Int64(fileSize)
            }
            return item
        }
        queuedFiles.append(contentsOf: newItems)
    }
    
    func removeFile(at index: Int) {
        guard index < queuedFiles.count else { return }
        queuedFiles.remove(at: index)
    }
    
    func removeFile(withId id: UUID) {
        queuedFiles.removeAll { $0.id == id }
    }
    
    func clearQueue() {
        queuedFiles.removeAll()
    }
    
    func startProcessing(
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        baselineInMillimeters: Double,
        horizontalFOV: Double,
        outputDirectory: URL?,
        audioConfiguration: AudioConfiguration
    ) {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        processingTask = Task {
            await processQueue(
                projectionFormat: projectionFormat,
                stereoscopicMode: stereoscopicMode,
                baselineInMillimeters: baselineInMillimeters,
                horizontalFOV: horizontalFOV,
                outputDirectory: outputDirectory,
                audioConfiguration: audioConfiguration
            )
        }
    }
    
    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        
        // Mark any processing items as cancelled
        for index in queuedFiles.indices {
            if queuedFiles[index].status == .processing {
                queuedFiles[index].status = .cancelled
            }
        }
    }
    
    private func processQueue(
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        baselineInMillimeters: Double,
        horizontalFOV: Double,
        outputDirectory: URL?,
        audioConfiguration: AudioConfiguration
    ) async {
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        for index in queuedFiles.indices {
            guard !Task.isCancelled else { break }
            
            let item = queuedFiles[index]
            if item.status != .pending { continue }
            
            await updateItemStatus(at: index, status: .processing)
            await updateItemStartTime(at: index, startTime: Date())
            
            // Set up audio configuration for this item
            var itemAudioConfig = audioConfiguration
            if let externalAudioURL = audioConfiguration.externalAudioURL {
                itemAudioConfig.externalAudioURL = externalAudioURL
            }
            
            await updateItemAudioConfiguration(at: index, audioConfiguration: itemAudioConfig)
            
            do {
                let outputURL = try await convertFile(
                    item: item,
                    index: index,
                    projectionFormat: projectionFormat,
                    stereoscopicMode: stereoscopicMode,
                    baselineInMillimeters: baselineInMillimeters,
                    horizontalFOV: horizontalFOV,
                    outputDirectory: outputDirectory,
                    audioConfiguration: itemAudioConfig
                )
                
                await updateItemOutput(at: index, outputURL: outputURL, status: .completed)
                
            } catch {
                await updateItemError(at: index, error: error, status: .failed)
            }
        }
    }
    
    private func convertFile(
        item: ConversionItem,
        index: Int,
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        baselineInMillimeters: Double,
        horizontalFOV: Double,
        outputDirectory: URL?,
        audioConfiguration: AudioConfiguration
    ) async throws -> URL {
        let inputURL = item.sourceURL
        
        // Determine output URL
        let outputFileName = inputURL.deletingPathExtension().lastPathComponent + "_apmp.mov"
        let outputURL = (outputDirectory ?? inputURL.deletingLastPathComponent()).appendingPathComponent(outputFileName)
        
        // Delete existing output file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create projected media metadata
        let projectedMediaMetadata: ProjectedMediaMetadata
        
        if projectionFormat == .auto {
            // Use auto-detection
            print("🔍 Using auto-detection for projection format...")
            let classifier = try await ProjectedMediaClassifier(from: inputURL)
            print("✅ Auto-detection complete. Projection: \(classifier.projectionKind ?? "nil"), ViewPacking: \(classifier.viewPackingKind ?? "nil")")
            projectedMediaMetadata = ProjectedMediaMetadata(
                projectionKind: classifier.projectionKind ?? "Equirectangular",
                viewPackingKind: classifier.viewPackingKind,
                baselineInMillimeters: baselineInMillimeters,
                horizontalFOV: horizontalFOV
            )
        } else {
            // Use manual settings
            print("⚙️ Using manual settings - Projection: \(projectionFormat), Stereo: \(stereoscopicMode)")
            projectedMediaMetadata = ProjectedMediaMetadata(
                projectionKind: projectionFormat.commandLineValue ?? "Equirectangular",
                viewPackingKind: stereoscopicMode.commandLineValue,
                baselineInMillimeters: baselineInMillimeters,
                horizontalFOV: horizontalFOV
            )
        }
        print("📋 Final metadata: \(projectedMediaMetadata)")
        
        // Perform conversion with real-time progress updates
        print("🔄 Creating converter for: \(inputURL.lastPathComponent)")
        let converter = try await APMPConverter(from: inputURL)
        print("✅ Converter created successfully")
        
        print("🎬 Starting APMP conversion...")
        let conversionStartTime = Date()
        
        try await converter.convertToAPMP(output: outputURL, projectedMediaMetadata: projectedMediaMetadata) { @Sendable currentFrame, totalFrames, timeRemaining in
            // Update progress based on actual frame processing
            let progress = Double(currentFrame) / Double(totalFrames)
            let bytesProcessed = Int64(Double(item.totalBytes) * progress)
            
            Task { @MainActor in
                await self.updateItemVideoProgress(
                    at: index,
                    progress: progress,
                    bytesProcessed: bytesProcessed,
                    estimatedTimeRemaining: timeRemaining
                )
            }
        }
        
        let conversionTime = Date().timeIntervalSince(conversionStartTime)
        print("✅ APMP conversion completed in \(String(format: "%.2f", conversionTime)) seconds")
        
        // Now handle audio processing if needed
        if audioConfiguration.hasExternalAudio || await hasSourceAudio(inputURL) {
            print("🔊 Starting audio processing...")
            let audioProcessor = AudioProcessor()
            let finalOutputURL = try await audioProcessor.processAudio(
                videoURL: outputURL,
                sourceVideoURL: inputURL,
                audioConfiguration: audioConfiguration,
                progressCallback: { audioProgress in
                    Task { @MainActor in
                        await self.updateItemAudioProgress(at: index, audioProgress: audioProgress)
                    }
                },
                statusCallback: { status in
                    Task { @MainActor in
                        await self.updateItemAudioStatus(at: index, audioStatus: status)
                    }
                }
            )
            
            // Replace the video-only output with the final output
            if finalOutputURL != outputURL {
                try? FileManager.default.removeItem(at: outputURL)
                return finalOutputURL
            }
        }
        
        // Ensure progress shows 100%
        await updateItemProgress(
            at: index,
            progress: 1.0,
            bytesProcessed: item.totalBytes,
            estimatedTimeRemaining: 0
        )
        
        return outputURL
    }
    
    private func updateItemStatus(at index: Int, status: ConversionStatus) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].status = status
            }
        }
    }
    
    private func updateItemOutput(at index: Int, outputURL: URL, status: ConversionStatus) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].outputURL = outputURL
                self.queuedFiles[index].status = status
            }
        }
    }
    
    private func updateItemError(at index: Int, error: Error, status: ConversionStatus) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].error = error
                self.queuedFiles[index].status = status
            }
        }
    }
    
    private func updateItemStartTime(at index: Int, startTime: Date) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].startTime = startTime
            }
        }
    }
    
    private func updateItemProgress(at index: Int, progress: Double, bytesProcessed: Int64, estimatedTimeRemaining: TimeInterval) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].progress = progress
                self.queuedFiles[index].bytesProcessed = bytesProcessed
                self.queuedFiles[index].estimatedTimeRemaining = estimatedTimeRemaining
            }
        }
    }
    
    private func updateItemVideoProgress(at index: Int, progress: Double, bytesProcessed: Int64, estimatedTimeRemaining: TimeInterval) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].videoProgress = progress
                self.queuedFiles[index].progress = progress * 0.7  // Video takes 70% of overall progress
                self.queuedFiles[index].bytesProcessed = bytesProcessed
                self.queuedFiles[index].estimatedTimeRemaining = estimatedTimeRemaining
            }
        }
    }
    
    private func updateItemAudioProgress(at index: Int, audioProgress: Double) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].audioProgress = audioProgress
                // Audio takes 30% of overall progress, offset by video progress
                self.queuedFiles[index].progress = self.queuedFiles[index].videoProgress * 0.7 + audioProgress * 0.3
            }
        }
    }
    
    private func updateItemAudioStatus(at index: Int, audioStatus: AudioProcessingStatus) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].audioStatus = audioStatus
            }
        }
    }
    
    private func updateItemAudioConfiguration(at index: Int, audioConfiguration: AudioConfiguration) async {
        Task { @MainActor in
            if index < self.queuedFiles.count {
                self.queuedFiles[index].audioConfiguration = audioConfiguration
            }
        }
    }
    
    private func hasSourceAudio(_ url: URL) async -> Bool {
        do {
            let asset = AVURLAsset(url: url)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            return !audioTracks.isEmpty
        } catch {
            return false
        }
    }
}