"""Judge the explanations in saved replies to the thirteen pattern quizzes: does the reason match the key's mechanism?"""
import asyncio, json, sys, pathlib, re, collections
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
JUDGE = "anthropic/claude-opus-5-5"
KEEP = ["accounts-7739-typeddatasign-domain","accounts-1271-permit2-cross-account-replay","signatures-permit2-signaturetransfer-frontrun","signatures-oz-ecdsa-signature-as-key","accounts-4337-unused-gas-penalty","compiler-legacy-init-order","compiler-tuple-assignment-self-transfer","evm-try-catch-empty-return","forwarder-multicall-suffix-oz5","upgrades-stateless-parent-gap","evm-transfer-refund-to-safe","compiler-transient-clear-collision","compiler-memory-bytes-delete"]
qs = {q["id"]: q for q in json.loads((ROOT/"questions-rescreen.json").read_text())}
PROMPT = """You are grading the explanation in one reply to a code-review question. The reply opens with a short answer and then explains. Grade only the explanation: does it give the same mechanism as the reference answer, in substance? A right first word with a wrong, missing, vague or contradictory reason FAILS. Extra true detail is fine. A reply that names a different mechanism as the reason FAILS even if its first word matches.

Question:
{instruction}

Reference answer and mechanism:
{answer}

Reply to grade:
<<<
{reply}
>>>

Output exactly one line: PASS or FAIL, then a colon and one sentence saying which mechanism the reply gave."""
async def main(cap):
    sem = asyncio.Semaphore(4); spent = 0.0; out = []
    async def one(n, r):
        nonlocal spent
        q = qs[r["id"]]; rep = r.get("reply") or ""
        row = {"round": n, "id": r["id"], "model": r["model"], "verdict": None, "reason": None, "cost": 0.0}
        if not rep: row["verdict"] = "NOREPLY"; out.append(row); return
        async with sem:
            if spent > cap: row["verdict"] = "SKIPPED"; out.append(row); return
            resp = await litellm.acompletion(model=JUDGE, max_tokens=1200, messages=[{"role": "user", "content": PROMPT.format(instruction=q["instruction"], answer=q["answer"], reply=rep)}])
            txt = (resp.choices[0].message.content or "").strip()
            try: row["cost"] = float(litellm.completion_cost(resp)); spent += row["cost"]
            except Exception: pass
            m = re.search(r"\b(PASS|FAIL)\b", txt); row["verdict"] = m.group(1) if m else "UNPARSED"; row["reason"] = txt[:300]; out.append(row)
    jobs = []
    for n, fn in ((1,"replies-rescreen.jsonl"),(2,"replies-rescreen-r2.jsonl"),(3,"replies-rescreen-r3.jsonl")):
        for r in map(json.loads, open(ROOT/fn)):
            if r["id"] in KEEP: jobs.append(one(n, r))
    await asyncio.gather(*jobs)
    with open(ROOT/"judged-explain.jsonl", "w") as f:
        for row in out: f.write(json.dumps(row) + "\n")
    print(json.dumps({"judged": len(out), "spend": round(spent, 4), "verdicts": dict(collections.Counter(o["verdict"] for o in out))}))
asyncio.run(main(float(sys.argv[1]) if len(sys.argv) > 1 else 2.0))
