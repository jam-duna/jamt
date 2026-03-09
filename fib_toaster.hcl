job "jamduna-fib" {
  datacenters = ["dc1"]
  type        = "batch"
  namespace   = "jamduna"

  group "fib" {
    count = 1

    constraint {
      attribute = "${meta.jamduna}"
      operator  = "="
      value     = "true"
    }

    meta {
      jam_url    = "http://coretime.jamduna.org"
      chain_name = "jamduna"
    }

    task "fib-stream-6" {
      driver = "raw_exec"

      template {
        data = <<EOH
#!/bin/bash
set -euxo pipefail

BASE_DIR="$NOMAD_TASK_DIR"
DATA_DIR="/mnt/nvme_drive_1/$NOMAD_JOB_NAME/$NOMAD_ALLOC_ID"
VALIDATOR="$FIB_VALIDATOR"
RPC_PORT="$FIB_RPC_PORT"

: "$${FIB_STREAM_PORT:=0}"
: "$${FIB_STREAM_INGRESS_ONLY:=false}"
: "$${FIB_STREAM_MODE:=stream}"
: "$${FIB_STREAM_INTERVAL:=1s}"
: "$${FIB_STREAM_MAX_TX:=0}"
: "$${FIB_STREAM_TARGET_N:=0}"
: "$${FIB_STREAM_TXS_PER_BLOCK:=4}"
: "$${FIB_STREAM_RUN_BLOCK_MIN:=1}"
: "$${FIB_STREAM_RUN_BLOCK_MAX:=3}"
: "$${FIB_STREAM_BATCH_SIZE:=8}"
: "$${FIB_STREAM_START_AT:=0}"
: "$${FIB_STREAM_MIN_RANGE_SIZE:=1}"
: "$${FIB_STREAM_MAX_RANGE_SIZE:=8}"
: "$${FIB_STREAM_ADVANCE_TIMEOUT:=2m}"
: "$${FIB_STREAM_POLL_INTERVAL:=500ms}"
: "$${FIB_STREAM_QUEUE_PENDING_HIGH:=1200}"
: "$${FIB_STREAM_RUN_MAX_DELAY_SEC:=5}"
: "$${FIB_STREAM_MAX_PENDING_BLOCKS:=256}"
: "$${FIB_STREAM_PENDING_SOFT_LIMIT:=0}"
: "$${FIB_STREAM_QUEUE_MAX_INFLIGHT:=0}"
: "$${FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT:=0s}"
: "$${FIB_STREAM_QUEUE_TICK_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY:=true}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_START_SEC:=-1}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_END_SEC:=-1}"
: "$${FIB_STREAM_SEED_BASE:=100}"
: "$${FIB_STREAM_PASS_BUDGET:=6m}"
: "$${FIB_STREAM_SYNC_TIMEOUT:=120s}"
: "$${FIB_STREAM_TELEMETRY:=localhost:9999}"
: "$${FIB_STREAM_EXTRA_ARGS:=}"

mkdir -p "$BASE_DIR" "$DATA_DIR/keys" "$DATA_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/rollup-stream-runner" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/rollup-stream-runner"
chmod +x "$BASE_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/spec.json" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/spec.json"

curl -fsSL -o "$BASE_DIR/jamduna-bin" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

LOCK_DIR="$DATA_DIR/.keygen.lock"
cleanup_lock() {
  if [ -n "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup_lock EXIT

until mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 1
done

if [ ! -f "$DATA_DIR/keys/seed_8" ]; then
  echo "Generating keys seed_0..seed_8"
  "$BASE_DIR/jamduna-bin" gen-keys --data-path "$DATA_DIR" --count 9 >/dev/null
fi

rmdir "$LOCK_DIR" 2>/dev/null || true
LOCK_DIR=""

echo "=== Validator Key Info (task $VALIDATOR) ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR" || true

ingress_flag=""
case "$FIB_STREAM_INGRESS_ONLY" in
  true|1|yes) ingress_flag="--fib-ingress-only" ;;
esac

telemetry_flag=""
if [ -n "$FIB_STREAM_TELEMETRY" ]; then
  telemetry_flag="--telemetry $FIB_STREAM_TELEMETRY"
fi

# shellcheck disable=SC2086
exec "$BASE_DIR/rollup-stream-runner" \
  --service fib \
  --chain "$BASE_DIR/spec.json" \
  --data-path "$DATA_DIR" \
  --dev-validator "$VALIDATOR" \
  --port "$FIB_STREAM_PORT" \
  --fib-rpc-port "$RPC_PORT" \
  --mode "$FIB_STREAM_MODE" \
  --interval "$FIB_STREAM_INTERVAL" \
  --max-tx "$FIB_STREAM_MAX_TX" \
  --target-n "$FIB_STREAM_TARGET_N" \
  --txs-per-block "$FIB_STREAM_TXS_PER_BLOCK" \
  --run-block-min "$FIB_STREAM_RUN_BLOCK_MIN" \
  --run-block-max "$FIB_STREAM_RUN_BLOCK_MAX" \
  --batch-size "$FIB_STREAM_BATCH_SIZE" \
  --start-at "$FIB_STREAM_START_AT" \
  --min-range-size "$FIB_STREAM_MIN_RANGE_SIZE" \
  --max-range-size "$FIB_STREAM_MAX_RANGE_SIZE" \
  --advance-timeout "$FIB_STREAM_ADVANCE_TIMEOUT" \
  --poll-interval "$FIB_STREAM_POLL_INTERVAL" \
  --queue-pending-high "$FIB_STREAM_QUEUE_PENDING_HIGH" \
  --run-max-delay-sec "$FIB_STREAM_RUN_MAX_DELAY_SEC" \
  --max-pending-blocks "$FIB_STREAM_MAX_PENDING_BLOCKS" \
  --pending-soft-limit "$FIB_STREAM_PENDING_SOFT_LIMIT" \
  --queue-max-inflight "$FIB_STREAM_QUEUE_MAX_INFLIGHT" \
  --queue-submit-retry-interval "$FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL" \
  --queue-guarantee-timeout "$FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT" \
  --queue-tick-interval "$FIB_STREAM_QUEUE_TICK_INTERVAL" \
  --queue-defer-on-pending-finality="$FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY" \
  --submission-window-start-sec "$FIB_STREAM_SUBMISSION_WINDOW_START_SEC" \
  --submission-window-end-sec "$FIB_STREAM_SUBMISSION_WINDOW_END_SEC" \
  --seed-base "$FIB_STREAM_SEED_BASE" \
  --pass-budget "$FIB_STREAM_PASS_BUDGET" \
  --sync-timeout "$FIB_STREAM_SYNC_TIMEOUT" \
  $ingress_flag \
  $telemetry_flag \
  $FIB_STREAM_EXTRA_ARGS
EOH
        destination = "local/start.sh"
        perms       = "0755"
      }

      config {
        command = "local/start.sh"
      }

      env {
        RUST_BACKTRACE  = "full"
        POLKAVM_BACKEND = "compiler"
        FIB_VALIDATOR   = "6"
        FIB_RPC_PORT    = "8601"
      }

      resources {
        memory = 3072
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    task "fib-stream-7" {
      driver = "raw_exec"

      template {
        data = <<EOH
#!/bin/bash
set -euxo pipefail

BASE_DIR="$NOMAD_TASK_DIR"
DATA_DIR="/mnt/nvme_drive_1/$NOMAD_JOB_NAME/$NOMAD_ALLOC_ID"
VALIDATOR="$FIB_VALIDATOR"
RPC_PORT="$FIB_RPC_PORT"

: "$${FIB_STREAM_PORT:=0}"
: "$${FIB_STREAM_INGRESS_ONLY:=false}"
: "$${FIB_STREAM_MODE:=stream}"
: "$${FIB_STREAM_INTERVAL:=1s}"
: "$${FIB_STREAM_MAX_TX:=0}"
: "$${FIB_STREAM_TARGET_N:=0}"
: "$${FIB_STREAM_TXS_PER_BLOCK:=4}"
: "$${FIB_STREAM_RUN_BLOCK_MIN:=1}"
: "$${FIB_STREAM_RUN_BLOCK_MAX:=3}"
: "$${FIB_STREAM_BATCH_SIZE:=8}"
: "$${FIB_STREAM_START_AT:=0}"
: "$${FIB_STREAM_MIN_RANGE_SIZE:=1}"
: "$${FIB_STREAM_MAX_RANGE_SIZE:=8}"
: "$${FIB_STREAM_ADVANCE_TIMEOUT:=2m}"
: "$${FIB_STREAM_POLL_INTERVAL:=500ms}"
: "$${FIB_STREAM_QUEUE_PENDING_HIGH:=1200}"
: "$${FIB_STREAM_RUN_MAX_DELAY_SEC:=5}"
: "$${FIB_STREAM_MAX_PENDING_BLOCKS:=256}"
: "$${FIB_STREAM_PENDING_SOFT_LIMIT:=0}"
: "$${FIB_STREAM_QUEUE_MAX_INFLIGHT:=0}"
: "$${FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT:=0s}"
: "$${FIB_STREAM_QUEUE_TICK_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY:=true}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_START_SEC:=-1}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_END_SEC:=-1}"
: "$${FIB_STREAM_SEED_BASE:=100}"
: "$${FIB_STREAM_PASS_BUDGET:=6m}"
: "$${FIB_STREAM_SYNC_TIMEOUT:=120s}"
: "$${FIB_STREAM_TELEMETRY:=localhost:9999}"
: "$${FIB_STREAM_EXTRA_ARGS:=}"

mkdir -p "$BASE_DIR" "$DATA_DIR/keys" "$DATA_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/rollup-stream-runner" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/rollup-stream-runner"
chmod +x "$BASE_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/spec.json" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/spec.json"

curl -fsSL -o "$BASE_DIR/jamduna-bin" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

LOCK_DIR="$DATA_DIR/.keygen.lock"
cleanup_lock() {
  if [ -n "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup_lock EXIT

until mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 1
done

if [ ! -f "$DATA_DIR/keys/seed_8" ]; then
  echo "Generating keys seed_0..seed_8"
  "$BASE_DIR/jamduna-bin" gen-keys --data-path "$DATA_DIR" --count 9 >/dev/null
fi

rmdir "$LOCK_DIR" 2>/dev/null || true
LOCK_DIR=""

echo "=== Validator Key Info (task $VALIDATOR) ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR" || true

ingress_flag=""
case "$FIB_STREAM_INGRESS_ONLY" in
  true|1|yes) ingress_flag="--fib-ingress-only" ;;
esac

telemetry_flag=""
if [ -n "$FIB_STREAM_TELEMETRY" ]; then
  telemetry_flag="--telemetry $FIB_STREAM_TELEMETRY"
fi

# shellcheck disable=SC2086
exec "$BASE_DIR/rollup-stream-runner" \
  --service fib \
  --chain "$BASE_DIR/spec.json" \
  --data-path "$DATA_DIR" \
  --dev-validator "$VALIDATOR" \
  --port "$FIB_STREAM_PORT" \
  --fib-rpc-port "$RPC_PORT" \
  --mode "$FIB_STREAM_MODE" \
  --interval "$FIB_STREAM_INTERVAL" \
  --max-tx "$FIB_STREAM_MAX_TX" \
  --target-n "$FIB_STREAM_TARGET_N" \
  --txs-per-block "$FIB_STREAM_TXS_PER_BLOCK" \
  --run-block-min "$FIB_STREAM_RUN_BLOCK_MIN" \
  --run-block-max "$FIB_STREAM_RUN_BLOCK_MAX" \
  --batch-size "$FIB_STREAM_BATCH_SIZE" \
  --start-at "$FIB_STREAM_START_AT" \
  --min-range-size "$FIB_STREAM_MIN_RANGE_SIZE" \
  --max-range-size "$FIB_STREAM_MAX_RANGE_SIZE" \
  --advance-timeout "$FIB_STREAM_ADVANCE_TIMEOUT" \
  --poll-interval "$FIB_STREAM_POLL_INTERVAL" \
  --queue-pending-high "$FIB_STREAM_QUEUE_PENDING_HIGH" \
  --run-max-delay-sec "$FIB_STREAM_RUN_MAX_DELAY_SEC" \
  --max-pending-blocks "$FIB_STREAM_MAX_PENDING_BLOCKS" \
  --pending-soft-limit "$FIB_STREAM_PENDING_SOFT_LIMIT" \
  --queue-max-inflight "$FIB_STREAM_QUEUE_MAX_INFLIGHT" \
  --queue-submit-retry-interval "$FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL" \
  --queue-guarantee-timeout "$FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT" \
  --queue-tick-interval "$FIB_STREAM_QUEUE_TICK_INTERVAL" \
  --queue-defer-on-pending-finality="$FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY" \
  --submission-window-start-sec "$FIB_STREAM_SUBMISSION_WINDOW_START_SEC" \
  --submission-window-end-sec "$FIB_STREAM_SUBMISSION_WINDOW_END_SEC" \
  --seed-base "$FIB_STREAM_SEED_BASE" \
  --pass-budget "$FIB_STREAM_PASS_BUDGET" \
  --sync-timeout "$FIB_STREAM_SYNC_TIMEOUT" \
  $ingress_flag \
  $telemetry_flag \
  $FIB_STREAM_EXTRA_ARGS
EOH
        destination = "local/start.sh"
        perms       = "0755"
      }

      config {
        command = "local/start.sh"
      }

      env {
        RUST_BACKTRACE  = "full"
        POLKAVM_BACKEND = "compiler"
        FIB_VALIDATOR   = "7"
        FIB_RPC_PORT    = "8603"
      }

      resources {
        memory = 3072
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    task "fib-stream-8" {
      driver = "raw_exec"

      template {
        data = <<EOH
#!/bin/bash
set -euxo pipefail

BASE_DIR="$NOMAD_TASK_DIR"
DATA_DIR="/mnt/nvme_drive_1/$NOMAD_JOB_NAME/$NOMAD_ALLOC_ID"
VALIDATOR="$FIB_VALIDATOR"
RPC_PORT="$FIB_RPC_PORT"

: "$${FIB_STREAM_PORT:=0}"
: "$${FIB_STREAM_INGRESS_ONLY:=false}"
: "$${FIB_STREAM_MODE:=stream}"
: "$${FIB_STREAM_INTERVAL:=1s}"
: "$${FIB_STREAM_MAX_TX:=0}"
: "$${FIB_STREAM_TARGET_N:=0}"
: "$${FIB_STREAM_TXS_PER_BLOCK:=4}"
: "$${FIB_STREAM_RUN_BLOCK_MIN:=1}"
: "$${FIB_STREAM_RUN_BLOCK_MAX:=3}"
: "$${FIB_STREAM_BATCH_SIZE:=8}"
: "$${FIB_STREAM_START_AT:=0}"
: "$${FIB_STREAM_MIN_RANGE_SIZE:=1}"
: "$${FIB_STREAM_MAX_RANGE_SIZE:=8}"
: "$${FIB_STREAM_ADVANCE_TIMEOUT:=2m}"
: "$${FIB_STREAM_POLL_INTERVAL:=500ms}"
: "$${FIB_STREAM_QUEUE_PENDING_HIGH:=1200}"
: "$${FIB_STREAM_RUN_MAX_DELAY_SEC:=5}"
: "$${FIB_STREAM_MAX_PENDING_BLOCKS:=256}"
: "$${FIB_STREAM_PENDING_SOFT_LIMIT:=0}"
: "$${FIB_STREAM_QUEUE_MAX_INFLIGHT:=0}"
: "$${FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT:=0s}"
: "$${FIB_STREAM_QUEUE_TICK_INTERVAL:=0s}"
: "$${FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY:=true}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_START_SEC:=-1}"
: "$${FIB_STREAM_SUBMISSION_WINDOW_END_SEC:=-1}"
: "$${FIB_STREAM_SEED_BASE:=100}"
: "$${FIB_STREAM_PASS_BUDGET:=6m}"
: "$${FIB_STREAM_SYNC_TIMEOUT:=120s}"
: "$${FIB_STREAM_TELEMETRY:=localhost:9999}"
: "$${FIB_STREAM_EXTRA_ARGS:=}"

mkdir -p "$BASE_DIR" "$DATA_DIR/keys" "$DATA_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/rollup-stream-runner" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/rollup-stream-runner"
chmod +x "$BASE_DIR/rollup-stream-runner"

curl -fsSL -o "$BASE_DIR/spec.json" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/spec.json"

curl -fsSL -o "$BASE_DIR/jamduna-bin" "$NOMAD_META_jam_url/$NOMAD_META_chain_name/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

LOCK_DIR="$DATA_DIR/.keygen.lock"
cleanup_lock() {
  if [ -n "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup_lock EXIT

until mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 1
done

if [ ! -f "$DATA_DIR/keys/seed_8" ]; then
  echo "Generating keys seed_0..seed_8"
  "$BASE_DIR/jamduna-bin" gen-keys --data-path "$DATA_DIR" --count 9 >/dev/null
fi

rmdir "$LOCK_DIR" 2>/dev/null || true
LOCK_DIR=""

echo "=== Validator Key Info (task $VALIDATOR) ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR" || true

ingress_flag=""
case "$FIB_STREAM_INGRESS_ONLY" in
  true|1|yes) ingress_flag="--fib-ingress-only" ;;
esac

telemetry_flag=""
if [ -n "$FIB_STREAM_TELEMETRY" ]; then
  telemetry_flag="--telemetry $FIB_STREAM_TELEMETRY"
fi

# shellcheck disable=SC2086
exec "$BASE_DIR/rollup-stream-runner" \
  --service fib \
  --chain "$BASE_DIR/spec.json" \
  --data-path "$DATA_DIR" \
  --dev-validator "$VALIDATOR" \
  --port "$FIB_STREAM_PORT" \
  --fib-rpc-port "$RPC_PORT" \
  --mode "$FIB_STREAM_MODE" \
  --interval "$FIB_STREAM_INTERVAL" \
  --max-tx "$FIB_STREAM_MAX_TX" \
  --target-n "$FIB_STREAM_TARGET_N" \
  --txs-per-block "$FIB_STREAM_TXS_PER_BLOCK" \
  --run-block-min "$FIB_STREAM_RUN_BLOCK_MIN" \
  --run-block-max "$FIB_STREAM_RUN_BLOCK_MAX" \
  --batch-size "$FIB_STREAM_BATCH_SIZE" \
  --start-at "$FIB_STREAM_START_AT" \
  --min-range-size "$FIB_STREAM_MIN_RANGE_SIZE" \
  --max-range-size "$FIB_STREAM_MAX_RANGE_SIZE" \
  --advance-timeout "$FIB_STREAM_ADVANCE_TIMEOUT" \
  --poll-interval "$FIB_STREAM_POLL_INTERVAL" \
  --queue-pending-high "$FIB_STREAM_QUEUE_PENDING_HIGH" \
  --run-max-delay-sec "$FIB_STREAM_RUN_MAX_DELAY_SEC" \
  --max-pending-blocks "$FIB_STREAM_MAX_PENDING_BLOCKS" \
  --pending-soft-limit "$FIB_STREAM_PENDING_SOFT_LIMIT" \
  --queue-max-inflight "$FIB_STREAM_QUEUE_MAX_INFLIGHT" \
  --queue-submit-retry-interval "$FIB_STREAM_QUEUE_SUBMIT_RETRY_INTERVAL" \
  --queue-guarantee-timeout "$FIB_STREAM_QUEUE_GUARANTEE_TIMEOUT" \
  --queue-tick-interval "$FIB_STREAM_QUEUE_TICK_INTERVAL" \
  --queue-defer-on-pending-finality="$FIB_STREAM_QUEUE_DEFER_ON_PENDING_FINALITY" \
  --submission-window-start-sec "$FIB_STREAM_SUBMISSION_WINDOW_START_SEC" \
  --submission-window-end-sec "$FIB_STREAM_SUBMISSION_WINDOW_END_SEC" \
  --seed-base "$FIB_STREAM_SEED_BASE" \
  --pass-budget "$FIB_STREAM_PASS_BUDGET" \
  --sync-timeout "$FIB_STREAM_SYNC_TIMEOUT" \
  $ingress_flag \
  $telemetry_flag \
  $FIB_STREAM_EXTRA_ARGS
EOH
        destination = "local/start.sh"
        perms       = "0755"
      }

      config {
        command = "local/start.sh"
      }

      env {
        RUST_BACKTRACE  = "full"
        POLKAVM_BACKEND = "compiler"
        FIB_VALIDATOR   = "8"
        FIB_RPC_PORT    = "8605"
      }

      resources {
        memory = 3072
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }
  }
}
