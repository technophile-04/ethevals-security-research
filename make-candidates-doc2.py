"""Candidates note, v2: only quizzes both open models or a frontier model missed; grouped by grading type; backing strength shown."""
import json, re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent
PRE = "You are an expert security researcher and smart contract auditor."
FILES = ["accounts","signatures","tokens","upgrades","defi","evm","pilot-opus"]
def field(b, name):
    m = re.search(r'\*\*'+re.escape(name)+r':\*\*(.*?)(?=\n\*\*[A-Z][^*]*:\*\*|\Z)', b, flags=re.S)
    return m.group(1).strip() if m else ""
CANDS = {}
for f in FILES:
    for b in re.split(r'^### ', (ROOT/f"{f}.md").read_text(), flags=re.M)[1:]:
        slug = b.split("\n",1)[0].strip()
        if slug.lower().startswith("rejected"): continue
        CANDS[slug] = {"instruction": field(b,"Instruction"), "answer": field(b,"Answer"), "backing": field(b,"Backing"),
                       "spec": field(b,"Spec source"), "verified": field(b,"Verified by")}
TRIM = {"accounts-4337-unused-gas-penalty": "drop 'A typical operation uses about 150,000 gas in execution.' (Shiv, 10-29); re-screen after"}
def gtype(instr):
    tail = instr.strip().splitlines()[-1].lower()
    if "yes or no" in tail: return "yes or no"
    if "number only" in tail or "with the number" in tail: return "number only"
    if "in one sentence" in tail and "then explain" not in tail: return "judge"
    m = re.search(r'answer ([a-z0-9\'’ ]+?) or ([a-z0-9\'’ ]+?)[,.]', tail)
    return f"{m.group(1)} or {m.group(2)}" if m else "pattern"
WEAK = ("no named", "no incident", "weak backing", "i found no", "not verified", "secondary source")
def strength(backing):
    bl = backing.lower()
    return "weak" if any(w in bl for w in WEAK) or "http" not in bl else "named incident"
MODELS = [("opus","Opus 5.5"),("gpt","GPT-6.1-sol"),("kimi","Kimi K3.1"),("glm","GLM 5.3")]
def cell(v):
    if not v: return "–"
    if v == "ok": return "right"
    if v.startswith("MISS"): return "**missed**"
    if "content_filter" in v: return "filtered"
    if "length" in v: return "cut off"
    return "error"
grades = json.load(open(ROOT/sys.argv[1]))
def miss(v,m): return v.get(m,"").startswith("MISS")
shown, rest = [], []
for slug, g in grades.items():
    if slug not in CANDS: continue
    both_open = miss(g,"kimi") and miss(g,"glm"); frontier = miss(g,"opus") or miss(g,"gpt")
    (shown if (both_open or frontier) else rest).append(slug)
groups = {}
for slug in shown: groups.setdefault(gtype(CANDS[slug]["instruction"]), []).append(slug)
out = ["---","author: claude-code","created: 2026-10-29","tags: [proposal, ethevals, security]","---","",
       "# security quizzes: the ones that bite", "",
       f"Only quizzes where both open models missed, or a frontier model missed, one cold call each with \"{PRE}\" in front. Grouped by how the answer is checked. The other {len(rest)} candidates, where one open model missed, are in the table at the end. Process and numbers: [[security-quizzes]].", ""]
for gt in ["yes or no", "number only", "judge"] + sorted(k for k in groups if k not in ("yes or no","number only","judge")):
    if gt not in groups: continue
    out += [f"# checked by: {gt}" + ("  (LLM judge reads the sentence)" if gt=="judge" else "  (pattern on the first word)"), ""]
    for slug in groups[gt]:
        c = CANDS[slug]; g = grades[slug]
        instr = c["instruction"]
        if not instr.startswith(PRE): instr = PRE + "\n\n" + instr
        quoted = "\n".join("> "+l for l in instr.splitlines())
        who = [n for m,n in MODELS if miss(g,m)]
        out += [f"## {slug}", "", quoted, "", f"**key:** {c['answer'].split(chr(10))[0]}", "",
                f"**why it matters ({strength(c['backing'])}):** {c['backing']}", ""]
        if c["verified"]: out += [f"**proved by:** {c['verified']}", ""]
        out += ["| " + " | ".join(n for _,n in MODELS) + " |", "|"+"---|"*len(MODELS),
                "| " + " | ".join(cell(g.get(m,"")) for m,_ in MODELS) + " |", ""]
        out += [f"**missed by:** {', '.join(who)}"]
        if slug in TRIM: out += ["", f"**trim:** {TRIM[slug]}"]
        out += [""]
# judge-graded candidates: shown even though every model answered them right (round one, without the auditor line)
g1 = json.load(open(ROOT/"grades-all.json"))
judges = []  # Shiv 10-29: the two judge-graded candidates are dropped, every model answered them right
if judges:
    out += ["# checked by: judge  (LLM judge reads the one-sentence answer)", "",
            "Only two candidates in the whole pool are judge-graded, because the brief asked for a fixed-form answer wherever one exists. Every model answered both right in round one, so neither is in the pool above. They are here so the judge form can be seen next to the pattern forms.", ""]
    for slug in judges:
        c = CANDS[slug]; g = g1[slug]
        instr = c["instruction"]
        if not instr.startswith(PRE): instr = PRE + "\n\n" + instr
        out += [f"## {slug}", "", "\n".join("> "+l for l in instr.splitlines()), "", f"**key:** {c['answer'].split(chr(10))[0]}", "",
                f"**why it matters ({strength(c['backing'])}):** {c['backing']}", "",
                "| " + " | ".join(n for _,n in MODELS) + " |", "|"+"---|"*len(MODELS),
                "| " + " | ".join(cell(g.get(m,"")) for m,_ in MODELS) + " |", "", "**missed by:** nobody", ""]
out += ["# the rest: one open model missed", "", "| quiz | checked by | backing | missed by |", "|---|---|---|---|"]
for slug in rest:
    c = CANDS[slug]; g = grades[slug]; who = [n for m,n in MODELS if miss(g,m)]
    out.append(f"| {slug} | {gtype(c['instruction'])} | {strength(c['backing'])} | {', '.join(who) or 'nobody this run'} |")
PICKS = [
 ("compiler-memory-bytes-delete", "silent recipient wipe in a bridge payload on the default legacy pipeline, 0.8.30 to 0.8.36, disclosed Sep 2026; Opus missed it in round two"),
 ("accounts-1271-permit2-cross-account-replay", "an allowance on an account the user never signed for; live for every ERC-1271 wallet without ERC-7739, Alchemy disclosure 2023"),
 ("accounts-safe-guard-module-path", "a 100 ETH guard that a module walks past; Safe 1.4.1 is what most treasuries run; GLM missed it in round one"),
 ("accounts-4337-unused-gas-penalty", "a paymaster deposit drained by its own gas limits on EntryPoint v0.7 and v0.8, Osec Dec 2025; trim the 150,000 gas sentence first"),
 ("signatures-oz-ecdsa-signature-as-key", "the one 'it is fine' question worth keeping: the textbook says malleable, OpenZeppelin 5.x says no; an auditor who flags it wastes a client's week"),
]
out += ["", "# my picks from the rest", "", "Judged on how bad the outcome is and how likely it is on today's versions, by vibes as asked:", ""]
for slug, why in PICKS: out.append(f"- **{slug}**: {why}")
out += ["", "Left out: the Safe v1.1.1 cross-chain replay (old singleton), the WETH phantom permit (well known since 2022), the OZ 5.6 empty-init revert (a failed deploy, not a loss), the assembly write-removal (old compilers), the self-transfer eval-order twin (the tuple one covers it), the OZ 5.4 forwarder suffix (safe on current code), and the ProxyAdmin constructor (the fact-checker called it ambiguous)."]
pathlib.Path(sys.argv[2]).write_text("\n".join(out)+"\n")
print("shown:", len(shown), "rest:", len(rest), "| groups:", {k:len(v) for k,v in groups.items()})
