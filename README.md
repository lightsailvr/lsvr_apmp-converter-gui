# APMP Converter GUI

A SwiftUI application for converting projected video content to Apple Projected Media Profile (APMP) format. This app provides an intuitive graphical interface for batch video conversion with drag & drop support, conversion queue management, and progress tracking.

## What This App Does

The APMP Converter GUI transforms 360° and 180° immersive video content into Apple's Projected Media Profile format, making it compatible with Apple's immersive media ecosystem. The app supports:

- **Monoscopic and stereoscopic video conversion**
- **Multiple projection types**: Equirectangular and half-equirectangular
- **Frame-packing modes**: Side-by-side and over-under stereoscopic layouts
- **Automatic format detection** from video metadata
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

- **Auto-detect**: Let the app analyze video metadata automatically
- **Projection Type**: Choose between equirectangular or half-equirectangular
- **View Packing**: Select side-by-side or over-under for stereoscopic content
- **Baseline**: Set stereo baseline in millimeters (for stereoscopic video)
- **Field of View**: Specify horizontal FOV in degrees

### Processing Videos

1. **Review** your conversion queue
2. **Adjust settings** for each video as needed
3. **Click "Start Conversion"** to begin batch processing
4. **Monitor progress** with real-time progress indicators
5. **Find converted files** in the same directory as source files (with `_apmp.mov` suffix)

## Supported Input Formats

- **Video codecs**: H.264, HEVC, and other AVFoundation-compatible formats
- **Projections**: Equirectangular (360°) and half-equirectangular (180°)
- **Stereoscopic layouts**: Side-by-side and over-under frame packing
- **File formats**: Most QuickTime-compatible video files

## Output Format

- **Container**: QuickTime (.mov)
- **Video codec**: HEVC for monoscopic, MV-HEVC for stereoscopic
- **Filename**: Original name with `_apmp.mov` suffix
- **Metadata**: Apple Projected Media Profile compliant

## System Requirements

- **macOS**: 26.0 or later
- **Xcode**: 16.0 or later for building
- **Swift**: 6.0
- **Architecture**: Apple Silicon and Intel Macs supported

## Technical Notes

- This project extends the original Apple sample code from WWDC25 session 297
- Built with SwiftUI and modern Swift concurrency (async/await)
- Uses AVFoundation, CoreMedia, and VideoToolbox for video processing
- Currently processes video tracks only (audio preservation in development)

## Known Limitations

- **Audio**: Original audio tracks are not preserved in current version
- **Performance**: Processing time depends on video resolution and duration
- **Memory**: Large video files may require significant RAM during conversion

## Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd apmp-converter-gui

# Open in Xcode
open ProjectedMediaConversion.xcodeproj

# Or build from command line
xcodebuild -project ProjectedMediaConversion.xcodeproj -scheme ProjectedMediaConversion -configuration Release build
```

## Support

For issues related to Apple Projected Media Profile, refer to:
- [WWDC25 Session 297: Learn about the Apple Projected Media Profile](https://developer.apple.com/videos/play/wwdc2025/297)
- Apple Developer Documentation on immersive media formats 


