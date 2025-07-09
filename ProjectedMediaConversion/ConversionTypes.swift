/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Types and enums for the Projected Media Conversion application.
*/

import Foundation
import AVFoundation

enum AmbisonicOrder: String, CaseIterable {
    case first = "1st"
    case second = "2nd" 
    case third = "3rd"
    
    var displayName: String {
        switch self {
        case .first:
            return "1st Order (4 channels)"
        case .second:
            return "2nd Order (9 channels)"
        case .third:
            return "3rd Order (16 channels)"
        }
    }
    
    var channelCount: Int {
        switch self {
        case .first:
            return 4
        case .second:
            return 9
        case .third:
            return 16
        }
    }
}

struct AudioConfiguration {
    var externalAudioURL: URL?
    var detectedOrder: AmbisonicOrder?
    var overrideOrder: AmbisonicOrder?
    var shouldOverrideExisting: Bool = true
    
    var effectiveOrder: AmbisonicOrder? {
        return overrideOrder ?? detectedOrder
    }
    
    var hasExternalAudio: Bool {
        return externalAudioURL != nil
    }
}

enum AudioProcessingStatus {
    case pending
    case analyzing
    case extracting
    case encoding
    case muxing
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .analyzing:
            return "Analyzing Audio"
        case .extracting:
            return "Extracting Audio"
        case .encoding:
            return "Encoding APAC"
        case .muxing:
            return "Muxing Audio"
        case .completed:
            return "Audio Complete"
        case .failed:
            return "Audio Failed"
        }
    }
}

enum ProjectionFormat: String, CaseIterable {
    case auto = "auto"
    case equirectangular = "equirectangular"
    case halfEquirectangular = "halfequirectangular"
    
    var displayName: String {
        switch self {
        case .auto:
            return "Auto-Detect"
        case .equirectangular:
            return "360° (Equirectangular)"
        case .halfEquirectangular:
            return "180° (Half-Equirectangular)"
        }
    }
    
    var commandLineValue: String? {
        switch self {
        case .auto:
            return nil
        case .equirectangular:
            return "Equirectangular"
        case .halfEquirectangular:
            return "HalfEquirectangular"
        }
    }
}

enum StereoscopicMode: String, CaseIterable {
    case auto = "auto"
    case mono = "mono"
    case sideBySide = "sidebyside"
    case topBottom = "topbottom"
    
    var displayName: String {
        switch self {
        case .auto:
            return "Auto-Detect"
        case .mono:
            return "Monoscopic"
        case .sideBySide:
            return "Side-by-Side"
        case .topBottom:
            return "Top-Bottom"
        }
    }
    
    var commandLineValue: String? {
        switch self {
        case .auto, .mono:
            return nil
        case .sideBySide:
            return "SideBySide"
        case .topBottom:
            return "OverUnder"
        }
    }
}

struct ConversionItem: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var status: ConversionStatus = .pending
    var progress: Double = 0.0
    var outputURL: URL?
    var error: Error?
    var bytesProcessed: Int64 = 0
    var totalBytes: Int64 = 0
    var estimatedTimeRemaining: TimeInterval = 0
    var startTime: Date?
    
    // Audio processing properties
    var audioConfiguration: AudioConfiguration = AudioConfiguration()
    var audioStatus: AudioProcessingStatus = .pending
    var audioProgress: Double = 0.0
    var videoProgress: Double = 0.0
    var detectedAudioChannels: Int = 0
    var audioProcessingError: Error?
    
    // Video specifications
    var inputVideoSpecs: VideoSpecifications?
    var outputVideoSpecs: VideoSpecifications?
    
    var filename: String {
        sourceURL.lastPathComponent
    }
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var bytesProcessedFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytesProcessed, countStyle: .file)
    }
    
    var estimatedTimeRemainingFormatted: String {
        if estimatedTimeRemaining <= 0 { return "" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: estimatedTimeRemaining) ?? ""
    }
    
    var hasAudioConfiguration: Bool {
        return audioConfiguration.hasExternalAudio || detectedAudioChannels > 0
    }
    
    var audioStatusDescription: String {
        if audioConfiguration.hasExternalAudio {
            return "External: \(audioConfiguration.effectiveOrder?.displayName ?? "Unknown")"
        } else if detectedAudioChannels > 0 {
            return "Source: \(detectedAudioChannels) channels"
        } else {
            return "No audio"
        }
    }
}

enum ConversionStatus {
    case pending
    case processing
    case completed
    case failed
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pending:
            return "clock"
        case .processing:
            return "gear"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
}

struct ProjectedMediaMetadata {
    var projectionKind: String
    var viewPackingKind: String?		 // optional, only for frame-packed source
    var baselineInMillimeters: Double?   // optional, only if stereoscopic
    var horizontalFOV: Double?           // optional
}

struct ConversionError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}

// MARK: - Video Specifications

struct VideoSpecifications {
    let codec: String
    let resolution: CGSize
    let frameRate: Double
    let bitrate: Int64?
    let colorPrimaries: String?
    let transferFunction: String?
    let colorMatrix: String?
    let pixelFormat: String?
    
    var isHDR: Bool {
        return transferFunction?.contains("2084") == true || 
               transferFunction?.contains("PQ") == true ||
               transferFunction?.contains("ST2084") == true
    }
    
    var colorSpaceDescription: String {
        if isHDR {
            return "HDR (ST2084/PQ)"
        } else if colorPrimaries?.contains("709") == true {
            return "SDR (Rec.709)"
        } else if colorPrimaries?.contains("2020") == true {
            return "Wide Gamut (Rec.2020)"
        } else {
            return colorPrimaries ?? "Unknown"
        }
    }
    
    var bitrateFormatted: String {
        guard let bitrate = bitrate else { return "Unknown" }
        let mbps = Double(bitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
    
    var resolutionFormatted: String {
        return "\(Int(resolution.width))×\(Int(resolution.height))"
    }
    
    var frameRateFormatted: String {
        return String(format: "%.2f fps", frameRate)
    }
}

// MARK: - Quality Settings

struct QualitySettings {
    var bitrateMbps: Int = 75 // Default 75 Mbps for immersive content
    var quality: Double = 0.9 // High quality (0.0-1.0)
    
    var bitrateFormatted: String {
        return "\(bitrateMbps) Mbps"
    }
    
    var bitrateBps: Int {
        return bitrateMbps * 1_000_000
    }
    
    static let bitrateRange = 50...120 // Mbps range for immersive content
}

