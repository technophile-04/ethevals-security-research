"""Extract candidate instructions and their targets from the six source files."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
questions = []
for stem in ("accounts", "signatures", "tokens", "upgrades", "defi", "evm"):
    path = ROOT / f"{stem}.md"
    source = path.read_text()
    for match in re.finditer(r"^### ([^\n]+)\n(.*?)(?=^### |\Z)", source, re.M | re.S):
        slug, body = match.groups()
        instruction = re.search(r"\*\*Instruction:\*\*(.*?)\*\*Answer:\*\*", body, re.S)
        answer = re.search(r"\*\*Answer:\*\*(.*?)(?=^\*\*|\Z)", body, re.M | re.S)
        grading = re.search(r"^\*\*Grading:\*\*([^\n]*)", body, re.M)
        if not all((instruction, answer, grading)):
            raise ValueError(f"Missing field: {path.name} {slug}")
        questions.append({"id": slug.strip(), "file": path.name,
                          "instruction": instruction[1].strip(),
                          "answer": answer[1].strip(), "grading": grading[1].strip()})
assert len({q["id"] for q in questions}) == len(questions), "Duplicate question IDs"
(ROOT / "questions.json").write_text(json.dumps(questions, indent=2, ensure_ascii=False) + "\n")
print(f"Question count: {len(questions)}")
print({stem: sum(q["file"] == f"{stem}.md" for q in questions)
       for stem in ("accounts", "signatures", "tokens", "upgrades", "defi", "evm")})
