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
        outputDirectory: URL?
    ) {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        processingTask = Task {
            await processQueue(
                projectionFormat: projectionFormat,
                stereoscopicMode: stereoscopicMode,
                baselineInMillimeters: baselineInMillimeters,
                horizontalFOV: horizontalFOV,
                outputDirectory: outputDirectory
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
        outputDirectory: URL?
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
            
            do {
                let outputURL = try await convertFile(
                    item: item,
                    index: index,
                    projectionFormat: projectionFormat,
                    stereoscopicMode: stereoscopicMode,
                    baselineInMillimeters: baselineInMillimeters,
                    horizontalFOV: horizontalFOV,
                    outputDirectory: outputDirectory
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
        outputDirectory: URL?
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
                await self.updateItemProgress(
                    at: index,
                    progress: progress,
                    bytesProcessed: bytesProcessed,
                    estimatedTimeRemaining: timeRemaining
                )
            }
        }
        
        let conversionTime = Date().timeIntervalSince(conversionStartTime)
        print("✅ APMP conversion completed in \(String(format: "%.2f", conversionTime)) seconds")
        
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
}