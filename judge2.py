"""Re-judge rows whose verdict was UNPARSED, recording finish_reason, with a larger output budget."""
import asyncio, json, sys, pathlib, re, collections
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
JUDGE = "anthropic/claude-opus-5-5"
qs = {q["id"]: q for q in json.loads((ROOT/"questions-judge.json").read_text())}
PROMPT = open(ROOT/"judge.py").read().split('PROMPT = """')[1].split('"""')[0]
async def main():
    sem = asyncio.Semaphore(4); out = []; fr = collections.Counter()
    async def one(n, r, rep):
        q = qs[r["id"]]
        async with sem:
            resp = await litellm.acompletion(model=JUDGE, max_tokens=1200,
                messages=[{"role": "user", "content": PROMPT.format(instruction=q["instruction"], answer=q["answer"], criterion=q["criterion"], reply=rep)}])
            txt = (resp.choices[0].message.content or "").strip(); fin = resp.choices[0].finish_reason
            m = re.search(r"\b(PASS|FAIL)\b", txt); fr[fin] += 1
            out.append({"round": n, "id": r["id"], "model": r["model"], "verdict": m.group(1) if m else "UNPARSED", "finish_reason": fin, "reason": txt[:300]})
    jobs = []
    for n in (1, 2, 3):
        replies = {(x["id"], x["model"]): x.get("reply") or "" for x in map(json.loads, open(ROOT/f"replies-judge-r{n}.jsonl"))}
        for r in map(json.loads, open(ROOT/f"judged-r{n}.jsonl")):
            if r["verdict"] not in ("PASS", "FAIL", "NOREPLY"): jobs.append(one(n, r, replies[(r["id"], r["model"])]))
    await asyncio.gather(*jobs)
    with open(ROOT/"judged-rejudge.jsonl", "w") as f:
        for row in out: f.write(json.dumps(row) + "\n")
    print(json.dumps({"rejudged": len(out), "finish_reasons": dict(fr), "verdicts": dict(collections.Counter(o["verdict"] for o in out))}))
asyncio.run(main())
