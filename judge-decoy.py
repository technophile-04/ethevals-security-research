"""Judge saved replies against each question's criterion with Opus 5.5. One call per reply; writes judged-<round>.jsonl."""
import asyncio, json, sys, pathlib, re
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
JUDGE = "anthropic/claude-opus-5-5"
qs = {q["id"]: q for q in json.loads((ROOT/"questions-decoy.json").read_text())}
PROMPT = """You are grading one reply to a code-review question. Apply the criterion literally. A reply that hedges between two causes, names a different bug, or contradicts itself fails.

Question:
{instruction}

Reference answer (for your eyes only):
{answer}

Criterion:
{criterion}

Reply to grade:
<<<
{reply}
>>>

Output exactly one line: PASS or FAIL, then a colon and one sentence of reason."""
async def main(infile, outfile, cap):
    rows = [json.loads(l) for l in open(infile)]
    sem = asyncio.Semaphore(4); spent = 0.0; out = []
    async def one(r):
        nonlocal spent
        q = qs[r["id"]]; rep = r.get("reply") or ""
        row = {"id": r["id"], "model": r["model"], "verdict": None, "reason": None, "cost": 0.0}
        if not rep:
            row["verdict"] = "NOREPLY"; row["reason"] = (r.get("error") or "")[:80]; out.append(row); return
        async with sem:
            if spent > cap: row["verdict"] = "SKIPPED"; row["reason"] = "cap"; out.append(row); return
            resp = await litellm.acompletion(model=JUDGE, max_tokens=1200,
                messages=[{"role": "user", "content": PROMPT.format(instruction=q["instruction"], answer=q["answer"], criterion=q["criterion"], reply=rep)}])
            txt = (resp.choices[0].message.content or "").strip()
            try: row["cost"] = float(litellm.completion_cost(resp)); spent += row["cost"]
            except Exception: pass
            m = re.match(r"\s*(PASS|FAIL)\b[:\s]*(.*)", txt, flags=re.S)
            row["verdict"] = m.group(1) if m else "UNPARSED"; row["reason"] = (m.group(2) if m else txt)[:300]
            out.append(row)
    await asyncio.gather(*(one(r) for r in rows))
    with open(outfile, "w") as f:
        for row in out: f.write(json.dumps(row) + "\n")
    print(json.dumps({"judged": len(out), "spend": round(spent, 4)}))
if __name__ == "__main__":
    asyncio.run(main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 1.5))
