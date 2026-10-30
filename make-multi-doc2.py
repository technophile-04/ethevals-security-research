import json, re, glob, collections, pathlib
def field(b, name):
    m = re.search(r'\*\*'+re.escape(name)+r':\*\*(.*?)(?=\n\*\*[A-Z][^*]*:\*\*|\Z)', b, flags=re.S); return m.group(1).strip() if m else ""
C = {}
for f in ("pilot-multi-opus.md","pilot-multi-opus2.md"):
    for b in re.split(r'^### ', pathlib.Path(f).read_text(), flags=re.M)[1:]:
        slug = b.split("\n",1)[0].strip()
        if slug.lower().startswith("rejected"): continue
        C[slug] = {"instruction": field(b,"Instruction"), "backing": field(b,"Backing"), "criterion": field(b,"Judge criterion"), "answer": field(b,"Answer"), "verified": field(b,"Verified by")}
qs = {}
for f in ("questions-multi.json","questions-multi2.json"): qs.update({q["id"]: q for q in json.load(open(f))})
def mdl(m): return 'opus' if 'opus' in m else 'gpt' if 'gpt' in m else 'kimi' if 'kimi' in m else 'glm'
def tally(pats):
    R = collections.defaultdict(lambda: collections.defaultdict(lambda: {"n":0,"miss":0,"high":0,"false":0,"strict":0}))
    for p in pats:
        for f in sorted(glob.glob(p)):
            for l in open(f):
                r = json.loads(l)
                if not isinstance(r["named"], list): continue
                q = qs[r["id"]]; t = R[r["id"]][mdl(r["model"])]; named = set(r["named"]); allset = {i["n"] for i in q["issues"]}; highs = {i["n"] for i in q["issues"] if i["severity"]=="High"}
                t["n"] += 1; t["miss"] += not named >= allset; t["high"] += not named >= highs; t["false"] += bool(r.get("false")); t["strict"] += (named >= allset and not r.get("false"))
    return R
O = tally(("judged-multi-opus-r*.jsonl","judged-multi2-opus-r*.jsonl")); G = tally(("judged-multi-gpt-r*.jsonl","judged-multi2-gpt-r*.jsonl"))
TITLES = {"vaults-fee-claim-and-mark":"Vault: fee claim and high-water mark","vaults-harvest-redeem-units":"Vault: harvest timing and redeem units","lending-guard-refund-cap":"Lending: same-block guard, refund, cap","fees-keys-subject-and-protocol":"Keys market: subject and protocol fees","lending-pool-cap-and-reserve":"Lending pool: deposit cap and cash reserve","lending-sanctions-escrow":"Lending: sanctions escrow","governance-council":"Governance council","accounts-relayed-wallet":"Relayed smart wallet","auctions-gallery-bids":"Gallery auction bids","staking-withdraw-queue":"Staking withdrawal queue","bridges-message-inbox":"Bridge message inbox","vesting-sponsored-grants":"Sponsored vesting grants"}
M = ("opus","gpt","kimi","glm")
out = ["---","author: claude-code","created: 2026-10-30","updated: 2026-10-30","tags: [proposal, ethevals, security]","---","",
"# security: twelve review questions with several issues each","",
"Each contract below has two or three real issues, every one modelled on a published finding and proven by its own Foundry test. The ask is \"List every issue you would report, one line each.\" Three cold calls per model with the auditor line. Every reply was judged twice with the same prompt: by Opus 5.5 after Shiv topped up the Anthropic key on the morning of 10-30, and before that by GPT-6.1-sol standing in. The two judges name the same issue set on 136 of 137 replies, so the completeness row is shown once. They disagree on the false-claim flag on 36 of 137 replies, so that row is shown for each judge. The strict row counts replies that named every issue and claimed nothing false, under the Opus judge. Opus has two graded replies instead of three on six contracts because the key ran out during its third call; filling them costs about a dollar. The decision is whether precision counts, and if so, how it is pinned down; see [[security-quizzes]] round five.",""]
for slug in TITLES:
    c = C[slug]; q = qs[slug]
    out += [f"## {TITLES[slug]}", ""]
    out += ["\n".join("> "+l for l in c["instruction"].splitlines()), ""]
    out += ["**the issues:**", ""]
    for line in c["backing"].splitlines():
        if line.strip().startswith("-"): out.append(line.strip()[:400])
    out += ["", f"**judge criterion:** {c['criterion']}", "",
            "| | Opus 5.5 | GPT-6.1-sol | Kimi K3.1 Pro | GLM 5.3 |","|---|---|---|---|---|",
            "| missed an issue (missed a High) | " + " | ".join(f"{O[slug][m]['miss']} ({O[slug][m]['high']}) of {O[slug][m]['n']}" for m in M) + " |",
            "| claimed a false issue, Opus judge | " + " | ".join(f"{O[slug][m]['false']} of {O[slug][m]['n']}" for m in M) + " |",
            "| claimed a false issue, GPT judge | " + " | ".join(f"{G[slug][m]['false']} of {G[slug][m]['n']}" for m in M) + " |",
            "| strict pass, Opus judge | " + " | ".join(f"{O[slug][m]['strict']} of {O[slug][m]['n']}" for m in M) + " |", ""]
    if c["verified"]: out += [f"**proved by:** {c['verified'][:300]}", ""]
pathlib.Path("/Users/shivbhonde/Documents/shiv/1. Projects/ethevals/security-multi-issue-candidates.md").write_text("\n".join(out)+"\n"); print("written", len(TITLES))
