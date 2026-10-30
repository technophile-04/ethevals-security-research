from pathlib import Path
import re

ROOT = Path('/tmp/subagents/security-quizzes')
draft = (ROOT / 'pilot-decoy-astra.md').read_text()
blocks = re.split(r'^### ', draft, flags=re.M)[1:]
assert len(blocks) == 6
excluded = set((ROOT / 'asked-slugs.txt').read_text().split())
for name in ('pilot-judge.md', 'pilot-opus.md'):
    excluded.update(re.findall(r'^### (\S+)', (ROOT / name).read_text(), re.M))

def functions(code):
    for match in re.finditer(r'\bfunction\s+(\w+)\s*\(', code):
        start = code.index('{', match.end())
        depth = 1
        end = start + 1
        while depth:
            depth += (code[end] == '{') - (code[end] == '}')
            end += 1
        yield match.group(1), re.sub(r'\s+', '', code[match.start():end])

for block in blocks:
    slug = block.splitlines()[0]
    assert slug not in excluded, slug
    instruction = block.split('**Instruction:**\n')[1].split('\n**Answer:**')[0].strip()
    assert instruction.startswith('You are an expert security researcher and smart contract auditor.')
    assert instruction.endswith('What is the root cause of the loss? Answer in one sentence.')
    assert len(instruction.split()) < 160, slug
    code = re.search(r'```solidity\n(.*?)```', instruction, re.S).group(1)
    lines = len(code.strip().splitlines())
    assert 12 <= lines <= 25, (slug, lines)
    assert not re.search(r'\b(test|quiz|eval|benchmark|score|attack|exploit|drain|steal|bypass|note|carefully|despite)\b', instruction, re.I)
    assert len(re.findall(r'^- Pass:', block, re.M)) == 3, slug
    assert len(re.findall(r'^- Fail', block, re.M)) == 3, slug
    assert 'Fail, confident decoy:' in block
    assert '**Judge criterion:** Passes if' in block
    assert '**Verified by:** `forge test --root' in block
    assert '[PASS] testDecoy' in block and '[PASS] testReal' in block
    proof = ROOT / 'pilot' / ('astra-' + slug) / 'test' / 'Proof.t.sol'
    actual = dict(functions(proof.read_text()))
    for name, body in functions(code):
        assert actual.get(name) == body, (slug, name, 'snippet differs from executed source')
    print(f'{slug}: {len(instruction.split())} words, {lines} lines, six hand cases, source bodies match')
print('Six candidates pass the draft checks; Foundry results are recorded in each candidate.')
