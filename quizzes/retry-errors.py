"""Re-ask only the errored rows of a replies file with a larger output budget; writes <file>-retry.jsonl."""
import asyncio, json, sys, pathlib
import litellm
ROOT = pathlib.Path(__file__).resolve().parent
async def main(replies_path, questions_path, max_tokens):
    qs = {q["id"]: q for q in json.loads(pathlib.Path(questions_path).read_text())}
    rows = [json.loads(l) for l in open(replies_path)]
    todo = [r for r in rows if r.get("error") or not r.get("reply")]
    sem = asyncio.Semaphore(3); out = []
    async def one(r):
        async with sem:
            row = {"id": r["id"], "model": r["model"], "reply": "", "error": None, "cost": 0.0}
            try:
                resp = await litellm.acompletion(model=r["model"], messages=[{"role": "user", "content": qs[r["id"]]["instruction"]}],
                    reasoning_effort="high", max_tokens=max_tokens, num_retries=2, timeout=600)
                row["reply"] = resp.choices[0].message.content or ""
                row["finish_reason"] = resp.choices[0].finish_reason
                if not row["reply"]: row["error"] = f"EmptyReply: finish_reason={row['finish_reason']}"
                try: row["cost"] = float(litellm.completion_cost(resp))
                except Exception: pass
            except Exception as e:
                row["error"] = f"{type(e).__name__}: {str(e)[:200]}"
            out.append(row)
    await asyncio.gather(*(one(r) for r in todo))
    outp = pathlib.Path(str(replies_path).replace(".jsonl", "-retry.jsonl"))
    with open(outp, "w") as f:
        for row in out: f.write(json.dumps(row) + "\n")
    print(json.dumps({"file": str(outp), "retried": len(todo), "ok": sum(1 for o in out if o["reply"]), "cost": round(sum(o["cost"] for o in out), 4)}))
asyncio.run(main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 32000))
