"""Build the candidates review note: one section per surviving quiz, instruction first."""
import json, re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent
PRE = "You are an expert security researcher and smart contract auditor."
FILES = ["accounts","signatures","tokens","upgrades","defi","evm","pilot-opus"]
VERDICTS = {}
for fc in ["factcheck-a.md","factcheck-b.md","factcheck-c.md"]:
    t = (ROOT/fc).read_text()
    for b in re.split(r'^### ', t, flags=re.M)[1:]:
        slug = b.split("\n",1)[0].strip()
        v = re.search(r'Verdict:\s*(\w+)', b); n = re.search(r'Note:\s*(.*)', b)
        VERDICTS[slug] = (v.group(1) if v else "?", (n.group(1).strip() if n else ""))
def field(b, name):
    m = re.search(r'\*\*'+re.escape(name)+r':\*\*(.*?)(?=\n\*\*[A-Z][^*]*:\*\*|\Z)', b, flags=re.S)
    return m.group(1).strip() if m else ""
CANDS = {}
for f in FILES:
    for b in re.split(r'^### ', (ROOT/f"{f}.md").read_text(), flags=re.M)[1:]:
        slug = b.split("\n",1)[0].strip()
        if slug.lower().startswith("rejected"): continue
        CANDS[slug] = {"file": f, "instruction": field(b,"Instruction"), "answer": field(b,"Answer"),
                       "why": field(b,"Why a model gets it wrong"), "backing": field(b,"Backing"),
                       "spec": field(b,"Spec source"), "verified": field(b,"Verified by")}
grades = json.load(open(ROOT/sys.argv[1]))          # {id: {model: verdict}}
order = [l.strip() for l in open(ROOT/"rescreen-order.txt")] if (ROOT/"rescreen-order.txt").exists() else list(grades)
MODELS = [("opus","Opus 5.5"),("gpt","GPT-6.1-sol"),("kimi","Kimi K3.1"),("glm","GLM 5.3")]
def cell(v):
    if not v: return "–"
    if v == "ok": return "right"
    if v.startswith("MISS"): return "**missed**"
    if "content_filter" in v or "EmptyR" in v: return "filtered"
    return "error"
out = ["---","author: claude-code","created: 2026-10-29","tags: [proposal, ethevals, security]","---","",
       "# security quizzes: the candidates","",
       f"Each quiz below opens with the line Shiv chose, \"{PRE}\" Results are from one cold call per model with that line in front; a three-sample repeat is running to turn single shots into miss rates. Numbers and process are in [[security-quizzes]].",""]
full, dapp = [], []
for slug in order:
    c = CANDS.get(slug); g = grades.get(slug, {})
    if not c: continue
    fm = any(g.get(m,"").startswith("MISS") for m in ("opus","gpt")); om = any(g.get(m,"").startswith("MISS") for m in ("kimi","glm"))
    (full if (fm and om) else dapp).append(slug)
    instr = c["instruction"]
    if not instr.startswith(PRE): instr = PRE + "\n\n" + instr
    quoted = "\n".join("> "+l for l in instr.splitlines())
    key = c["answer"].split("\n")[0]
    bar = "frontier and open model miss" if (fm and om) else ("open model miss" if om else "no miss")
    out += [f"## {slug}", "", quoted, "", f"**key:** {key}", ""]
    out += [f"**why it matters:** {c['backing']}", ""]
    if c["verified"]: out += [f"**proved by:** {c['verified']}", ""]
    out += ["| " + " | ".join(n for _,n in MODELS) + " |", "|"+"---|"*len(MODELS),
            "| " + " | ".join(cell(g.get(m,"")) for m,_ in MODELS) + " |", "", f"**bar:** {bar}"]
    v = VERDICTS.get(slug)
    if v and v[0] != "CORRECT": out += ["", f"**fact-check:** {v[0].lower()}. {v[1]}"]
    out += [""]
summary = f"{len(full)} meet the full bar (an open model and a frontier model miss), {len(dapp)} meet the dapp-dev bar (an open model misses)."
out.insert(9, summary); out.insert(10, "")
pathlib.Path(sys.argv[2]).write_text("\n".join(out))
print(summary, "| sections:", len(full)+len(dapp))
