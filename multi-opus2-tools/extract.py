# usage: extract.py <instruction file> <out .sol>; writes the code block with an SPDX line and the pinned pragma
import sys, re
t = open(sys.argv[1]).read()
code = re.search(r"```solidity\n(.*?)```", t, re.S).group(1)
head = "// SPDX-License-Identifier: MIT\n"
if "pragma solidity" not in code:
    head += "pragma solidity 0.8.28;\n"
open(sys.argv[2], "w").write(head + code)
