"""Ask each instruction once per bare model, with at most one transport retry.

Run from the project's runner directory with uv run --env-file ../.env.
Only final replies, usage counts, and costs are saved. No trajectories are saved.
"""
import argparse
import asyncio
from collections import Counter
from decimal import Decimal
import json
import logging
import os
from pathlib import Path
import urllib.request

import litellm

ROOT = Path(__file__).resolve().parent
MODELS = ["openrouter/z-ai/glm-5.3"]  # 
            # removed
litellm.suppress_debug_info = True
litellm.set_verbose = False
for name in ("LiteLLM", "LiteLLM Router", "LiteLLM Proxy", "httpx", "openai", "anthropic"):
    logging.getLogger(name).setLevel(logging.CRITICAL)


def clean_error(error):
    text = f"{type(error).__name__}: {error}"
    for name, value in os.environ.items():
        if len(value) >= 8 and any(word in name.upper() for word in ("KEY", "TOKEN", "SECRET", "PASSWORD")):
            text = text.replace(value, "[REDACTED]")
    return text[:1500]


def prices():
    with urllib.request.urlopen("https://openrouter.ai/api/v1/models", timeout=30) as response:
        router = {model["id"]: model for model in json.load(response)["data"]}
    result = {}
    for model in MODELS:
        if model.startswith("openrouter/"):
            pricing = router[model.split("/", 1)[1]]["pricing"]
            result[model] = (Decimal(pricing["prompt"]), Decimal(pricing["completion"]))
        else:
            pricing = litellm.model_cost.get(model) or litellm.model_cost[model.split("/", 1)[1]]
            result[model] = (Decimal(str(pricing["input_cost_per_token"])),
                             Decimal(str(pricing["output_cost_per_token"])))
    return result


class Budget:
    def __init__(self, cap, rates):
        self.cap = Decimal(str(cap))
        self.rates = rates
        self.spent = Decimal(0)
        self.unknown = Decimal(0)
        self.reserved = Decimal(0)
        self.condition = asyncio.Condition()

    async def reserve(self, instruction, model, max_tokens):
        input_rate, output_rate = self.rates[model]
        # UTF-8 bytes bound token count; the allowance covers provider message framing.
        input_cost = (len(instruction.encode()) + 256) * input_rate
        async with self.condition:
            while True:
                available = self.cap - self.spent - self.unknown - self.reserved
                desired = (input_cost + max_tokens * output_rate) * Decimal("1.05")
                if desired <= available:
                    self.reserved += desired
                    return desired, max_tokens
                if self.reserved:
                    await self.condition.wait()
                    continue
                tokens = min(max_tokens, int((available / Decimal("1.05") - input_cost) / output_rate))
                if tokens < 1024:
                    return None
                reserve = (input_cost + tokens * output_rate) * Decimal("1.05")
                self.reserved += reserve
                return reserve, tokens

    async def settle(self, reserved, cost, uncertain=False):
        async with self.condition:
            self.reserved -= reserved
            if uncertain:
                self.unknown += reserved
            else:
                self.spent += Decimal(str(cost))
            self.condition.notify_all()


def response_cost(response, model, rates):
    usage = response.usage
    cost = getattr(usage, "cost", None)
    if cost is None:
        cost = response._hidden_params.get("response_cost")
    if cost is not None:
        return float(cost), "provider_or_litellm"
    try:
        return float(litellm.completion_cost(completion_response=response)), "litellm"
    except Exception:
        input_rate, output_rate = rates[model]
        return float(usage.prompt_tokens * input_rate + usage.completion_tokens * output_rate), "usage_times_price"


async def main(args):
    questions = json.loads((ROOT / "questions-glm-retry.json").read_text())
    output = ROOT / "replies-glm-retry.jsonl"
    if output.exists():
        raise FileExistsError("replies-glm-retry.jsonl exists; refuse to repeat model calls")
    rates = prices()
    (ROOT / "pricing.json").write_text(json.dumps({model: {"input_per_token": str(rate[0]),
        "output_per_token": str(rate[1])} for model, rate in rates.items()}, indent=2) + "\n")
    budget = Budget(args.cap, rates)
    sem = asyncio.Semaphore(args.concurrency)
    rows = []

    async def ask(question, model):
        row = {"id": question["id"], "model": model, "reply": "", "cost": 0.0,
               "error": None, "attempts": 0}
        unknown = Decimal(0)
        async with sem:
            for attempt in (1, 2):
                reservation = await budget.reserve(question["instruction"], model, args.max_tokens)
                if reservation is None:
                    row["error"] = "BudgetCap: no call admitted within the $3 cap"
                    break
                reserved, max_tokens = reservation
                row["attempts"] = attempt
                try:
                    response = await litellm.acompletion(
                        model=model,
                        messages=[{"role": "user", "content": question["instruction"]}],
                        reasoning_effort="high", max_tokens=max_tokens,
                        num_retries=0, max_retries=0, timeout=180,
                    )
                except Exception as error:
                    transport = isinstance(error, (litellm.APIConnectionError, litellm.Timeout))
                    await budget.settle(reserved, 0, uncertain=transport)
                    if transport:
                        unknown += reserved
                    row["error"] = clean_error(error)
                    if transport and attempt == 1:
                        continue
                    break
                cost, source = response_cost(response, model, rates)
                await budget.settle(reserved, cost)
                row["cost"] = cost
                row["cost_source"] = source
                row["input_tokens"] = response.usage.prompt_tokens
                row["output_tokens"] = response.usage.completion_tokens
                row["max_tokens"] = max_tokens
                row["finish_reason"] = response.choices[0].finish_reason
                # Access only the final text. Never inspect reasoning fields.
                row["reply"] = response.choices[0].message.content or ""
                row["error"] = None
                if not row["reply"]:
                    row["error"] = f"EmptyReply: finish_reason={row['finish_reason']}"
                elif row["finish_reason"] in ("length", "content_filter"):
                    row["error"] = f"IncompleteReply: finish_reason={row['finish_reason']}"
                break
        if unknown:
            row["unknown_cost_reserve"] = float(unknown)
            if not row["cost"]:
                row["cost"] = None
        with output.open("a") as handle:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
        rows.append(row)
        if len(rows) % 8 == 0 or row["error"]:
            print(json.dumps({"completed": len(rows), "id": row["id"], "model": model,
                              "error_type": row["error"].split(":", 1)[0] if row["error"] else None,
                              "cost": round(float(budget.spent), 6),
                              "unknown_cost_reserve": float(budget.unknown)}), flush=True)

    print(f"Questions: {len(questions)}; calls: {len(questions) * len(MODELS)}; cap: ${args.cap:.2f}", flush=True)
    await asyncio.gather(*(ask(question, model) for question in questions for model in MODELS))
    summary = {"questions": len(questions), "rows": len(rows),
               "replies_per_model": dict(Counter(row["model"] for row in rows if row["reply"])),
               "errors_per_model": {model: sum(bool(row["error"]) for row in rows if row["model"] == model)
                                    for model in MODELS},
               "total_cost": float(budget.spent), "unknown_cost_reserve": float(budget.unknown),
               "cap": args.cap, "output": str(output)}
    (ROOT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cap", type=float, default=3.0)
    parser.add_argument("--concurrency", type=int, default=8)
    parser.add_argument("--max-tokens", type=int, default=8192)
    args = parser.parse_args()
    if not 0 < args.cap <= 3:
        parser.error("cap must be greater than zero and at most $3")
    asyncio.run(main(args))
