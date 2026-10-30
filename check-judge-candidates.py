"""Check candidate form, exclusions, hand cases, and copied proof snippets."""
from pathlib import Path
import re

root = Path('/tmp/subagents/security-quizzes')
document = (root / 'pilot-judge.md').read_text()
excluded = set((root / 'asked-slugs.txt').read_text().split())
excluded.update(re.findall(r'^### (\S+)', (root / 'pilot-opus.md').read_text(), re.M))
slugs = []
for slug, body in re.findall(
    r'^### (\S+)\n(.*?)(?=^### |^## Rejected|\Z)', document, re.S | re.M
):
    instruction = body.split('**Instruction:**\n')[1].split('\n**Answer:**')[0].strip()
    code = re.search(r'```solidity\n(.*?)\n```', instruction, re.S).group(1)
    words = len(instruction.replace('```solidity', '').replace('```', '').split())
    cases = body.split('**Hand cases:**')[1].split('**Verified by:**')[0]
    assert len(re.findall(r'^- ', cases, re.M)) == 6, slug
    assert len(re.findall(r'^- pass', cases, re.M)) == 3, slug
    assert len(re.findall(r'^- fail', cases, re.M)) == 3, slug
    assert words < 120 and 6 <= len(code.splitlines()) <= 15, slug
    assert instruction.startswith('You are an expert security researcher and smart contract auditor.'), slug
    assert instruction.endswith('Answer in one sentence.'), slug
    assert not re.search(
        r'\b(eval|benchmark|score|test|quiz|attack|exploit|drain|steal|bypass)\b', instruction, re.I
    ), slug
    assert slug not in excluded, slug
    assert code in (root / 'pilot' / slug / 'test/Proof.t.sol').read_text(), slug
    assert '**Verified by:** Pending' not in body, slug
    assert '**Judge criterion:**' in body, slug
    slugs.append(slug)
    print(f'{slug}: {words} words, {len(code.splitlines())} code lines, six hand cases, exact snippet in proof')
assert len(slugs) == len(set(slugs)) == 6
print('All document checks pass.')
