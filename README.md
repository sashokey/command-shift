Cycles through enabled keyboard layouts and input modes across applications.

Requires macOS 13 or later and an Apple Silicon Mac.

## Installation

Download the app ZIP from [Releases](https://github.com/sashokey/command-shift/releases), move `CommandShift.app` to `/Applications`, and open it. Grant **Input Monitoring** permission through the native macOS prompt. CommandShift starts listening automatically once permission is granted.

The app is currently ad-hoc signed and not notarized. macOS may require **Privacy & Security → Open Anyway** on first launch.

## Usage notes

- **Restore a hidden menu bar icon:** open CommandShift again from **Applications** while it is already running.
- **Shortcut behavior:** switching with **Shift + Command** happens when either modifier is released. Typing or using the mouse during the gesture cancels it, so shortcuts such as **Command + Shift + Z** keep working. Release both modifiers before trying again after cancellation.
- **Pending login approval:** select **Open at Login (Pending Approval)** to open **Login Items** in System Settings.
- **Secure Keyboard Entry:** the shortcut may be unavailable while another app uses this mode.
