#!/bin/bash
utils=/opt/supervisor-scripts/utils
. "${utils}/logging.sh"
. "${utils}/environment.sh"                 # loads /etc/environment + ${WORKSPACE}/.env
. "${utils}/exit_portal.sh" "Qwen LLM"      # self-skips if "Qwen LLM" not in /etc/portal.yaml

source /venv/main/bin/activate

# Serve Qwen3-8B on an internal-only port; Caddy exposes it externally with auth.
pty vllm serve Qwen/Qwen3-8B \
    --host 127.0.0.1 \
    --port 18000 \
    --served-model-name qwen3-8b \
    --max-model-len 16384 \
    --gpu-memory-utilization 0.90 \
    2>&1
