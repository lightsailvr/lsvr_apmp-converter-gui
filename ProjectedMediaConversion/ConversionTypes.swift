/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Types and enums for the Projected Media Conversion application.
*/

import Foundation

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