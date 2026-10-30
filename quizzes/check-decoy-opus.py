"""Form checks for pilot-decoy-opus.md (brief5): shape, words, banned words, exclusions, snippet == src."""
from pathlib import Path
import re
root = Path('/tmp/subagents/security-quizzes')
doc = (root / 'pilot-decoy-opus.md').read_text()
excluded = set((root / 'asked-slugs.txt').read_text().split())
for f in ['pilot-opus.md', 'pilot-judge.md', 'pilot-decoy.md', 'pilot-decoy-astra.md']:
    excluded.update(re.findall(r'^### (\S+)', (root / f).read_text(), re.M))
banned = r'\b(eval|benchmark|score|test|quiz|attack|exploit|drain|steal|bypass|note|carefully|despite)\w*'
n = 0
for slug, body in re.findall(r'^### (\S+)\n(.*?)(?=^### |^## |\Z)', doc, re.S | re.M):
    ins = body.split('**Instruction:**\n')[1].split('\n**Answer:**')[0].strip()
    code = re.search(r'```solidity\n(.*?)\n```', ins, re.S).group(1)
    words = len(ins.replace('```solidity', '').replace('```', '').split())
    lines = [l for l in code.splitlines() if l.strip()]
    src = list((root / 'pilot' / f'opus-{slug}' / 'src').glob('*.sol'))
    assert len(src) == 1 and src[0].read_text().rstrip('\n') == code, f'{slug}: snippet differs from src'
    assert ins.startswith('You are an expert security researcher and smart contract auditor.'), slug
    assert ins.endswith('What is the root cause of the loss? Answer in one sentence.'), slug
    assert words < 160, (slug, words)
    assert 12 <= len(lines) <= 25, (slug, len(lines), 'non-blank code lines')
    hits = re.findall(banned, ins, re.I)
    assert not hits, (slug, hits)
    assert slug not in excluded, slug
    cases = body.split('**Hand cases:**')[1].split('**Verified by:**')[0]
    assert len(re.findall(r'^- pass', cases, re.M)) == 3 and len(re.findall(r'^- fail', cases, re.M)) == 3, slug
    assert '- fail, confident decoy:' in cases, slug
    for field in ['**Answer:**', '**Decoy:**', '**Backing:**', '**Decoy source:**', '**Spec source:**', '**Judge criterion:**', '**Verified by:**', '**Your confidence']:
        assert field in body, (slug, field)
    n += 1
    print(f'{slug}: {words} words, {len(lines)} non-blank code lines, 3 pass / 3 fail, snippet == src')
assert n == 6, n
print('All checks pass.')
