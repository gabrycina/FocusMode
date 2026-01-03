# FocusMode

A lightweight macOS menu bar app that instantly switches you to a distraction-free workspace with a single keyboard shortcut.

![FocusMode Demo](https://raw.githubusercontent.com/gabrycina/FocusMode/main/Assets/demo.gif)

## Features

- **One-key activation** - Press `Cmd+Shift+P` to instantly enter focus mode
- **Multi-monitor support** - Assign apps to specific screens
- **Clean workspace** - Hides all other apps, shows only what you need
- **Menu bar app** - Lives in your menu bar, no dock icon clutter
- **Configurable** - Choose which apps are part of your productivity setup
- **Native & fast** - Built with Swift, minimal resource usage

## Installation

### Download (Recommended)

1. Download the latest `FocusMode-x.x.x.dmg` from [Releases](https://github.com/gabrycina/FocusMode/releases)
2. Open the DMG and drag FocusMode to your Applications folder
3. Launch FocusMode from Applications
4. Grant Accessibility permissions when prompted (required for window management)

### Build from Source

```bash
git clone https://github.com/gabrycina/FocusMode.git
cd FocusMode
./Scripts/build.sh
```

The app will be at `build/FocusMode.app`

## Usage

1. **Click the target icon** in your menu bar to open settings
2. **Search and select apps** you want in your focus workspace
3. **Assign screens** (if you have multiple monitors)
4. **Press `Cmd+Shift+P`** to activate your workspace

When activated:
- All non-configured apps are hidden
- Your selected apps open and maximize on their assigned screens
- You're immediately in your productivity zone

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions (for window management)

## Permissions

FocusMode needs Accessibility permissions to:
- Move and resize windows
- Hide other applications

Grant access at: **System Settings → Privacy & Security → Accessibility**

## Building

Requirements:
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

```bash
# Build release
swift build -c release

# Or use the build script (creates .app bundle and DMG)
./Scripts/build.sh
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Pull requests welcome! Please open an issue first to discuss what you'd like to change.
