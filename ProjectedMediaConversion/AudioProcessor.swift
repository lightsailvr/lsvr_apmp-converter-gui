/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Audio processing pipeline for handling ambisonic audio and APAC encoding.
*/

import Foundation
import AVFoundation
import CoreMedia

class AudioProcessor {
    
    /// Processes audio for the given video file with the specified audio configuration
    /// - Parameters:
    ///   - videoURL: The APMP video file (without audio)
    ///   - sourceVideoURL: The original video file (may contain audio)
    ///   - audioConfiguration: Audio processing configuration
    ///   - progressCallback: Callback for progress updates (0.0 to 1.0)
    ///   - statusCallback: Callback for status updates
    /// - Returns: URL to the final video file with audio
    func processAudio(
        videoURL: URL,
        sourceVideoURL: URL,
        audioConfiguration: AudioConfiguration,
        progressCallback: @escaping (Double) -> Void,
        statusCallback: @escaping (AudioProcessingStatus) -> Void
    ) async throws -> URL {
        
        let finalOutputURL = videoURL.deletingPathExtension().appendingPathExtension("mov")
        
        // Step 1: Analyze audio requirements
        statusCallback(.analyzing)
        progressCallback(0.1)
        
        let audioSource = try await determineAudioSource(
            sourceVideoURL: sourceVideoURL,
            audioConfiguration: audioConfiguration
        )
        
        // Step 2: Extract/prepare audio
        statusCallback(.extracting)
        progressCallback(0.3)
        
        let audioURL = try await extractAudio(from: audioSource)
        
        // Step 3: Encode to APAC if needed
        statusCallback(.encoding)
        progressCallback(0.6)
        
        let apacAudioURL = try await encodeToAPAC(
            audioURL: audioURL,
            audioConfiguration: audioConfiguration
        )
        
        // Step 4: Mux with video
        statusCallback(.muxing)
        progressCallback(0.8)
        
        let finalURL = try await muxAudioWithVideo(
            videoURL: videoURL,
            audioURL: apacAudioURL,
            outputURL: finalOutputURL
        )
        
        // Cleanup temporary files
        try? FileManager.default.removeItem(at: audioURL)
        if apacAudioURL != audioURL {
            try? FileManager.default.removeItem(at: apacAudioURL)
        }
        
        statusCallback(.completed)
        progressCallback(1.0)
        
        return finalURL
    }
    
    private func determineAudioSource(
        sourceVideoURL: URL,
        audioConfiguration: AudioConfiguration
    ) async throws -> AudioSource {
        
        if let externalAudioURL = audioConfiguration.externalAudioURL {
            // Use external audio file
            let channels = try await detectChannelCount(from: externalAudioURL)
            let detectedOrder = ambisonicOrderFromChannels(channels)
            
            return AudioSource(
                url: externalAudioURL,
                channels: channels,
                ambisonicOrder: detectedOrder,
                isExternal: true
            )
        } else {
            // Use source video audio
            let asset = AVURLAsset(url: sourceVideoURL)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            
            guard let audioTrack = audioTracks.first else {
                throw AudioProcessingError.noAudioFound
            }
            
            let channels = try await detectChannelCountFromTrack(audioTrack)
            let detectedOrder = ambisonicOrderFromChannels(channels)
            
            return AudioSource(
                url: sourceVideoURL,
                channels: channels,
                ambisonicOrder: detectedOrder,
                isExternal: false
            )
        }
    }
    
    private func extractAudio(from source: AudioSource) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioOutputURL = tempDir.appendingPathComponent("extracted_audio.m4a")
        
        // Remove existing temp file
        try? FileManager.default.removeItem(at: audioOutputURL)
        
        let asset = AVURLAsset(url: source.url)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = audioOutputURL
        exportSession.outputFileType = .m4a
        
        // Export only audio
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let composition = AVMutableComposition()
            let audioCompositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            let duration = try await asset.load(.duration)
            try audioCompositionTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTracks.first!,
                at: .zero
            )
            
            exportSession.assetForExport = composition
        }
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw AudioProcessingError.audioExtractionFailed(error)
        }
        
        return audioOutputURL
    }
    
    private func encodeToAPAC(
        audioURL: URL,
        audioConfiguration: AudioConfiguration
    ) async throws -> URL {
        
        let channels = try await detectChannelCount(from: audioURL)
        
        // Only encode to APAC if it's ambisonic (4, 9, or 16 channels)
        guard channels == 4 || channels == 9 || channels == 16 else {
            print("🔊 Audio has \(channels) channels, not encoding to APAC")
            return audioURL
        }
        
        print("🔊 Encoding \(channels)-channel audio to APAC...")
        
        let tempDir = FileManager.default.temporaryDirectory
        let apacOutputURL = tempDir.appendingPathComponent("apac_audio.m4a")
        
        // Remove existing temp file
        try? FileManager.default.removeItem(at: apacOutputURL)
        
        let asset = AVURLAsset(url: audioURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let audioTrack = audioTracks.first else {
            throw AudioProcessingError.noAudioTrackFound
        }
        
        // Get audio properties
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw AudioProcessingError.noAudioFormatFound
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let streamDescription = audioStreamBasicDescription else {
            throw AudioProcessingError.audioFormatParsingFailed
        }
        
        let sampleRate = streamDescription.pointee.mSampleRate
        let channelLayout = try await getChannelLayout(from: audioTrack)
        
        // Create APAC encoder settings
        let apacSettings = createAPACSettings(
            channels: channels,
            sampleRate: sampleRate,
            channelLayout: channelLayout
        )
        
        // Use AVAssetWriter to encode with APAC
        let writer = try AVAssetWriter(outputURL: apacOutputURL, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: apacSettings)
        
        guard writer.canAdd(writerInput) else {
            throw AudioProcessingError.cannotAddWriterInput
        }
        
        writer.add(writerInput)
        
        // Create reader
        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        
        guard reader.canAdd(readerOutput) else {
            throw AudioProcessingError.cannotAddReaderOutput
        }
        
        reader.add(readerOutput)
        
        // Start encoding
        guard writer.startWriting() && reader.startReading() else {
            throw AudioProcessingError.encodingStartFailed
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // Process audio samples
        let processingQueue = DispatchQueue(label: "audio.processing")
        
        await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: processingQueue) {
                while writerInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                    
                    if !writerInput.append(sampleBuffer) {
                        reader.cancelReading()
                        continuation.resume()
                        return
                    }
                }
            }
        }
        
        await writer.finishWriting()
        
        if let error = writer.error {
            throw AudioProcessingError.apacEncodingFailed(error)
        }
        
        return apacOutputURL
    }
    
    private func muxAudioWithVideo(
        videoURL: URL,
        audioURL: URL,
        outputURL: URL
    ) async throws -> URL {
        
        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)
        
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw AudioProcessingError.noVideoTrackFound
        }
        
        let videoCompositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let videoDuration = try await videoAsset.load(.duration)
        try videoCompositionTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )
        
        // Add audio track
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw AudioProcessingError.noAudioTrackFound
        }
        
        let audioCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let audioDuration = try await audioAsset.load(.duration)
        let finalDuration = min(videoDuration, audioDuration)
        
        try audioCompositionTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: finalDuration),
            of: audioTrack,
            at: .zero
        )
        
        // Export final composition
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHEVCHighestQuality
        ) else {
            throw AudioProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw AudioProcessingError.muxingFailed(error)
        }
        
        return outputURL
    }
    
    // MARK: - Helper Methods
    
    private func detectChannelCount(from url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let audioTrack = audioTracks.first else {
            throw AudioProcessingError.noAudioTrackFound
        }
        
        return try await detectChannelCountFromTrack(audioTrack)
    }
    
    private func detectChannelCountFromTrack(_ audioTrack: AVAssetTrack) async throws -> Int {
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        
        guard let formatDescription = formatDescriptions.first else {
            throw AudioProcessingError.noAudioFormatFound
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        
        guard let streamDescription = audioStreamBasicDescription else {
            throw AudioProcessingError.audioFormatParsingFailed
        }
        
        return Int(streamDescription.pointee.mChannelsPerFrame)
    }
    
    private func ambisonicOrderFromChannels(_ channels: Int) -> AmbisonicOrder? {
        switch channels {
        case 4:
            return .first
        case 9:
            return .second
        case 16:
            return .third
        default:
            return nil
        }
    }
    
    private func getChannelLayout(from audioTrack: AVAssetTrack) async throws -> AudioChannelLayout? {
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        
        guard let formatDescription = formatDescriptions.first else {
            return nil
        }
        
        return CMAudioFormatDescriptionGetChannelLayout(formatDescription, sizeOut: nil)
    }
    
    private func createAPACSettings(
        channels: Int,
        sampleRate: Double,
        channelLayout: AudioChannelLayout?
    ) -> [String: Any] {
        
        var settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAPAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderContentSourceKey: AVAudioContentSource.appleAV_Spatial_Offline.rawValue,
            AVEncoderDynamicRangeControlConfigurationKey: AVAudioDynamicRangeControlConfiguration.movie.rawValue,
            AVEncoderASPFrequencyKey: 75
        ]
        
        if let channelLayout = channelLayout {
            settings[AVChannelLayoutKey] = channelLayout
        }
        
        return settings
    }
}

// MARK: - Supporting Types

private struct AudioSource {
    let url: URL
    let channels: Int
    let ambisonicOrder: AmbisonicOrder?
    let isExternal: Bool
}

enum AudioProcessingError: Error, LocalizedError {
    case noAudioFound
    case noAudioTrackFound
    case noVideoTrackFound
    case noAudioFormatFound
    case audioFormatParsingFailed
    case exportSessionCreationFailed
    case audioExtractionFailed(Error)
    case apacEncodingFailed(Error)
    case muxingFailed(Error)
    case encodingStartFailed
    case cannotAddWriterInput
    case cannotAddReaderOutput
    
    var errorDescription: String? {
        switch self {
        case .noAudioFound:
            return "No audio found in source"
        case .noAudioTrackFound:
            return "No audio track found"
        case .noVideoTrackFound:
            return "No video track found"
        case .noAudioFormatFound:
            return "No audio format found"
        case .audioFormatParsingFailed:
            return "Failed to parse audio format"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .audioExtractionFailed(let error):
            return "Audio extraction failed: \(error.localizedDescription)"
        case .apacEncodingFailed(let error):
            return "APAC encoding failed: \(error.localizedDescription)"
        case .muxingFailed(let error):
            return "Audio muxing failed: \(error.localizedDescription)"
        case .encodingStartFailed:
            return "Failed to start encoding"
        case .cannotAddWriterInput:
            return "Cannot add writer input"
        case .cannotAddReaderOutput:
            return "Cannot add reader output"
        }
    }
}