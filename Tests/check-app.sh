set -eu

app=${1:?Pass the path to CommandShift.app}
binary="$app/Contents/MacOS/CommandShift"
plist="$app/Contents/Info.plist"

if [ ! -x "$binary" ]; then
    printf 'FAIL: the app must contain an executable CommandShift binary\n' >&2
    exit 1
fi

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" = CommandShift
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = io.github.sashokey.command-shift
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$plist")" = true
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")" = 13.0

if ! icon_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist" 2>/dev/null); then
    printf 'FAIL: the app must declare its icon\n' >&2
    exit 1
fi
icon="$app/Contents/Resources/$icon_name"
if [ ! -s "$icon" ]; then
    printf 'FAIL: the declared app icon must exist in Contents/Resources\n' >&2
    exit 1
fi
iconset=$(mktemp -d "$(dirname "$app")/check-icon.XXXXXX")/AppIcon.iconset
/usr/bin/iconutil --convert iconset --output "$iconset" "$icon"
for size in 16 32 128 256 512; do
    test -s "$iconset/icon_${size}x${size}.png"
    test -s "$iconset/icon_${size}x${size}@2x.png"
done

/usr/bin/plutil -lint "$plist"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/file "$binary"
printf 'PASS: app bundle metadata, icon resolutions, executable and signature\n'
