#!/bin/sh
# usage: new-project.sh <slug>
set -eu
d=/tmp/subagents/security-quizzes/pilot/multi-opus-$1
mkdir -p "$d/src" "$d/test"
cat > "$d/foundry.toml" <<'T'
[profile.default]
src = "src"
test = "test"
solc = "0.8.28"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
allow_paths = [".."]
remappings = ["@openzeppelin/contracts/=../deps/oz5/", "proof/=../_multi-opus/"]
[fuzz]
runs = 256
T
echo "$d"
