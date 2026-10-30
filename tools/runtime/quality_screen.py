#!/usr/bin/env python3
"""Ten direct CLI translations, no server or output correction. Raw evidence retained."""
import argparse, hashlib, json, pathlib, subprocess, time

p = argparse.ArgumentParser()
p.add_argument('model', type=pathlib.Path)
p.add_argument('--cli', default='llama-cli')
p.add_argument('--output', type=pathlib.Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
texts = ['加入购物车', '您好，我收到货后发现有一个灯不亮，可以补发配件吗？',
         '可以的，麻烦拍一下故障视频，我们今天给您补发。',
         '这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。',
         '已选：暖白光 3000K，54W，260×80cm；20件']
with a.model.open('rb') as f:
    sha = hashlib.file_digest(f, 'sha256').hexdigest()
record = {'model': str(a.model.resolve()), 'sha256': sha,
          'runtime': subprocess.check_output([a.cli, '--version'], text=True, stderr=subprocess.STDOUT), 'rows': []}
for lang, target in [('en', '英语'), ('ru', '俄语')]:
    for i, text in enumerate(texts):
        prompt = f'将以下文本翻译为{target}，注意只需要输出翻译后的结果，不要额外解释：\n{text}'
        command = [a.cli, '-m', str(a.model.resolve()), '-p', prompt, '-st', '--jinja', '--simple-io',
                   '--no-display-prompt', '--no-warmup', '--color', 'off', '--log-colors', 'off',
                   '--seed', '42', '--temp', '0.7', '--top-p', '0.6', '--top-k', '20', '--min-p', '0',
                   '--repeat-penalty', '1.05', '-n', '512', '-c', '2048', '-ngl', '99']
        start = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True, timeout=180)
        (a.output / f'{lang}-{i}.stdout.txt').write_text(result.stdout)
        (a.output / f'{lang}-{i}.stderr.txt').write_text(result.stderr)
        record['rows'].append({'target': lang, 'source': text, 'stdout': result.stdout,
                               'exitCode': result.returncode, 'wallMs': (time.monotonic()-start)*1000, 'command': command})
        (a.output / 'results.json').write_text(json.dumps(record, indent=2, ensure_ascii=False))
        print(lang, i, result.returncode, result.stdout[-1000:], flush=True)
