#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACTS="$ROOT/../BuildArtifacts/oct2026/runtime"
REV=d81235049384534c167caea52b85a694f6103d14
SHA=6b58785f0a82898f4c3442417ff962e2d4b231b1bee5d033902ad90b27901e14
SOURCE="$ARTIFACTS/llama.cpp-$REV"
mkdir -p "$ARTIFACTS" "$ROOT/ScreenTranslatorNext/Runtime"
if [[ ! -f "$ARTIFACTS/source.tar.gz" ]]; then
    curl -fL --retry 3 "https://codeload.github.com/ggml-org/llama.cpp/tar.gz/$REV" -o "$ARTIFACTS/source.tar.gz"
fi
printf '%s  %s\n' "$SHA" "$ARTIFACTS/source.tar.gz" | shasum -a 256 -c -
if [[ ! -d "$SOURCE" ]]; then tar -xzf "$ARTIFACTS/source.tar.gz" -C "$ARTIFACTS"; fi
python3 - "$ARTIFACTS/source.tar.gz" "$ARTIFACTS" <<'PY'
import hashlib,pathlib,sys,tarfile
with tarfile.open(sys.argv[1]) as archive:
    count=0
    for item in archive.getmembers():
        if not item.isfile():continue
        source=pathlib.Path(sys.argv[2])/item.name
        assert source.is_file(), f'Missing source: {item.name}'
        assert hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(archive.extractfile(item).read()).digest(), f'Source changed: {item.name}'
        count+=1
print('Verified exact archive source files:',count)
PY
# Always build from verified archive contents, without changing any old runtime.
if [[ ! -d "$SOURCE/build-apple/llama.xcframework" ]]; then
    (cd "$SOURCE" && ./build-xcframework.sh ios-device ios-sim)
fi
# Official XCFramework omits common/Jinja. Compile its same-revision sources;
# no handwritten chat template and no copied legacy runtime libraries.
for sdk in iphoneos iphonesimulator; do
    output="$ARTIFACTS/jinja/$sdk"
    mkdir -p "$output"
    objects=()
    if [[ "$sdk" == iphoneos ]]; then target=arm64-apple-ios18.0; else target=arm64-apple-ios18.0-simulator; fi
    for file in jinja/lexer jinja/parser jinja/runtime jinja/string jinja/value unicode json; do
        object="$output/${file//\//_}.o"
        xcrun --sdk "$sdk" clang++ -target "$target" -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
            -std=c++17 -O3 -DNDEBUG -fvisibility=hidden \
            -I"$SOURCE/common" -I"$SOURCE/vendor" -I"$SOURCE/ggml/include" \
            -c "$SOURCE/common/$file.cpp" -o "$object"
        objects+=("$object")
    done
    xcrun --sdk "$sdk" libtool -static -o "$output/libnextjinja.a" "${objects[@]}"
done
ln -sfn "$SOURCE/build-apple/llama.xcframework" "$ROOT/ScreenTranslatorNext/Runtime/llama.xcframework"
ln -sfn "$SOURCE" "$ROOT/ScreenTranslatorNext/Runtime/source"
ln -sfn "$ARTIFACTS/jinja" "$ROOT/ScreenTranslatorNext/Runtime/jinja"
cmake -S "$SOURCE" -B "$ARTIFACTS/host" -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_APP=OFF \
    -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_COMMON=ON \
    -DLLAMA_BUILD_MTMD=ON -DGGML_METAL=ON -DLLAMA_BUILD_NUMBER=11429 -DLLAMA_BUILD_COMMIT=d81235049
cmake --build "$ARTIFACTS/host" --target llama-cli -j 6
python3 - "$ARTIFACTS" "$REV" "$SHA" <<'PY'
import pathlib,hashlib,json,sys,subprocess
root=pathlib.Path(sys.argv[1]);source=root/('llama.cpp-'+sys.argv[2])
files={str(p.relative_to(source/'build-apple')):hashlib.sha256(p.read_bytes()).hexdigest()
       for p in sorted((source/'build-apple/llama.xcframework').rglob('*')) if p.is_file()}
manifest={'release':'v0.6.0 / b11429','revision':sys.argv[2],'sourceSHA256':sys.argv[3],
 'command':'./build-xcframework.sh ios-device ios-sim','xcode':subprocess.check_output(['xcodebuild','-version'],text=True),
 'options':{'GGML_METAL':True,'GGML_METAL_EMBED_LIBRARY':True,'GGML_NATIVE':False,'GGML_OPENMP':False,'BUILD_SHARED_LIBS':False},
 'jinja':'same-revision common/jinja plus unicode.cpp/json.cpp; arm64 device/simulator', 'frameworkFilesSHA256':files,
 'jinjaSHA256':{sdk:hashlib.sha256((root/'jinja'/sdk/'libnextjinja.a').read_bytes()).hexdigest() for sdk in ['iphoneos','iphonesimulator']}}
(root/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('Runtime ready:',root/'manifest.json')
PY
