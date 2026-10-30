"""Judge replies to multi-issue questions: which issues were named, and was a false vulnerability claimed."""
import asyncio, json, sys, pathlib, re, collections
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
JUDGE = "openai/gpt-6.1-sol"
qs = {q["id"]: q for q in json.loads((ROOT/"questions-multi2.json").read_text())}
PROMPT = """You are grading one reply to a code-review question that asked the reviewer to list every issue they would report. Use the criterion, which numbers the real issues. Decide, for each numbered issue, whether the reply names it with its mechanism (not just a hint). Decide also whether the reply claims a vulnerability the code does not have; a harmless style, gas or hygiene remark is not a false claim. A hedge ("may or may not") on an issue does not count as naming it.

Question:
{instruction}

Reference answer:
{answer}

Criterion:
{criterion}

Reply to grade:
<<<
{reply}
>>>

Output exactly two lines:
NAMED: <comma-separated issue numbers the reply names, or none>
FALSE: <yes or no>
Then one sentence of reason."""
async def main(infile, outfile, cap):
    rows = [json.loads(l) for l in open(infile)]
    sem = asyncio.Semaphore(4); spent = 0.0; out = []
    async def one(r):
        nonlocal spent
        q = qs[r["id"]]; rep = r.get("reply") or ""
        row = {"id": r["id"], "model": r["model"], "named": None, "false": None, "reason": None, "cost": 0.0}
        if not rep: row["named"] = "NOREPLY"; row["reason"] = (r.get("error") or "")[:80]; out.append(row); return
        async with sem:
            if spent > cap: row["named"] = "SKIPPED"; out.append(row); return
            resp = await litellm.acompletion(model=JUDGE, max_tokens=1200, messages=[{"role": "user", "content": PROMPT.format(instruction=q["instruction"], answer=q["answer"], criterion=q["criterion"], reply=rep)}])
            txt = (resp.choices[0].message.content or "").strip()
            try: row["cost"] = float(litellm.completion_cost(resp)); spent += row["cost"]
            except Exception: pass
            m = re.search(r"NAMED:\s*([^\n]*)", txt); f = re.search(r"FALSE:\s*(yes|no)", txt, flags=re.I)
            row["named"] = sorted({int(x) for x in re.findall(r"\d+", m.group(1))}) if m else "UNPARSED"
            row["false"] = (f.group(1).lower() == "yes") if f else None; row["reason"] = txt[:300]; out.append(row)
    await asyncio.gather(*(one(r) for r in rows))
    with open(outfile, "w") as fh:
        for row in out: fh.write(json.dumps(row) + "\n")
    print(json.dumps({"judged": len(out), "spend": round(spent, 4)}))
asyncio.run(main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 2.0))
