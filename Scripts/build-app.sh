set -eu

cd "$(dirname "$0")/.."
app=${1:-.build/CommandShift.app}
if [ "$#" -gt 0 ]; then shift; fi

if [ -e "$app" ]; then
    printf 'Output already exists: %s\nChoose a new output path.\n' "$app" >&2
    exit 1
fi

swift build --configuration release --product CommandShift -debug-info-format none --disable-local-rpath -Xswiftc -Osize -Xswiftc -warnings-as-errors "$@"
bin_dir=$(swift build --configuration release --show-bin-path "$@")
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/CommandShift" "$app/Contents/MacOS/CommandShift"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/bin/strip -S -x "$app/Contents/MacOS/CommandShift"
/usr/bin/codesign --sign - --options runtime --timestamp=none "$app"
printf 'Built %s\n' "$app"
