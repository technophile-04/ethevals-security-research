"""Re-judge UNPARSED rows in an Opus-judged file with a larger output budget, patching them in place."""
import asyncio, json, sys, pathlib, re, importlib.util
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
def prompt_from(script):
    spec = importlib.util.spec_from_file_location("j", ROOT/script); src = (ROOT/script).read_text()
    return re.search(r'PROMPT = """(.*?)"""', src, flags=re.S).group(1)
async def main(script, qfile, replies, judged):
    PROMPT = prompt_from(script); qs = {q["id"]: q for q in json.loads((ROOT/qfile).read_text())}
    reps = {(r["id"], r["model"]): r for r in map(json.loads, open(replies))}
    rows = [json.loads(l) for l in open(judged)]; spent = 0.0; fixed = 0
    for row in rows:
        if row["named"] != "UNPARSED": continue
        q = qs[row["id"]]; rep = reps[(row["id"], row["model"])]["reply"]
        resp = await litellm.acompletion(model="anthropic/claude-opus-5-5", max_tokens=4000, messages=[{"role": "user", "content": PROMPT.format(instruction=q["instruction"], answer=q["answer"], criterion=q["criterion"], reply=rep)}])
        txt = (resp.choices[0].message.content or "").strip(); spent += float(litellm.completion_cost(resp))
        m = re.search(r"NAMED:\s*([^\n]*)", txt); f = re.search(r"FALSE:\s*(yes|no)", txt, flags=re.I)
        row["named"] = sorted({int(x) for x in re.findall(r"\d+", m.group(1))}) if m else "UNPARSED"
        row["false"] = (f.group(1).lower() == "yes") if f else None; row["reason"] = txt[:300]; fixed += row["named"] != "UNPARSED"
        print(row["id"], row["model"], "->", row["named"], row["false"], "|", txt[:120].replace("\n", " "))
    with open(judged, "w") as fh:
        for row in rows: fh.write(json.dumps(row) + "\n")
    print(json.dumps({"fixed": fixed, "spend": round(spent, 4)}))
asyncio.run(main(*sys.argv[1:]))
