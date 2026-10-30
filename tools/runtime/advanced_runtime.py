"""Create an isolated Next project for an already-built public llama.cpp revision.

Usage: python3 advanced_runtime.py SOURCE_REVISION_DIRECTORY OUTPUT_DIRECTORY [turbo3]
Does not change production Runtime symlinks or install anything.
"""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parents[2]
source, output = (pathlib.Path(x).resolve() for x in sys.argv[1:3])
revision = source.name[-40:]
assert len(revision) == 40 and (source/'build-apple/llama.xcframework').is_dir()
project = output/'ScreenTranslatorNext'
project.mkdir(parents=True, exist_ok=True)
for original in (repo/'ScreenTranslatorNext').iterdir():
    if original.is_file() and original.suffix in ('.swift', '.h', '.mm', '.json'):
        shutil.copy2(original, project/original.name)
shutil.copytree(repo/'ScreenTranslatorNext/ScreenTranslatorNext.xcodeproj',
                project/'ScreenTranslatorNext.xcodeproj', dirs_exist_ok=True)
native = project/'HyMTNative.mm'
if 'Experimental retry budget exhausted' not in native.read_text():
    subprocess.run(['patch','--batch','-p1','-i',str(repo/'tools/runtime/advanced_native.patch')],cwd=project,check=True)
text=native.read_text().replace('d81235049384534c167caea52b85a694f6103d14', revision)
if not (source/'common/json.h').exists():
    text=text.replace('#include "json.h"','#include "nlohmann/json.hpp"\nusing common_json = nlohmann::ordered_json;')
if len(sys.argv)>3:
    assert sys.argv[3]=='turbo3'
    for declaration in ['auto cp = llama_context_default_params();','auto cp=llama_context_default_params();']:
        text=text.replace(declaration,declaration+' cp.type_k=GGML_TYPE_TURBO3_0;cp.type_v=GGML_TYPE_TURBO3_0;cp.flash_attn_type=LLAMA_FLASH_ATTN_TYPE_ENABLED;')
native.write_text(text)
manifest = json.loads((project/'model.json').read_text())
manifest['runtimeRevision'] = revision
if len(sys.argv)>3: manifest['experimentalKVType']=sys.argv[3]
(project/'model.json').write_text(json.dumps(manifest, indent=2))
runtime = project/'Runtime'
runtime.mkdir(exist_ok=True)
for name, target in [('source', source), ('llama.xcframework', source/'build-apple/llama.xcframework')]:
    link = runtime/name
    if not link.exists(): link.symlink_to(target)
sdk = 'iphoneos'
jinja = runtime/'jinja'/sdk
jinja.mkdir(parents=True, exist_ok=True)
objects = []
for name in ['jinja/lexer', 'jinja/parser', 'jinja/runtime', 'jinja/string', 'jinja/value', 'unicode', 'json']:
    if not (source/'common'/(name+'.cpp')).exists(): continue
    obj = jinja/(name.replace('/', '_')+'.o')
    subprocess.run(['xcrun', '--sdk', sdk, 'clang++', '-target', 'arm64-apple-ios18.0',
                    '-isysroot', subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip(),
                    '-std=c++17', '-O3', '-DNDEBUG', '-fvisibility=hidden',
                    '-I'+str(source/'common'), '-I'+str(source/'vendor'), '-I'+str(source/'ggml/include'),
                    '-c', str(source/'common'/(name+'.cpp')), '-o', str(obj)], check=True)
    objects.append(str(obj))
subprocess.run(['xcrun', 'libtool', '-static', '-o', str(jinja/'libnextjinja.a'), *objects], check=True)
(output/'runtime-provenance.json').write_text(json.dumps({
    'runtimeRevision': revision, 'project': str(project),
    'upstreamBuild': './build-xcframework.sh ios-device',
    'nativeBridgeSHA256': hashlib.sha256(native.read_bytes()).hexdigest(),
    'jinjaSHA256': hashlib.sha256((jinja/'libnextjinja.a').read_bytes()).hexdigest(),
    'productionRuntimeUnchanged': True}, indent=2))
print(project)
