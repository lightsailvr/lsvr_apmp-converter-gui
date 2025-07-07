# APMP Converter GUI

A SwiftUI application for converting projected video content to Apple Projected Media Profile (APMP) format with intelligent audio preservation. This app provides an intuitive graphical interface for batch video conversion with drag & drop support, conversion queue management, and comprehensive audio processing.

## What This App Does

The APMP Converter GUI transforms 360° and 180° immersive video content into Apple's Projected Media Profile format, making it compatible with Apple's immersive media ecosystem. The app supports:

- **Monoscopic and stereoscopic video conversion**
- **Multiple projection types**: Equirectangular and half-equirectangular
- **Frame-packing modes**: Side-by-side and over-under stereoscopic layouts
- **Automatic format detection** from video metadata
- **Intelligent audio preservation** with dual-pipeline processing
- **Spatial audio support** with APAC encoding for ambisonic content
- **Batch processing** with conversion queue management
- **Modern macOS design** with drag & drop interface

## How to Use

### Getting Started

1. **Build and run** the project in Xcode 16.0+
2. The app opens with a clean interface showing a file drop zone

### Converting Videos

**Method 1: Drag & Drop**
- Drag video files directly onto the drop zone
- The app will automatically detect supported formats
- Files are added to the conversion queue

**Method 2: File Selection**
- Click "Select Files" to browse for video files
- Choose one or multiple video files
- Files are added to the conversion queue

### Conversion Settings

For each video in the queue, you can configure:

**Video Settings:**
- **Auto-detect**: Let the app analyze video metadata automatically
- **Projection Type**: Choose between equirectangular or half-equirectangular
- **View Packing**: Select side-by-side or over-under for stereoscopic content
- **Baseline**: Set stereo baseline in millimeters (for stereoscopic video)
- **Field of View**: Specify horizontal FOV in degrees

**Audio Settings:**
- **Automatic Detection**: App automatically detects and preserves source audio
- **External Audio Files**: Import separate ambisonic audio files (4, 9, or 16 channels)
- **Ambisonic Order Override**: Manually specify spatial audio order (1st, 2nd, 3rd order)
- **Quality Preservation**: Stereo audio preserved without re-encoding

### Processing Videos

1. **Review** your conversion queue
2. **Adjust settings** for each video as needed
3. **Click "Start Conversion"** to begin batch processing
4. **Monitor progress** with real-time progress indicators
5. **Find converted files** in the same directory as source files (with `_apmp.mov` suffix)

## Supported Input Formats

**Video:**
- **Video codecs**: H.264, HEVC, and other AVFoundation-compatible formats
- **Projections**: Equirectangular (360°) and half-equirectangular (180°)
- **Stereoscopic layouts**: Side-by-side and over-under frame packing
- **File formats**: Most QuickTime-compatible video files

**Audio:**
- **Stereo Audio**: Standard 2-channel audio (preserved without re-encoding)
- **Ambisonic Audio**: 4-channel (1st order), 9-channel (2nd order), 16-channel (3rd order)
- **External Audio**: Separate ambisonic audio files (.m4a, .wav, .aiff)
- **Source Audio**: Audio tracks embedded in source video files

## Output Format

**Video:**
- **Container**: QuickTime (.mov)
- **Video codec**: HEVC for monoscopic, MV-HEVC for stereoscopic
- **Metadata**: Apple Projected Media Profile compliant

**Audio:**
- **Stereo**: Preserved in original format for maximum quality
- **Ambisonic**: Encoded to APAC (Apple Projected Audio Codec) format
- **Synchronization**: Audio perfectly synchronized with video tracks

**Filename:** Original name with `_apmp.mov` suffix

## System Requirements

- **macOS**: 26.0 Developer Beta or later (required for latest APIs)
- **Xcode**: Xcode Beta at `/Applications/Xcode-beta.app` (required)
- **Swift**: 6.0 with modern concurrency support
- **Architecture**: Apple Silicon and Intel Macs supported

## Audio Processing Implementation

### How Audio Processing Works

The app uses an intelligent dual-pipeline approach for audio processing:

**Pipeline 1: Direct Export (Stereo Audio)**
- **Detection**: Automatically identifies 2-channel stereo audio
- **Processing**: Creates direct composition of APMP video + original stereo audio
- **Benefits**: Fast processing, no quality loss, no temporary files
- **Use Case**: Standard stereo video content

**Pipeline 2: Extract-Encode-Mux (Ambisonic Audio)**
- **Detection**: Identifies 4, 9, or 16-channel spatial audio
- **Processing**: Extracts audio → Encodes to APAC → Muxes with APMP video
- **Benefits**: Full spatial audio support, Apple standards compliant
- **Use Case**: Ambisonic/spatial audio content

### Audio Processing Features

- **Automatic Detection**: Analyzes source files to determine optimal processing path
- **Error Prevention**: Intelligent file naming prevents conflicts and overwrites
- **Progress Tracking**: Real-time updates for both video and audio processing phases
- **Quality Preservation**: Maintains original audio quality whenever possible
- **Comprehensive Logging**: Detailed debugging information for troubleshooting

## Technical Notes

- This project extends the original Apple sample code from WWDC25 session 297
- Built with SwiftUI and modern Swift concurrency (async/await, @Sendable)
- Uses latest AVFoundation, CoreMedia, and VideoToolbox APIs
- **Audio Support**: Complete audio preservation with intelligent pipeline selection
- **Beta SDK**: Requires macOS 26.0 developer beta for cutting-edge API features

## Performance Notes

- **Stereo Audio**: Very fast processing with direct composition export
- **Ambisonic Audio**: Longer processing time due to APAC encoding requirements
- **Memory Usage**: Efficient processing with minimal temporary file creation
- **Video Resolution**: Processing time scales with video resolution and duration

## Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd apmp-converter-gui

# Open in Xcode Beta (required)
open -a "Xcode-beta" ProjectedMediaConversion.xcodeproj

# Or build from command line using Xcode Beta
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project ProjectedMediaConversion.xcodeproj \
  -scheme ProjectedMediaConversion \
  -configuration Release build
```

**Important**: This project requires Xcode Beta and macOS 26.0 Developer Beta due to its use of cutting-edge APIs that are not available in release versions.

## Support

For issues related to Apple Projected Media Profile, refer to:
- [WWDC25 Session 297: Learn about the Apple Projected Media Profile](https://developer.apple.com/videos/play/wwdc2025/297)
- Apple Developer Documentation on immersive media formats 


