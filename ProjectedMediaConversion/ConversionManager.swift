/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Manages the queue of video conversions and coordinates with the conversion logic.
*/

import Foundation
import SwiftUI
import AVFoundation

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
        
        // Analyze video specifications for new items
        let startIndex = queuedFiles.count - newItems.count
        for i in 0..<newItems.count {
            Task {
                await analyzeVideoSpecs(at: startIndex + i)
            }
        }
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
        audioConfiguration: AudioConfiguration,
        qualitySettings: QualitySettings
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
                audioConfiguration: audioConfiguration,
                qualitySettings: qualitySettings
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
        audioConfiguration: AudioConfiguration,
        qualitySettings: QualitySettings
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
                    audioConfiguration: itemAudioConfig,
                    qualitySettings: qualitySettings
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
        audioConfiguration: AudioConfiguration,
        qualitySettings: QualitySettings
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
        
        try await converter.convertToAPMP(output: outputURL, projectedMediaMetadata: projectedMediaMetadata, qualitySettings: qualitySettings) { @Sendable currentFrame, totalFrames, timeRemaining in
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
        let sourceHasAudio = await hasSourceAudio(inputURL)
        if audioConfiguration.hasExternalAudio || sourceHasAudio {
            print("🔊 Starting audio processing...")
            let audioProcessor = AudioProcessor()
            let finalOutputURL = try await audioProcessor.processAudio(
                videoURL: outputURL,
                sourceVideoURL: inputURL,
                audioConfiguration: audioConfiguration,
                progressCallback: { @Sendable audioProgress in
                    Task { @MainActor in
                        await self.updateItemAudioProgress(at: index, audioProgress: audioProgress)
                    }
                },
                statusCallback: { @Sendable status in
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
    
    func analyzeVideoSpecs(at index: Int) async {
        guard index < queuedFiles.count else { return }
        
        let url = queuedFiles[index].sourceURL
        let specs = await extractVideoSpecifications(from: url)
        
        await MainActor.run {
            if index < self.queuedFiles.count {
                self.queuedFiles[index].inputVideoSpecs = specs
            }
        }
    }
    
    private func extractVideoSpecifications(from url: URL) async -> VideoSpecifications? {
        do {
            let asset = AVURLAsset(url: url)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            
            guard let videoTrack = videoTracks.first else { return nil }
            
            // Get basic properties
            let naturalSize = try await videoTrack.load(.naturalSize)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
            
            // Get format descriptions for codec and color info
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else { return nil }
            
            // Extract codec information
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let codec = fourCCToString(codecType)
            
            // Extract color space information
            let colorPrimaries = getColorPrimaries(from: formatDescription)
            let transferFunction = getTransferFunction(from: formatDescription)
            let colorMatrix = getColorMatrix(from: formatDescription)
            let pixelFormat = getPixelFormat(from: formatDescription)
            
            return VideoSpecifications(
                codec: codec,
                resolution: naturalSize,
                frameRate: Double(nominalFrameRate),
                bitrate: Int64(estimatedDataRate),
                colorPrimaries: colorPrimaries,
                transferFunction: transferFunction,
                colorMatrix: colorMatrix,
                pixelFormat: pixelFormat
            )
        } catch {
            print("❌ Error analyzing video specs: \(error)")
            return nil
        }
    }
    
    private func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes = withUnsafeBytes(of: fourCC.bigEndian) { Array($0) }
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
    }
    
    private func getColorPrimaries(from formatDescription: CMFormatDescription) -> String? {
        guard let primaries = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
        ) else { return nil }
        
        if CFEqual(primaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2) {
            return "ITU-R BT.709"
        } else if CFEqual(primaries, kCMFormatDescriptionColorPrimaries_ITU_R_2020) {
            return "ITU-R BT.2020"
        }
        
        return String(describing: primaries)
    }
    
    private func getTransferFunction(from formatDescription: CMFormatDescription) -> String? {
        guard let transfer = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_TransferFunction
        ) else { return nil }
        
        if CFEqual(transfer, kCMFormatDescriptionTransferFunction_ITU_R_709_2) {
            return "ITU-R BT.709"
        } else if CFEqual(transfer, kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ) {
            return "SMPTE ST 2084 (PQ)"
        } else if CFEqual(transfer, kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG) {
            return "ITU-R BT.2100 HLG"
        }
        
        return String(describing: transfer)
    }
    
    private func getColorMatrix(from formatDescription: CMFormatDescription) -> String? {
        guard let matrix = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: kCMFormatDescriptionExtension_YCbCrMatrix
        ) else { return nil }
        
        if CFEqual(matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2) {
            return "ITU-R BT.709"
        } else if CFEqual(matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_2020) {
            return "ITU-R BT.2020"
        }
        
        return String(describing: matrix)
    }
    
    private func getPixelFormat(from formatDescription: CMFormatDescription) -> String? {
        let pixelFormat = CMFormatDescriptionGetMediaSubType(formatDescription)
        return fourCCToString(pixelFormat)
    }
    
    func predictOutputVideoSpecs(
        at index: Int,
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        qualitySettings: QualitySettings
    ) async {
        guard index < queuedFiles.count else { return }
        
        let item = queuedFiles[index]
        guard let inputSpecs = item.inputVideoSpecs else { return }
        
        let predictedSpecs = await generatePredictedSpecs(
            inputSpecs: inputSpecs,
            projectionFormat: projectionFormat,
            stereoscopicMode: stereoscopicMode,
            qualitySettings: qualitySettings
        )
        
        await MainActor.run {
            if index < self.queuedFiles.count {
                self.queuedFiles[index].outputVideoSpecs = predictedSpecs
            }
        }
    }
    
    func predictAllOutputSpecs(
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        qualitySettings: QualitySettings
    ) async {
        for index in 0..<queuedFiles.count {
            await predictOutputVideoSpecs(
                at: index,
                projectionFormat: projectionFormat,
                stereoscopicMode: stereoscopicMode,
                qualitySettings: qualitySettings
            )
        }
    }
    
    private func generatePredictedSpecs(
        inputSpecs: VideoSpecifications,
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        qualitySettings: QualitySettings
    ) async -> VideoSpecifications {
        
        // Determine output codec
        let outputCodec = (stereoscopicMode == .sideBySide || stereoscopicMode == .topBottom) ? "hvc1" : "hvc1"
        // Note: Both use HEVC, but stereo content gets encoded as MV-HEVC internally
        
        // Calculate output resolution
        let outputResolution = calculateOutputResolution(
            inputResolution: inputSpecs.resolution,
            projectionFormat: projectionFormat,
            stereoscopicMode: stereoscopicMode
        )
        
        // Preserve frame rate
        let outputFrameRate = inputSpecs.frameRate
        
        // Use user-selected bitrate
        let outputBitrate = Int64(qualitySettings.bitrateBps)
        
        // Determine if HDR will be preserved
        let willPreserveHDR = inputSpecs.isHDR
        let outputColorPrimaries = willPreserveHDR ? inputSpecs.colorPrimaries : "ITU-R BT.709"
        let outputTransferFunction = willPreserveHDR ? inputSpecs.transferFunction : "ITU-R BT.709"
        let outputColorMatrix = willPreserveHDR ? inputSpecs.colorMatrix : "ITU-R BT.709"
        
        print("🔮 Predicted output specs: \(outputCodec) • \(Int(outputResolution.width))×\(Int(outputResolution.height)) • \(outputFrameRate) fps • \(qualitySettings.bitrateFormatted)")
        
        return VideoSpecifications(
            codec: outputCodec,
            resolution: outputResolution,
            frameRate: outputFrameRate,
            bitrate: outputBitrate,
            colorPrimaries: outputColorPrimaries,
            transferFunction: outputTransferFunction,
            colorMatrix: outputColorMatrix,
            pixelFormat: "420v" // HEVC 4:2:0
        )
    }
    
    private func calculateOutputResolution(
        inputResolution: CGSize,
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode
    ) -> CGSize {
        
        var outputResolution = inputResolution
        
        // Handle stereoscopic unpacking
        switch stereoscopicMode {
        case .sideBySide:
            // Side-by-side gets unpacked to individual eye frames
            outputResolution.width = inputResolution.width / 2
        case .topBottom:
            // Top-bottom gets unpacked to individual eye frames
            outputResolution.height = inputResolution.height / 2
        case .mono, .auto:
            // No change for monoscopic
            break
        }
        
        // APMP conversion typically maintains resolution
        // but we could add logic here for any specific APMP requirements
        
        return outputResolution
    }
    
    // MARK: - Validation
    
    func validateSettings(
        projectionFormat: ProjectionFormat,
        stereoscopicMode: StereoscopicMode,
        qualitySettings: QualitySettings
    ) -> [String] {
        var warnings: [String] = []
        
        // Check bitrate recommendations
        if qualitySettings.bitrateMbps < 60 {
            warnings.append("Bitrate below 60 Mbps may result in quality loss for immersive content")
        }
        
        // Check for auto-detection with insufficient info
        if projectionFormat == .auto && stereoscopicMode == .auto {
            warnings.append("Both projection and stereoscopic mode are set to auto-detect - ensure source metadata is accurate")
        }
        
        // Check for potential resolution issues
        for item in queuedFiles {
            if let inputSpecs = item.inputVideoSpecs {
                if inputSpecs.resolution.width < 1920 {
                    warnings.append("Input resolution \(inputSpecs.resolutionFormatted) is below recommended minimum for immersive content")
                }
                
                if inputSpecs.frameRate < 24 {
                    warnings.append("Input frame rate \(inputSpecs.frameRateFormatted) is below recommended minimum")
                }
            }
        }
        
        return warnings
    }
}