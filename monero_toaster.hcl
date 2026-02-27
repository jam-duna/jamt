job "jamduna-monero" {
  datacenters = ["dc1"]
  type        = "batch"
  namespace   = "jamduna"

  group "monero" {
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

    task "monero-stream" {
      driver = "raw_exec"

      template {
        data = <<EOH
#!/bin/bash
set -euxo pipefail

BASE_DIR="${NOMAD_TASK_DIR}"
DATA_DIR="/mnt/nvme_drive_1/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_ID}"

mkdir -p "$BASE_DIR" "$DATA_DIR/keys" "$DATA_DIR/monero-stream-runner"

# Download monero stream runner
curl -fsSL -o "$BASE_DIR/monero-stream-runner" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/monero-stream-runner"
chmod +x "$BASE_DIR/monero-stream-runner"

# Download spec
curl -fsSL -o "$BASE_DIR/spec.json" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Download jamduna binary for key listing
curl -fsSL -o "$BASE_DIR/jamduna-bin" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

# Download all seeds (0-5 validators + 6 for monero stream runner)
for i in 0 1 2 3 4 5 6; do
  curl -fsSL -o "$DATA_DIR/keys/seed_$i" \
    "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_$i"
done

# Display key info
echo "=== Validator Key Info ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR" || true

# Show spec peers for troubleshooting
echo "=== Spec Bootnodes ==="
jq -r '.bootnodes[]' "$BASE_DIR/spec.json" || true

# Kill any leftover monero-stream-runner processes
pkill -f "monero-stream-runner" || true
sleep 2

# Clean stale local state to avoid anchor/continuity mismatch
rm -rf "$DATA_DIR/jam-6" "$DATA_DIR/monero-stream-runner"

exec "$BASE_DIR/monero-stream-runner" \
  --chain "$BASE_DIR/spec.json" \
  --data-path "$DATA_DIR" \
  --state "$DATA_DIR/monero-stream-runner/wallet-state.json" \
  --dev-validator 6 \
  --sync-timeout 300s
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
      }

      resources {
        memory = 2048
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }
  }
}