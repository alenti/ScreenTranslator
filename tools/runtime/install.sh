#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACTS="$ROOT/../BuildArtifacts/oct2026"
DEVICE="${1:?Usage: install.sh DEVICE MODEL [--benchmark]}"
MODEL="${2:?Provide the exact pinned GGUF file}"
BUNDLE=AlenShamatov.ScreenTranslatorNext
MODEL_DESTINATION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("localPath","model.gguf"))' "$ROOT/ScreenTranslatorNext/model.json")"
python3 - "$ROOT/ScreenTranslatorNext/model.json" "$MODEL" <<'PY'
import pathlib,hashlib,json,sys
manifest=json.loads(pathlib.Path(sys.argv[1]).read_text());model=pathlib.Path(sys.argv[2])
assert model.stat().st_size==manifest['bytes'], 'Wrong model size'
with model.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
assert sha==manifest['sha256'], 'Wrong model SHA256'
print('Verified model:',manifest['filename'],sha)
PY
test -d "$ROOT/ScreenTranslatorNext/Runtime/llama.xcframework" || bash "$ROOT/tools/runtime/build.sh"
xcodebuild -project "$ROOT/ScreenTranslatorNext/ScreenTranslatorNext.xcodeproj" -scheme ScreenTranslatorNext \
    -configuration Release -destination "id=$DEVICE" -derivedDataPath "$ARTIFACTS/DerivedData" \
    -allowProvisioningUpdates build > "$ARTIFACTS/app-build.log" 2>&1
xcrun devicectl device install app --device "$DEVICE" "$ARTIFACTS/DerivedData/Build/Products/Release-iphoneos/ScreenTranslatorNext.app"
xcrun devicectl device copy to --device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --source "$MODEL" --destination "Documents/$MODEL_DESTINATION"
if [[ "${3:-}" == --benchmark ]]; then
    swift "$ROOT/tools/runtime/make_cards.swift" "$ARTIFACTS/cards"
    xcrun devicectl device copy to --device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
        --source "$ARTIFACTS/cards" --destination Documents/Cards
    xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
        --environment-variables '{"NEXT_AUTORUN":"1"}' "$BUNDLE"
else
    xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE"
fi
