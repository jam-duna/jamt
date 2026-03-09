job "jamduna-evm" {
  datacenters = ["dc1"]
  type = "batch"
  namespace = "jamduna"

  group "evm" {
    count = 1

    constraint {
       attribute = "${meta.jamduna}"
       operator = "="
       value     = "true"
      }

    meta {
      jam_url = "http://coretime.jamduna.org"
      chain_name = "jamduna"
    }

    task "evm-stream" {
      driver = "raw_exec"

template {
  data = <<EOH
#!/bin/bash
set -x

BASE_DIR="${NOMAD_TASK_DIR}"

# Download evm binaries
curl -fsSL -o "$BASE_DIR/evm-stream-runner" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/evm-stream-runner"
chmod +x "$BASE_DIR/evm-stream-runner"

curl -fsSL -o "$BASE_DIR/evm-builder" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/evm-builder"
chmod +x "$BASE_DIR/evm-builder"

curl -fsSL -o "$BASE_DIR/evm-feeder" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/evm-feeder"
chmod +x "$BASE_DIR/evm-feeder"

# Download spec
curl -fsSL -o "$BASE_DIR/spec.json" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Download jamduna binary for key listing
curl -fsSL -o "$BASE_DIR/jamduna-bin" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

# Use NVMe storage for data files via state/ directory override
DATA_DIR="/mnt/nvme_drive_1/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_ID}"
mkdir -p "$DATA_DIR/keys"

# Create state/ symlink next to binaries so evm-stream-runner uses NVMe path
ln -sfn "$DATA_DIR" "$BASE_DIR/state"

# Download all seeds (0-5 validators + 6 for evm builder)
for i in 0 1 2 3 4 5 6; do
  curl -fsSL -o "$DATA_DIR/keys/seed_$i" \
    "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_$i"
done

# Display key info
echo "=== Validator Key Info ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR"

export EVM_RUNNER_BUILDER_BIN="$BASE_DIR/evm-builder"
export EVM_RUNNER_FEEDER_BIN="$BASE_DIR/evm-feeder"

# Kill any leftover evm-stream-runner processes
pkill -f "evm-stream-runner" || true
sleep 2

"$BASE_DIR/evm-stream-runner" \
  -chain "$BASE_DIR/spec.json"

sleep 6000
EOH
  destination = "local/start.sh"
  perms       = "0755"
}

      config {
        command = "local/start.sh"
      }

      env {
        RUST_BACKTRACE = "full"
        POLKAVM_BACKEND = "compiler"
      }
       resources {
         memory = 4096
        }

  logs {
    max_files     = 5
    max_file_size = 10
  }
    }
  }
}
