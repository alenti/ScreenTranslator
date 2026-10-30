"""Download explicitly selected, immutable official files into an isolated directory.

Usage: python breakthrough_models.py METADATA_JSON OUTPUT FILE [FILE ...]
Uses the local HF authorization, never accepts a token on the command line.
"""
import concurrent.futures
import hashlib
import json
import pathlib
import sys
from huggingface_hub import hf_hub_download


def main():
    metadata = json.loads(pathlib.Path(sys.argv[1]).read_text())
    output = pathlib.Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    files = {row['rfilename']: row for row in metadata['siblings']}
    names = sys.argv[3:]
    assert names and all(name in files for name in names)

    def fetch(name):
        row = files[name]
        path = pathlib.Path(hf_hub_download(metadata['id'], name, revision=metadata['sha'], local_dir=output))
        with path.open('rb') as stream:
            sha = hashlib.file_digest(stream, 'sha256').hexdigest()
        assert path.stat().st_size == row['size'], f'Size mismatch: {name}'
        if row.get('lfs'):
            assert sha == row['lfs']['sha256'], f'SHA mismatch: {name}'
        print('VERIFIED', name, path.stat().st_size, flush=True)
        return {'filename': name, 'bytes': path.stat().st_size, 'sha256': sha}

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        verified = list(pool.map(fetch, names))
    (output/'provenance.json').write_text(json.dumps({
        'repository': metadata['id'], 'revision': metadata['sha'],
        'licenseMetadata': metadata.get('cardData', {}).get('license'),
        'files': verified, 'purpose': 'isolated new-architecture screening; never auto-installs'}, indent=2))


if __name__ == '__main__':
    main()
