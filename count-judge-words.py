# Count words in each **Instruction:** block of pilot-judge.md (whitespace-split, code included).
import re, sys
text = open(sys.argv[1]).read()
for m in re.finditer(r"^### (\S+)\n\*\*Instruction:\*\*\n(.*?)\n\*\*Answer:\*\*", text, re.S | re.M):
    words = len(m.group(2).replace("```solidity", "").replace("```", "").split())
    print(f"{words:4d}  {m.group(1)}")
