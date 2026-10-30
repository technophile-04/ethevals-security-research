"""Tally strict (all issues, no false claim) and big-ones (all Highs, no false claim) verdicts per question and model."""
import json, collections, sys, glob, pathlib
qfiles = sys.argv[1].split(","); jpatterns = sys.argv[2].split(",")
qs = {}
for f in qfiles: qs.update({q["id"]: q for q in json.load(open(f))})
rows = []
for p in jpatterns:
    for f in sorted(glob.glob(p)): rows += [json.loads(l) for l in open(f)]
res = collections.defaultdict(lambda: collections.defaultdict(lambda: {"n":0,"strict_fail":0,"big_fail":0,"false":0,"noreply":0,"missed":collections.Counter()}))
for r in rows:
    m = 'opus' if 'opus' in r['model'] else 'gpt' if 'gpt' in r['model'] else 'kimi' if 'kimi' in r['model'] else 'glm'
    q = qs[r["id"]]; t = res[r["id"]][m]
    if not isinstance(r["named"], list): t["noreply"] += 1; continue
    t["n"] += 1; named = set(r["named"]); allset = {i["n"] for i in q["issues"]}; highs = {i["n"] for i in q["issues"] if i["severity"] == "High"}
    false = bool(r.get("false")); t["false"] += false
    if not named >= allset: t["strict_fail"] += 1
    if not named >= highs: t["big_fail"] += 1
    for i in allset - named: t["missed"][i] += 1
print(f"{'question':36s} {'opus':12s} {'gpt':12s} {'kimi':12s} {'glm':12s}   (missed some / missed a High / graded)")
for i, ms in res.items():
    cells=[]
    for m in ("opus","gpt","kimi","glm"):
        c=f"{ms[m]['strict_fail']}/{ms[m]['big_fail']}/{ms[m]['n']}" + (f" n{ms[m]['noreply']}" if ms[m]['noreply'] else "")
        cells.append(c.ljust(12))
    print(f"{i:36s} " + " ".join(cells))
print("\nfalse-claim rate per model (replies with an extra claimed vulnerability / graded):")
for m in ("opus","gpt","kimi","glm"):
    f=sum(ms[m]["false"] for ms in res.values()); n=sum(ms[m]["n"] for ms in res.values()); print(f"  {m}: {f}/{n}")
print("\nmissed issues (issue(severity): times, all models) and false claims:")
for i, ms in res.items():
    missed = collections.Counter(); fc = 0
    for m in ms: missed.update(ms[m]["missed"]); fc += ms[m]["false"]
    sev = {x["n"]: x["severity"][0] for x in qs[i]["issues"]}
    print(f"  {i:36s} missed={{{', '.join(f'{k}({sev[k]}):{v}' for k, v in sorted(missed.items()))}}} false_claims={fc}")
