# Fable advice, round two: why every model finds these, and what to change

Written from the brief, the plan and my first answer only; no trajectories or task code read.

## 1. Why every model finds them

**The bug class, first and by a wide margin.** Every planted bug is a broken symmetry inside one state variable: `deploy` raises `deployedAssets`, `undeploy` forgets to lower it. The property that breaks is the variable's own definition, so the whole proof fits in the two or three places that write it. A model reading a file once collects every writer of each counter, and an asymmetric pair stands out like a missing bracket. That is recognition, not audit. DeepSeek passing at $0.04 says the same thing: the bug is visible on a skim.

**Model-written bugs are model-shaped, and the port stripped the hard part.** The writers were asked to carry a real finding's mechanism into new code, and did the minimal port: write a clean contract, delete one line. In Kinetiq or RAAC the same mechanism sat among protocol-specific complications and several harmless asymmetries. In our code it is the only inconsistency in an otherwise textbook file, under descriptive names that state the invariant out loud. This is the trim I warned against in round one, done by writing instead of cutting: the ten-line excerpt in a 600-line coat.

**Size is not the lever at these numbers.** The grown vault proves it: 1,225 lines, same two lines, both agents still found both, only slower. Everything fits in one read. Size bites only when the needle itself spans files, not when the haystack does. EVMbench's 46% recall at a similar median size comes from the needle, not the hay: contest Highs that survive to a report are mostly assumption mismatches, because the team's own tests already catch the forgotten lines.

**README, the word "audit", internet mode: not causes.** Removing the property statements changed nothing. The role line is what any audit task says. No trajectory searched the web. Nothing to fix there.

**One structural point.** With false findings unscored, an agent that lists every asymmetry it sees gets full recall for free. Nothing you add to the code can lower recall unless it hides the real bug's signal. Decoys are therefore pointless as well as rejected.

## 2. The single change

Change the bug class. Stop planting omissions. Plant mismatched assumptions: two pieces of code that are each correct under their own reading, where the harm appears only when both readings are held at once. The test for a candidate finding: can each function involved pass a local review on its own? If yes, it qualifies. Forgotten lines fail this test; the vault's Aave strategy assuming `aToken` balances are static, or a settlement reading a snapshot another path can move, pass it.

Ranked:

1. **Code-to-code assumption mismatch, picked by root cause.** Choose 2025-26 findings whose summary reads "X assumed Y" rather than "X forgot Z", and port the pair of assumptions, not the line. Cost: a rewritten Opus writer brief, about twice the writer time per task, tasks of 800 to 1,500 lines because the second part must exist, harder proofs, and a judge criterion that names both halves. The root-cause sentence of a finding is enough to sort it, so research stays light.

2. **Code-to-dependency mismatch on a forked real contract.** The protocol integrates a real Aave v3 pool, ERC-4626 vault or Uniswap v4 hook at a pinned block, and the finding rests on how that dependency actually behaves, not how the code's comments say it does. Internet mode becomes an asset: the agent must read docs or the chain, which is audit work. Cost: an Anvil fork in the task environment, which the runner already does for dapp-dev, plus the fork flakiness and the past-block deadlock already seen. Avoid the tropes every model knows: fee-on-transfer, stale Chainlink, `slot0`, first depositor.

3. **Four to six findings per task, mixed severity, score the share.** Cheapest, one writer round. It only amplifies whatever miss rate exists, so it does nothing to omission bugs. Do it alongside option 1, not instead.

Do not: grow the haystack again, strip more README, touch the instruction, or add decoys.

## 3. PR #83

Rework, don't merge: keep it draft, reuse the vault and dex code as the base for option 1 bugs, drop staking and governance, since four all-pass tasks cost a paid run on every release and tell the board nothing.

## 4. When I would stop

Stop if two option-1 tasks of 1,000 to 1,500 lines, each with three or more proven assumption-mismatch findings, still give DeepSeek and Kimi full recall in two trials each, with frontier agents finding everything from a single read and no dependency lookups. Twelve cells, under $10 on the open side. Stop also if the only misses come from crashes or budget, or if the only way left to produce one is a trick. And note the hidden ceiling: the affordable size is set by writer and proof time, not trial cost, since DeepSeek reads 1,200 lines for fifteen cents. If recall only separates agents once precision is scored, and the judge cannot score precision reliably, which round five showed, the audit form has hit its limit at our scale and the honest board entry is "frontier and open agents both find planted bugs at this size".
