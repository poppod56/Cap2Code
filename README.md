# Cap2Code 📸

[![Platform](https://img.shields.io/badge/platform-iOS%2016.6%2B-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Cap2Code** is a powerful iOS application that uses OCR (Optical Character Recognition) to automatically detect and extract IDs, codes, and patterns from screenshots and photos.

## ✨ Features

### 📷 Multiple Import Methods
- **Photo Library**: Select from any album in your photo library
- **Camera**: Take photos directly and scan instantly
- **File Import**: Import images from Files app
- **Batch Processing**: Select and scan multiple images at once

### 🔍 Smart Detection
- **OCR Technology**: Powered by Apple Vision Framework
- **Multi-language Support**: English, Thai, Japanese, Korean
- **Pattern Detection**: Customizable regex patterns
  - Default patterns: AAA-1234, AAA1234
  - Optional patterns: Generic ID, Phone Number, Invoice
  - Custom patterns: Add your own regex patterns

### 📊 Results Management
- **Category Filtering**: All, Today, This Week, This Month
- **Search Integration**: Click to search detected IDs on the web
- **CSV Export**: Export all results with clickable search URLs
- **Context Menu**: Copy ID, Search on web, Copy OCR text
- **Data Persistence**: Scanned data remains even after deleting photos

### ⚙️ Customization
- **Search Domains**: Choose or add custom search engines
  - Built-in: Google, Bing, DuckDuckGo
  - Custom: Add your own with `{q}` placeholder
  - Example: `https://www.example.com/search?q={q}&extra=params`
- **Pattern Management**: Enable/disable patterns, add custom regex
- **Settings**: Organized menu structure for easy configuration

### 🌍 Localization
Full support for **11 languages**:
- 🇺🇸 English
- 🇪🇸 Spanish (Español)
- 🇫🇷 French (Français)
- 🇩🇪 German (Deutsch)
- 🇯🇵 Japanese (日本語)
- 🇰🇷 Korean (한국어)
- 🇵🇹 Portuguese (Português)
- 🇷🇺 Russian (Русский)
- 🇨🇳 Chinese (中文)
- 🇸🇦 Arabic (العربية)
- 🇹🇭 Thai (ไทย)

### 📱 Additional Features
- **App Update Checker**: Automatic notification when new version is available
- **Pause/Resume**: Control batch processing with pause/resume
- **Progress Tracking**: Real-time progress bar during scanning
- **Facebook Analytics**: Track app installations and engagement

## 🛠 Technologies

- **SwiftUI**: Modern declarative UI framework
- **Vision Framework**: OCR and text recognition
- **Photos/PhotosUI**: Photo library access and management
- **AVFoundation**: Camera integration
- **Combine**: Reactive programming
- **Facebook SDK**: Analytics and tracking

## 📋 Requirements

- iOS 16.6 or later
- Xcode 15.0 or later
- Swift 5.0 or later

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Cap2Code.git
   cd Cap2Code
   ```

2. **Install Facebook SDK**
   
   The project uses Swift Package Manager for Facebook SDK. Dependencies will be resolved automatically when you open the project in Xcode.

3. **Configure Facebook SDK**
   
   The Facebook SDK is already configured in the project with:
   - App ID: `3786481838317702`
   - Client Token: Already set in `CodeScan-Info.plist`
   - Display Name: Cap2Code

4. **Open the project**
   ```bash
   open ScreenShotAutoRun.xcodeproj
   ```

5. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 📖 Usage

### Basic Workflow

1. **Import Photos**
   - Tap "Select Album" to choose from your photo library
   - Or tap the camera icon to take a new photo
   - Or use "Scan Selected" to process specific images

2. **View Results**
   - Navigate to the "Results" tab
   - See all detected IDs organized by date
   - Filter by category (All, Today, This Week, This Month)

3. **Search & Export**
   - Tap the magnifying glass icon to search an ID on the web
   - Tap "Export CSV" to export all results with search URLs
   - Long-press on IDs for more options (Copy, Search, Copy OCR)

### Customization

1. **Add Custom Patterns**
   - Go to Settings → Patterns
   - Tap "+" to add a new pattern
   - Enter name and regex pattern
   - Toggle patterns on/off as needed

2. **Configure Search Domain**
   - Go to Settings → Search Domains
   - Select from built-in options or tap "+" to add custom
   - Use `{q}` as placeholder for the search query
   - Example: `https://www.google.com/search?q={q}`

## 🏗 Project Structure

```
ScreenShotAutoRun/
├── App/                          # App configuration
├── Features/
│   ├── Import/                   # Photo import and scanning
│   ├── Results/                  # Results display and management
│   ├── Review/                   # Photo review
│   └── Settings/                 # App settings
├── Services/
│   ├── OCRService.swift         # OCR processing
│   ├── PhotoService.swift       # Photo library management
│   └── AppUpdateService.swift   # Version update checker
├── Persistence/
│   ├── JSONStore.swift          # Scan results storage
│   ├── PatternStore.swift       # Pattern management
│   └── SearchDomainStore.swift  # Search domain management
├── Shared/
│   ├── Models/                   # Data models
│   ├── UI/                      # Reusable UI components
│   └── Utils/                   # Utility functions
└── Localization/                # 11 language support
```

## 🔐 Privacy

Cap2Code respects your privacy:

- **Local Processing**: All OCR and pattern detection happens on your device
- **No Cloud Storage**: Your data is stored locally on your device
- **Camera & Photos**: Only accessed with your explicit permission
- **Facebook Analytics**: Only tracks basic app usage (installs, opens)
- **No Personal Data Collection**: We don't collect or transmit personal information

### Permissions Required

- **Camera**: To take photos for scanning
- **Photo Library**: To access and scan existing photos

## 📊 Data Storage

All scanned data is stored locally in:
- **Location**: App's Documents directory
- **Format**: JSON files
- **Files**: 
  - `processed.json`: Scan results
  - `patterns.json`: Custom patterns
  - `search_domains.json`: Custom search domains

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 To-Do List

- [ ] Add unit tests
- [ ] Add UI tests
- [ ] Implement backup & restore
- [ ] Add statistics dashboard
- [ ] Implement iCloud sync
- [ ] Add widget support
- [ ] iPad layout optimization
- [ ] Add Shortcuts support

## 🐛 Known Issues

- None currently reported

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple Vision Framework for OCR capabilities
- Facebook SDK for analytics
- SwiftUI community for inspiration and support

## 📞 Support

For support, please open an issue in the GitHub repository or contact:
- Email: support@cap2code.com
- Website: https://cap2code.com

## 📱 App Store

Coming soon to the App Store!

---

**Made with ❤️ using SwiftUI**

Version: 1.1.1 (Build 3)
