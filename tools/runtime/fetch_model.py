#!/usr/bin/env python3
"""Fetch only the app's pinned official model; validate before exposing final file."""
import hashlib, json, pathlib, sys, urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
manifest = json.loads((root/'ScreenTranslatorNext/model.json').read_text())
destination = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root.parent/'BuildArtifacts/oct2026/models'/manifest['filename']
destination.parent.mkdir(parents=True, exist_ok=True)
temporary = destination.with_suffix('.gguf.part')
if destination.exists():
    with destination.open('rb') as source:
        assert destination.stat().st_size == manifest['bytes'] and hashlib.file_digest(source,'sha256').hexdigest() == manifest['sha256'], 'Existing file is not the pinned model'
else:
    url = f"https://huggingface.co/{manifest['repository']}/resolve/{manifest['revision']}/{manifest['filename']}?download=true"
    with urllib.request.urlopen(url, timeout=120) as response, temporary.open('wb') as output:
        while chunk := response.read(4*1024*1024):
            output.write(chunk)
    with temporary.open('rb') as source:
        assert temporary.stat().st_size == manifest['bytes'] and hashlib.file_digest(source,'sha256').hexdigest() == manifest['sha256'], 'Downloaded artifact mismatch'
    temporary.rename(destination)
print(destination.resolve(), manifest['sha256'])
