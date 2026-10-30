import json, re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent
PRE = "You are an expert security researcher and smart contract auditor."
def field(b, name):
    m = re.search(r'\*\*'+re.escape(name)+r':\*\*(.*?)(?=\n\*\*[A-Z][^*]*:\*\*|\Z)', b, flags=re.S); return m.group(1).strip() if m else ""
C = {}
for f in ["accounts","signatures","tokens","upgrades","defi","evm","pilot-opus"]:
    for b in re.split(r'^### ', (ROOT/f"{f}.md").read_text(), flags=re.M)[1:]:
        slug = b.split("\n",1)[0].strip()
        C[slug] = {"instruction": field(b,"Instruction"), "answer": field(b,"Answer"), "backing": field(b,"Backing"), "spec": field(b,"Spec source"), "verified": field(b,"Verified by")}
rates = json.load(open(ROOT/"rates-3x.json"))
CHK = {}
for b in re.split(r'^### ', (ROOT/"currency-check.md").read_text(), flags=re.M)[1:]:
    slug = b.split("\n",1)[0].strip()
    h = re.search(r'\*\*Holds today\?\*\*\s*(.*)', b); l = re.search(r'\*\*Incident link real\?\*\*\s*(.*)', b)
    CHK[slug] = (h.group(1).strip() if h else "", l.group(1).strip() if l else "")
def gtype(instr):
    tail = instr.strip().splitlines()[-1].lower()
    if "yes or no" in tail: return "yes or no, pattern on the first word"
    if "number only" in tail or "with the number" in tail: return "a number, pattern on the first word"
    m = re.search(r'answer ([a-z0-9\'’ ]+?) or ([a-z0-9\'’ ]+?)[,.]', tail)
    return (f"{m.group(1)} or {m.group(2)}, pattern on the first word" if m else "pattern on the first word")
def cellv(t):
    s = f"{t['miss']} of 3"
    if t['filtered']: s += f", {t['filtered']} blocked by the filter"
    if t['cut']: s += f", {t['cut']} cut off"
    return s
GROUPS = [
 ("signatures and accounts, on today's standards", [
  ("accounts-7739-typeddatasign-domain", "Which domain goes first when a smart account signs a dapp's message",
   "whether the model knows how ERC-7739 wraps a dapp's typed data so one owner key cannot have its signature replayed across its smart accounts, and which domain separator sits next to the 0x1901 prefix in the final digest."),
  ("accounts-1271-permit2-cross-account-replay", "One signature, two smart accounts",
   "whether the model sees that Permit2's permit struct has no owner field, so a naive ERC-1271 account lets a signature meant for account A create an allowance on account B."),
  ("signatures-permit2-signaturetransfer-frontrun", "Can a searcher take a Permit2 transfer from the mempool",
   "whether the model knows Permit2's SignatureTransfer hashes the caller in as the spender, so a copied signature is useless to anyone but the intended contract. The reflex says front-run; the answer is no."),
  ("signatures-oz-ecdsa-signature-as-key", "Marking a signature as used",
   "whether the model knows OpenZeppelin 5.x's ECDSA rejects the high-s twin and the 64-byte form, so keying a one-time voucher on the signature bytes is safe. The reflex says malleable; the answer is no."),
  ("accounts-4337-unused-gas-penalty", "Paying for gas you did not use",
   "whether the model knows EntryPoint v0.7 and v0.8 charge a 10% penalty on unused execution gas, taken from the paymaster's deposit and paid to the bundler, so a generous gas limit is a cost."),
 ]),
 ("Solidity as it ships today", [
  ("compiler-legacy-init-order", "owner() at declaration time",
   "whether the model knows that on the default (legacy) pipeline every state-variable initializer runs before any constructor, so `feeRecipient = owner()` stores the zero address."),
  ("compiler-tuple-assignment-self-transfer", "Sending tokens to yourself",
   "whether the model computes the real result of a tuple assignment on a self-transfer: Solidity writes the components right to left, so the balance drops to 60 instead of inflating to 140."),
  ("evm-try-catch-empty-return", "try/catch does not catch a missing contract",
   "whether the model knows a call to an address with no code succeeds with empty return data, and decoding that empty data reverts outside the catch, so a borrower can block their own liquidation with an EOA hook."),
  ("forwarder-multicall-suffix-oz5", "Forged sender through multicall, after the fix",
   "whether the model knows OpenZeppelin 5.x's Multicall strips a forged ERC-2771 sender suffix, so the 2023 spoofing trick no longer authorizes anything. The reflex says vulnerable; the answer is no."),
  ("upgrades-stateless-parent-gap", "Adding a parent to an upgradeable contract",
   "whether the model knows an OpenZeppelin 4.9 upgradeable parent with no variables still carries a 50-slot gap, so appending it in V2 shifts every balance to a different slot and reads zero."),
  ("evm-transfer-refund-to-safe", "An ETH refund to a Safe under the 2,300 gas stipend",
   "whether the model knows `transfer`'s 2,300 gas is enough for a Safe's fallback only when the Safe's storage is already warm, which it is when the Safe itself made the call."),
 ]),
 ("recent compiler bugs, on versions people run today", [
  ("compiler-transient-clear-collision", "delete on a transient variable",
   "whether the model knows the 0.8.28 to 0.8.33 via-IR bug that merges the clearing helpers of a transient and a storage address, so `renounceOwnership` leaves the pending owner in place. Fixed in 0.8.34."),
  ("compiler-memory-bytes-delete", "delete on one byte wipes 32",
   "whether the model knows the legacy code generator's `delete` on a memory bytes element zeroes a full word in 0.8.30 to 0.8.36, wiping the recipient in a packed payload. Fixed in 0.8.37."),
 ]),
]
TRIM = {"accounts-4337-unused-gas-penalty": "drop the sentence 'A typical operation uses about 150,000 gas in execution.' before it ships, then re-screen"}
out = ["---","author: claude-code","created: 2026-10-30","tags: [proposal, ethevals, security]","---","",
"# security domain: the first tasks","",
"Written [[2026-10-30]] for [[shiv]] and [[carlos]]. Thirteen questions, picked from 96 screened candidates for three things: a non-expert can read them, they hold on versions people run today, and an open model missed them in cold calls. The intention paragraph below is written to be shown as is.","",
"## our intention","",
"The security domain asks whether a model, with no tools and no web, knows the security-relevant behaviour of today's Ethereum stack well enough to review code the way a careful auditor would: smart-account standards (ERC-4337, EIP-7702, ERC-1271 and ERC-7739), signatures and approvals (Permit2, EIP-712, ECDSA), what Solidity does on the compiler people ship with, and how upgradeable contracts keep their storage. Each question is short, usually about a code snippet, opens with the line \"You are an expert security researcher and smart contract auditor.\", and has one fixed answer checked by a rule on the first word.","",
"Every kept question rests on something real: a disclosed bug, a post-mortem, an advisory, or the compiler's own documented behaviour. Where the question is about what code does, the key is proven by compiling and running that code in a Foundry test with the compiler version pinned, not by our reading. And every kept question was missed by an open model (Kimi K3.1 Pro or GLM 5.3) in at least two of three cold calls. Frontier models are recorded, not required: across 96 questions GPT-6.1-sol missed only compiler-behaviour ones, and we did not want a domain made of compiler trivia.","",
"We deliberately left out CTF puzzles, questions phrased as attacks, and bugs that only exist on old compilers (one is included as optional). We are not security experts. The keys stand on execution and on the specs, and we would welcome review from people who audit for a living. Two other approaches were tried and dropped: 84 questions about spec facts, which every frontier model answered, and nine agent-run code-review excerpts with real bugs planted, which all three agents found; those sit in docs/research/ for reference.","",
"On looking it up: these questions measure what a bare model carries in its head, which is why the bar is a cold miss with no web. The board also runs every quiz in internet and skills modes, where the question becomes whether the agent knows to look and reads the spec right; a spec question like number 1 is findable there, which is the point of the mode column. The Solidity-behaviour questions are harder to look up: the honest way to answer them is to compile and run the snippet, which an agent with tools can do and a bare model cannot.", "",
"How to read the tables: three cold calls per model, with the auditor line in front. \"blocked by the filter\" means Anthropic's API refused to answer; \"cut off\" means GLM ran out of output tokens. Neither counts as a miss.",""]
n = 0
for title, items in GROUPS:
    out += [f"## {title}", ""]
    for slug, plain, tests in items:
        n += 1; c = C[slug]; r = rates[slug]
        instr = c["instruction"]
        if not instr.startswith(PRE): instr = PRE + "\n\n" + instr
        out += [f"### {n}. {plain}", "", f"**tests:** {tests}", "", f"**because:** {c['backing']}", ""]
        out += ["\n".join("> "+l for l in instr.splitlines()), "", f"**key:** {c['answer']}", "", f"**checked by:** {gtype(c['instruction'])}", ""]
        if c["verified"]: out += [f"**proved by:** {c['verified']}", ""]
        if slug in CHK:
            out += [f"**checked on current versions (GPT-6.1-sol, 30 Oct):** {CHK[slug][0]}", "", f"**link check:** {CHK[slug][1]}", ""]
        out += ["| Opus 5.5 | GPT-6.1-sol | Kimi K3.1 Pro | GLM 5.3 |", "|---|---|---|---|",
                "| " + " | ".join(cellv(r[m]) for m in ("opus","gpt","kimi","glm")) + " |", ""]
        if slug in TRIM: out += [f"**before it ships:** {TRIM[slug]}", ""]
out += ["## left out, and why", "",
"- Safe guard versus module (Safe 1.4.1): a real gap, but with the auditor line no model missed it in three calls.",
"- Safe v1.1.1 cross-chain replay and the Vyper 0.2.16 lock: old versions.",
"- The eval-order self-transfer: a twin of the tuple question.",
"- The OpenZeppelin ProxyAdmin constructor: the fact-checker called it ambiguous.",
"- The OpenZeppelin 5.6 empty-init revert: a failed deploy, not a loss.",
"- The assembly write-removal: old compiler, and only one miss in three.",
"- The WETH phantom permit: no open-model miss, and Anthropic's filter blocked it every time.",
"- The 0.8.16 storage-write-removal question that every model misses: an old compiler; Shiv said leave it.",
"- The two judge-graded Safe questions (delegatecall payload, domain fields): every model answered them right.",
"- Seventy-four other spec-fact questions from round one that every model answered, kept in /tmp/subagents/security-quizzes/ as a pool.", "",
"## what happens next", "",
"1. Shiv marks any of the thirteen he wants dropped in Plannotator; number 1 is a keep.",
"2. GPT-6.1-sol is checking, right now, that each answer holds on the latest released versions and that each incident link is real; its findings get folded into the \"because\" lines.",
"Three the checker would worry about: the tuple self-transfer rests on how the compiler is implemented rather than a promised language rule (the proof covers 0.8.20 to 0.8.38, both pipelines); the memory-bytes delete is a disclosure with no known affected deployment; the Safe refund's help-centre link is dead, so its backing is the Safe 1.5 source and the proof.", "",
"3. The kept ones become task folders under tasks/concepts/, tagged security on the board, each with its Foundry proof where there is one, then go through the runner's own trials before a PR.",""]
pathlib.Path(sys.argv[1]).write_text("\n".join(out)+"\n"); print("tasks:", n)
