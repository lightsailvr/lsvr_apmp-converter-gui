# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Apple sample code project that demonstrates converting projected video content to Apple Projected Media Profile (APMP). The project is associated with WWDC25 session 297 and converts equirectangular or half-equirectangular video to APMP format.

**Current Status**: The project has been extended with a full SwiftUI GUI application that provides an intuitive interface for batch video conversion. The GUI includes drag & drop support, conversion queue management, progress tracking, and modern macOS design.

## Build and Run Commands

**Build the project:**
```bash
xcodebuild -project ProjectedMediaConversion.xcodeproj -scheme ProjectedMediaConversion -configuration Debug build
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

- The project uses Xcode 16.0+ (LastUpgradeVersion = "2600")
- Swift concurrency is used throughout (`async`/`await`)
- The scheme includes sample command-line arguments for testing
- Sample video file: `Lighthouse_sbs.mp4` (side-by-side stereoscopic)
- Output files are named with `_apmp.mov` suffix
- **Project Type**: Changed from command-line tool to macOS SwiftUI application
- **Target**: macOS 26.0+ with Swift 6.0
- **Window Size**: Default 1000×700 pixels, suitable for 1080p displays

## Development Guidelines

When extending this project with UI components or additional features:

- **UI Framework**: Aim to build all functionality using SwiftUI unless there is a feature that is only supported in AppKit
- **Design**: Design UI in a way that is idiomatic for the macOS platform and follows Apple Human Interface Guidelines
- **Icons**: Use SF Symbols for iconography
- **APIs**: Use the most modern macOS APIs. Since there is no backward compatibility constraint, this app can target the latest macOS version with the newest APIs
- **Swift Language**: Use the most modern Swift language features and conventions. Target Swift 6 and use Swift concurrency (async/await, actors) and Swift macros where applicable

## Known Issues & Audio Integration Status

### Audio Preservation Challenge

**Issue**: The original Apple sample code only processes video tracks, stripping audio from source files during APMP conversion.

**Goal**: Preserve original audio in the converted APMP files to maintain complete immersive media experience.

### Attempted Solutions

#### Approach 1: Concurrent Audio/Video Processing (FAILED)
- **Method**: Modified `APMPConverter` to handle both video and audio tracks simultaneously
- **Implementation**: Added `AVAssetReaderTrackOutput` for audio, concurrent processing with video
- **Failure**: Caused AudioQueue errors (`Error (-4) getting reporterIDs`), app freezing, and unplayable output files
- **Root Cause**: Complex concurrency issues between video compression and audio processing

#### Approach 2: Sequential Audio/Video Processing (FAILED) 
- **Method**: Process video first, then audio, then combine in `AVAssetWriter`
- **Implementation**: Modified processing order to eliminate race conditions
- **Failure**: Still encountered AudioQueue issues and freezing during finalization
- **Root Cause**: `AVAssetWriter` complexity when handling both APMP video encoding and audio streams

#### Approach 3: Extract-Convert-Recombine Workflow (IN PROGRESS)
- **Method**: 
  1. Extract audio to temporary M4A file using `AVAssetExportSession`
  2. Convert video-only to APMP format (original workflow)
  3. Recombine APMP video + audio using `AVMutableComposition`
- **Status**: Implementation complete but still experiencing issues
- **Current Blockers**: 
  - Audio extraction working
  - Video conversion working
  - Recombination step needs debugging

### Recommendations for Future Work

1. **Debug Recombination**: Focus on the `AVMutableComposition` step - verify track insertion and export session configuration
2. **Alternative Tools**: Consider using `ffmpeg` via process execution for audio handling
3. **Metadata Preservation**: Ensure APMP-specific metadata survives the recombination process
4. **Simpler Approach**: Create video-only APMP files and provide separate audio workflow
5. **Testing**: Use shorter test videos to isolate issues faster

### Current Workaround

The application currently processes video-only and produces working APMP files without audio. This is functional for testing the UI and video conversion pipeline, but audio preservation remains an open issue.

## Testing

No explicit test framework is configured. Test conversions using:
- The included sample video
- Different projection types and view packing configurations
- Various command-line argument combinations
- **Note**: Audio testing requires videos with audio tracks to verify preservation attempts