# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Apple sample code project that demonstrates converting projected video content to Apple Projected Media Profile (APMP). The project is associated with WWDC25 session 297 and converts equirectangular or half-equirectangular video to APMP format.

**Current Status**: The project has been extended with a full SwiftUI GUI application that provides an intuitive interface for batch video conversion. The GUI includes drag & drop support, conversion queue management, progress tracking, and modern macOS design.

## Build and Run Commands

**IMPORTANT: Development Environment Requirements**
- **macOS**: macOS 26.0 Developer Beta (required)
- **Xcode**: Xcode Beta located at `/Applications/Xcode-beta.app` (required)
- **Modern APIs**: This project uses cutting-edge APIs only available in the latest developer betas
- **DO NOT downgrade deployment targets** - always use the newest available APIs and resolve build errors with modern approaches

**Build the project:**
```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -project ProjectedMediaConversion.xcodeproj -scheme ProjectedMediaConversion -configuration Debug build
```

**Run from command line after building:**
```bash
./build/Debug/ProjectedMediaConversion <video_file_path> [options]
```

**Run in Xcode:**
- Click Run button to convert the included sample (`Lighthouse_sbs.mp4`)
- Or edit scheme arguments: Product > Scheme > Edit Scheme > Arguments tab

## Command Line Options

- `--autoDetect` or `-a`: Auto-detect spherical metadata compatible with APMP
- `--projectionKind <kind>` or `-p`: Specify projection (`equirectangular` or `halfequirectangular`)
- `--viewPackingKind <kind>` or `-v`: Specify frame-packing (`sidebyside` or `overunder`)
- `--baseline <mm>` or `-b`: Stereo baseline in millimeters
- `--fov <degrees>` or `-f`: Horizontal field of view in degrees

## Architecture

The project consists of three main Swift files:

### Core Components

1. **ProjectedMediaConversion.swift** - Main entry point using Swift ArgumentParser
   - Handles command-line argument parsing
   - Orchestrates the conversion process
   - Uses `ProjectedMediaClassifier` for auto-detection
   - Uses `APMPConverter` for the actual conversion

2. **ProjectedMediaClassifier.swift** - Video format analysis
   - Detects existing APMP compliance
   - Identifies projection types (equirectangular, half-equirectangular, parametric immersive)
   - Determines view packing (side-by-side, over-under)
   - Checks for HEVC codec and frame-packing

3. **Converter.swift** - Video transcoding engine
   - Handles monoscopic and stereoscopic video processing
   - Performs frame-packing conversion (side-by-side, over-under)
   - Implements MV-HEVC encoding for stereo content
   - Manages pixel buffer operations and video compression

### Key Technical Details

- **Dependencies**: Uses Swift ArgumentParser from Apple
- **Video Processing**: Built on AVFoundation, CoreMedia, and VideoToolbox
- **Output Format**: QuickTime (.mov) files with HEVC or MV-HEVC codec
- **Stereo Support**: MV-HEVC with layer IDs [0, 1] for left/right eyes
- **Projection Types**: Equirectangular and half-equirectangular supported

### File Structure

```
ProjectedMediaConversion/
├── ProjectedMediaConversionApp.swift     # SwiftUI App entry point
├── ContentView.swift                     # Main window layout and coordination
├── ConversionTypes.swift                 # Enums and data structures
├── ConversionManager.swift               # Queue management and conversion coordination
├── FileDropView.swift                    # Drag & drop interface
├── ConversionQueueView.swift             # Queue display and management UI
├── ProjectedMediaConversionCLI.swift     # Original CLI entry point (renamed)
├── ProjectedMediaClassifier.swift        # Video format detection
└── Converter.swift                       # Video transcoding logic
```

## Development Notes

- **Development Environment**: macOS 26.0 Developer Beta with Xcode Beta
- **Modern APIs**: Uses latest AVFoundation, CoreMedia, and VideoToolbox APIs
- **Swift concurrency**: Uses modern async/await patterns throughout
- **Project Type**: macOS SwiftUI application targeting the latest platform features
- **Target**: macOS 26.0+ with Swift 6.0 (cutting-edge features required)
- **Window Size**: Default 1000×700 pixels, suitable for 1080p displays
- **API Philosophy**: Always use the most modern APIs available - never downgrade for compatibility

## Development Guidelines

When extending this project with UI components or additional features:

- **UI Framework**: Aim to build all functionality using SwiftUI unless there is a feature that is only supported in AppKit
- **Design**: Design UI in a way that is idiomatic for the macOS platform and follows Apple Human Interface Guidelines
- **Icons**: Use SF Symbols for iconography
- **APIs**: Use the most modern macOS APIs. Since there is no backward compatibility constraint, this app can target the latest macOS version with the newest APIs
- **Swift Language**: Use the most modern Swift language features and conventions. Target Swift 6 and use Swift concurrency (async/await, actors) and Swift macros where applicable

## Audio Processing Implementation

### Audio Preservation Status: **COMPLETED ✅**

The application now successfully preserves audio from source files during APMP conversion using an intelligent dual-pipeline approach.

### Implementation Overview

The audio processing system automatically detects audio characteristics and selects the appropriate processing pipeline:

#### Pipeline 1: Direct Export (Stereo Audio)
- **Used for**: 2-channel stereo audio from source video
- **Method**: Direct composition using `AVMutableComposition`
- **Process**:
  1. Creates composition combining APMP video track + original stereo audio track
  2. Exports using `AVAssetExportSession` with highest quality preset
  3. No re-encoding of audio - preserves original quality
- **Benefits**: Fast, reliable, preserves audio quality, no temporary files

#### Pipeline 2: Extract-Encode-Mux (Ambisonic Audio)
- **Used for**: 4, 9, or 16-channel ambisonic audio (external or source)
- **Method**: Advanced APAC encoding pipeline
- **Process**:
  1. Extract audio to temporary M4A file
  2. Encode to APAC (Apple Projected Audio Codec) format
  3. Mux APAC audio with APMP video using `AVMutableComposition`
- **Benefits**: Supports spatial audio standards, maintains ambisonic metadata

### Key Features

- **Automatic Detection**: Analyzes source audio and selects optimal processing path
- **File Conflict Prevention**: Intelligent output naming prevents overwriting input files
- **Comprehensive Error Handling**: Detailed error reporting and debugging capabilities
- **Progress Tracking**: Real-time progress updates for both video and audio processing
- **Quality Preservation**: No unnecessary re-encoding for stereo content

### Audio Configuration Options

The GUI provides controls for:
- **External Audio Files**: Import separate ambisonic audio files
- **Ambisonic Order Override**: Manual specification of spatial audio order (1st, 2nd, 3rd)
- **Automatic Detection**: System detects audio characteristics from source files
- **Quality Settings**: Maintains highest quality for all audio types

### Technical Implementation

**Key Files:**
- `AudioProcessor.swift`: Main audio processing logic with dual pipelines
- `ConversionTypes.swift`: Audio configuration data structures
- `ConversionManager.swift`: Orchestrates video/audio processing coordination

**Modern API Usage:**
- Latest AVFoundation async/await patterns
- Swift 6.0 concurrency with `@Sendable` closures
- macOS 26.0 beta SDK compatibility

## Testing

Test conversions using various content types:
- **Stereo Video**: Standard 2-channel audio videos to test direct export pipeline
- **Ambisonic Content**: 4, 9, or 16-channel spatial audio files to test APAC encoding
- **Different Projections**: Equirectangular and half-equirectangular formats
- **Various Formats**: Different input video codecs and containers
- **External Audio**: Separate ambisonic audio files with video conversion

**Audio Testing Notes:**
- Stereo audio preserves original quality without re-encoding
- Ambisonic audio gets converted to APAC format for Apple spatial audio compliance
- Progress tracking shows separate video and audio processing phases
- Error handling provides detailed diagnostics for audio processing issues