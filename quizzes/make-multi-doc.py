import json, re, glob, collections, pathlib
PRE = "You are an expert security researcher and smart contract auditor."
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
rows = []
for p in ("judged-multi-gpt-r*.jsonl","judged-multi2-gpt-r*.jsonl"):
    for f in sorted(glob.glob(p)): rows += [json.loads(l) for l in open(f)]
R = collections.defaultdict(lambda: collections.defaultdict(lambda: {"n":0,"miss":0,"high":0,"false":0}))
for r in rows:
    if not isinstance(r["named"], list): continue
    m = 'opus' if 'opus' in r['model'] else 'gpt' if 'gpt' in r['model'] else 'kimi' if 'kimi' in r['model'] else 'glm'
    q = qs[r["id"]]; t = R[r["id"]][m]; named = set(r["named"]); allset = {i["n"] for i in q["issues"]}; highs = {i["n"] for i in q["issues"] if i["severity"]=="High"}
    t["n"] += 1; t["miss"] += not named >= allset; t["high"] += not named >= highs; t["false"] += bool(r.get("false"))
TITLES = {"vaults-fee-claim-and-mark":"Vault: fee claim and high-water mark","vaults-harvest-redeem-units":"Vault: harvest timing and redeem units","lending-guard-refund-cap":"Lending: same-block guard, refund, cap","fees-keys-subject-and-protocol":"Keys market: subject and protocol fees","lending-pool-cap-and-reserve":"Lending pool: deposit cap and cash reserve","lending-sanctions-escrow":"Lending: sanctions escrow","governance-council":"Governance council","accounts-relayed-wallet":"Relayed smart wallet","auctions-gallery-bids":"Gallery auction bids","staking-withdraw-queue":"Staking withdrawal queue","bridges-message-inbox":"Bridge message inbox","vesting-sponsored-grants":"Sponsored vesting grants"}
out = ["---","author: claude-code","created: 2026-10-30","tags: [proposal, ethevals, security]","---","",
"# security: twelve review questions with several issues each","",
"Each contract below has two or three real issues, every one modelled on a published finding and proven by its own Foundry test. The ask is \"List every issue you would report, one line each.\" Three cold calls per model with the auditor line; the judge is GPT-6.1-sol standing in for Opus until the Anthropic key is topped up. Two columns per model: how many of three replies missed an issue (and how many missed a High), and how many of three claimed a vulnerability the code does not have. The decision is whether the second column counts; see [[security-quizzes]] round five.",""]
for slug in TITLES:
    c = C[slug]; q = qs[slug]
    out += [f"## {TITLES[slug]}", ""]
    out += ["\n".join("> "+l for l in c["instruction"].splitlines()), ""]
    out += ["**the issues:**", ""]
    for line in c["backing"].splitlines():
        if line.strip().startswith("-"): out.append(line.strip()[:400])
    out += ["", f"**judge criterion:** {c['criterion']}", "",
            "| | Opus 5.5 | GPT-6.1-sol | Kimi K3.1 Pro | GLM 5.3 |","|---|---|---|---|---|",
            "| missed an issue (missed a High) | " + " | ".join(f"{R[slug][m]['miss']} ({R[slug][m]['high']}) of {R[slug][m]['n']}" for m in ("opus","gpt","kimi","glm")) + " |",
            "| claimed a false issue | " + " | ".join(f"{R[slug][m]['false']} of {R[slug][m]['n']}" for m in ("opus","gpt","kimi","glm")) + " |", ""]
    if c["verified"]: out += [f"**proved by:** {c['verified'][:300]}", ""]
pathlib.Path("/Users/shivbhonde/Documents/shiv/1. Projects/ethevals/security-multi-issue-candidates.md").write_text("\n".join(out)+"\n"); print("written", len(TITLES))
