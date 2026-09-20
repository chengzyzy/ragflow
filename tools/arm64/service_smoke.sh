#!/usr/bin/env bash
# Run only on a GitHub ARM64 runner, against the image just built by this job.
set -euo pipefail

[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ARCH:-} == ARM64 ]] || {
    echo 'Service smoke checks require a GitHub ARM64 runner.' >&2; exit 1;
}
component=${1:?Usage: service_smoke.sh ragflow|mineru IMAGE}
case "$component" in ragflow|mineru) ;; *) exit 1 ;; esac
export IMAGE=${2:?Missing image}
export SMOKE_DIR
SMOKE_DIR=$(mktemp -d "${RUNNER_TEMP:?}/arm64-smoke.XXXXXX")
export SMOKE_PASSWORD
SMOKE_PASSWORD=$(openssl rand -hex 24)
printf '::add-mask::%s\n' "$SMOKE_PASSWORD"
printf 'user_default_llm: {}\n' > "$SMOKE_DIR/local.service_conf.yaml"
log_dir="$RUNNER_TEMP/arm64-service-smoke"
mkdir -p "$log_dir"
compose=(docker compose --env-file /dev/null
    --project-name "arm64-ci-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}-$component"
    --file "$(dirname "${BASH_SOURCE[0]}")/compose.smoke.yml")

cleanup() {
    local result=$?
    trap - EXIT
    set +e
    "${compose[@]}" ps --all > "$log_dir/containers.txt" 2>&1
    "${compose[@]}" logs --no-color --timestamps 2>&1 |
        sed "s/$SMOKE_PASSWORD/[REDACTED]/g" > "$log_dir/services.log"
    "${compose[@]}" ps --all --quiet |
        xargs -r docker inspect --format '{{json .State}}' |
        sed "s/$SMOKE_PASSWORD/[REDACTED]/g" > "$log_dir/container-states.jsonl"
    "${compose[@]}" down --volumes --remove-orphans --timeout 20 || result=1
    rm -rf "$SMOKE_DIR"
    exit "$result"
}
trap cleanup EXIT

if [[ $component == ragflow ]]; then
    sudo sysctl -w vm.max_map_count=262144
fi
"${compose[@]}" up --detach --no-build --wait --wait-timeout 900 "$component"

if [[ $component == ragflow ]]; then
    # healthz covers database/search/storage/Redis, but not the worker or admin.
    "${compose[@]}" exec -T ragflow python3 - <<'PY'
import json
import os
import time
import urllib.request

import valkey

conn = valkey.StrictRedis(host="redis", password=os.environ["REDIS_PASSWORD"], db=1,
                         socket_timeout=5, socket_connect_timeout=5)
deadline = time.monotonic() + 180
first_heartbeats = {}
last_error = "No advancing worker heartbeat"
while time.monotonic() < deadline:
    try:
        with urllib.request.urlopen("http://127.0.0.1/api/v1/system/healthz", timeout=10) as response:
            health = json.load(response)
        assert all(health.get(key) == "ok" for key in ("status", "db", "redis", "doc_engine", "storage")), health
        with urllib.request.urlopen("http://127.0.0.1/api/v1/admin/ping", timeout=10) as response:
            assert json.load(response)["message"] == "pong"
        with urllib.request.urlopen("http://127.0.0.1/", timeout=10) as response:
            assert b"<html" in response.read().lower(), "Missing Web frontend"
        for worker in conn.smembers("TASKEXE"):
            latest = conn.zrevrange(worker, 0, 0, withscores=True)
            if not latest:
                continue
            score = latest[0][1]
            heartbeat = json.loads(latest[0][0])
            instance = (worker, heartbeat["pid"], heartbeat["boot_at"])
            first = first_heartbeats.setdefault(instance, score)
            if score > first and time.time() - 60 <= score <= time.time() + 5:
                print("API, admin, Web frontend, dependencies and advancing worker heartbeat passed.")
                raise SystemExit(0)
    except Exception as exc:
        last_error = str(exc)
    time.sleep(5)
raise SystemExit(f"Service smoke failed: {last_error}")
PY
else
    "${compose[@]}" exec -T mineru python3 -c \
        'import json, urllib.request; schema = json.load(urllib.request.urlopen("http://127.0.0.1:8886/openapi.json", timeout=10)); assert "/file_parse" in schema["paths"]'
fi
printf '%s normal entrypoint and service health checks passed.\n' "$component"
