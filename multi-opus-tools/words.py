# usage: words.py <instruction file>; counts whitespace-split words with code fences removed
import sys
t=open(sys.argv[1]).read()
print(len(t.replace('```solidity','').replace('```','').split()))
