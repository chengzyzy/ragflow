#!/usr/bin/env bash
set -euo pipefail

MODEL_SOURCE="${MINERU_MODEL_SOURCE:-huggingface}"
PORT="${MINERU_PORT:-8886}"

# Models (~1-2 GB) and the config file live in the mounted /data volume, so the
# download happens once and survives container recreation.
if [ ! -s "${MINERU_TOOLS_CONFIG_JSON}" ]; then
    echo "[mineru] no config found at ${MINERU_TOOLS_CONFIG_JSON}"
    echo "[mineru] downloading pipeline models from ${MODEL_SOURCE} (first run only) ..."
    mineru-models-download -s "${MODEL_SOURCE}" -m pipeline
else
    echo "[mineru] reusing models described by ${MINERU_TOOLS_CONFIG_JSON}"
fi

echo "[mineru] starting mineru-api on 0.0.0.0:${PORT}"
exec mineru-api --host 0.0.0.0 --port "${PORT}"
