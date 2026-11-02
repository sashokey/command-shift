# CommandShift

CommandShift is a lightweight menu bar app for switching keyboard layouts with **Shift + Command**.

Requires macOS 13 or later. Supports Apple Silicon Macs.

## Installation

Download the app ZIP from [Releases](https://github.com/sashokey/command-shift/releases), move `CommandShift.app` to `/Applications`, and open it. Grant **Input Monitoring** permission through the native macOS prompt. CommandShift starts listening automatically once permission is granted.

The app is currently ad-hoc signed and not notarized. macOS may require **Privacy & Security → Open Anyway** on first launch.

## Usage notes

- **Restore a hidden menu bar icon:** open CommandShift again from **Applications** while it is already running.
- **Shortcut conflicts:** switching happens when either modifier is released. Typing or using the mouse during the gesture cancels it, so shortcuts such as **Command + Shift + Z** keep working. Release both modifiers before trying again after cancellation.
- **More than two input sources:** the shortcut cycles through all enabled keyboard layouts and input modes.
- **Pending login approval:** select **Open at Login (Pending Approval)** to open **Login Items** in System Settings.
- **Secure Keyboard Entry:** the shortcut may be unavailable while another app uses this mode.

## License

Licensed under [GPL-3.0](LICENSE).
