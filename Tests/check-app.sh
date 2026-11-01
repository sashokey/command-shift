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
/usr/bin/plutil -lint "$plist"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/file "$binary"
printf 'PASS: app bundle metadata, executable and signature\n'
