"""Download immutable official inputs for isolated compression; never install a model.

Usage: python3 tools/runtime/advanced_models.py OUTPUT_DIRECTORY
Downloads ~16 GB. Run the recorded upstream converter/quantizer separately.
"""
import concurrent.futures
import hashlib
import json
import pathlib
import subprocess
import sys
import urllib.request

REPOSITORY = 'tencent/Hy-MT2-7B'
REVISION = '9b0eb4e8f001def3e5ff6469a0ac96fdb39ec223'


def fetch(output):
    output = pathlib.Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    metadata = json.load(urllib.request.urlopen(
        f'https://huggingface.co/api/models/{REPOSITORY}/revision/{REVISION}?blobs=true', timeout=30))
    selected = [f for f in metadata['siblings'] if '/' not in f['rfilename'] and
                f['rfilename'].endswith(('.json', '.jinja', '.safetensors', '.txt'))]

    def download(row):
        name = row['rfilename']
        target = output / name
        temporary = output / (name + '.partial')
        if not target.exists():
            subprocess.run(['curl', '--fail', '--location', '--retry', '2', '--continue-at', '-',
                            '--silent', '--show-error',
                            f'https://huggingface.co/{REPOSITORY}/resolve/{REVISION}/{name}',
                            '--output', str(temporary)], check=True)
            temporary.rename(target)
        with target.open('rb') as stream:
            sha = hashlib.file_digest(stream, 'sha256').hexdigest()
        assert target.stat().st_size == row['size'], f'Wrong size: {name}'
        if row.get('lfs'):
            assert sha == row['lfs']['sha256'], f'Wrong SHA256: {name}'
        print('VERIFIED', name, target.stat().st_size, flush=True)
        return {'filename': name, 'bytes': target.stat().st_size, 'sha256': sha}

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        files = list(pool.map(download, selected))
    (output / 'download-provenance.json').write_text(json.dumps({
        'repository': REPOSITORY, 'revision': REVISION, 'files': files,
        'license': 'Apache-2.0; see the downloaded LICENSE.txt',
        'purpose': 'Independent BF16 source for quantization; no production replacement'}, indent=2))


if __name__ == '__main__':
    fetch(sys.argv[1])
