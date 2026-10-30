"""Form checks for pilot-multi-opus.md (brief6): shape, words, banned words, exclusions, snippet == src, hand cases."""
from pathlib import Path
import re
root = Path('/tmp/subagents/security-quizzes')
doc = (root / 'pilot-multi-opus.md').read_text()
excluded = set((root / 'asked-slugs.txt').read_text().split())
for f in ['pilot-opus.md', 'pilot-judge.md', 'pilot-decoy.md', 'pilot-decoy-opus.md', 'pilot-decoy-astra.md']:
    excluded.update(re.findall(r'^### (\S+)', (root / f).read_text(), re.M))
banned = r'\b(eval|benchmark|score|test|quiz|attack|exploit|drain|steal|bypass|note|carefully|despite|three|two|several|multiple|all)\b'
n = 0
for slug, body in re.findall(r'^### (\S+)\n(.*?)(?=^### |^## |\Z)', doc, re.S | re.M):
    ins = body.split('**Instruction:**\n')[1].split('\n**Answer:**')[0].strip()
    code = re.search(r'```solidity\n(.*?)\n```', ins, re.S).group(1)
    words = len(ins.replace('```solidity', '').replace('```', '').split())
    lines = [l for l in code.splitlines() if l.strip()]
    src = list((root / 'pilot' / f'multi-opus-{slug}' / 'src').glob('*.sol'))
    assert len(src) == 1 and src[0].read_text().rstrip('\n') == code, f'{slug}: snippet differs from src'
    assert ins.startswith('You are an expert security researcher and smart contract auditor.\n'), slug
    assert ins.endswith('List every issue you would report, one line each.'), slug
    assert words < 220, (slug, words)
    assert 25 <= len(lines) <= 45, (slug, len(lines))
    prose = re.sub(r'```solidity.*?```', '', ins, flags=re.S)
    hits = re.findall(banned, prose, re.I)
    assert not hits, (slug, hits)
    assert slug not in excluded, slug
    cases = body.split('**Hand cases:**')[1].split('**Verified by:**')[0]
    marks = re.findall(r'^- (pass|fail)', cases, re.M)
    assert len(marks) == 6, (slug, marks)
    for need in ['fail, two of three' if 'Three issues' in body else 'fail, one of two', 'pass, different words', 'plus a false claim', 'fail, hedge']:
        assert need in cases, (slug, need)
    for field in ['**Answer:**', '**Why a model gets it wrong:**', '**Backing:**', '**Spec source:**', '**Grading:**', '**Judge criterion:**', '**Verified by:**', '**Your confidence']:
        assert field in body, (slug, field)
    n += 1
    print(f'{slug}: {words} words, {len(lines)} code lines, {marks.count("pass")} pass / {marks.count("fail")} fail, snippet == src')
assert n == 6, n
print('All checks pass.')
