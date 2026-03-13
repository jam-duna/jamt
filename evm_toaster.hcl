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

    task "evm-runnercore" {
      driver = "raw_exec"

template {
  data = <<EOH
#!/bin/bash
set -x

BASE_DIR="${NOMAD_TASK_DIR}"

# Download evm runnercore binary
curl -fsSL -o "$BASE_DIR/evm-runnercore" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/evm-runnercore"
chmod +x "$BASE_DIR/evm-runnercore"

# Download spec
curl -fsSL -o "$BASE_DIR/spec.json" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Download jamduna binary for key listing
curl -fsSL -o "$BASE_DIR/jamduna-bin" "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/jamduna"
chmod +x "$BASE_DIR/jamduna-bin"

# Use NVMe storage for data files
DATA_DIR="/mnt/nvme_drive_1/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_ID}"
mkdir -p "$DATA_DIR/keys"

# Download all seeds (0-5 validators + 6 for evm builder)
for i in 0 1 2 3 4 5 6; do
  curl -fsSL -o "$DATA_DIR/keys/seed_$i" \
    "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_$i"
done

# Display key info
echo "=== Validator Key Info ==="
"$BASE_DIR/jamduna-bin" list-keys -d "$DATA_DIR"

# Kill any leftover runnercore/legacy processes
pkill -f "evm-runnercore" || true
pkill -f "evm-stream-runner" || true
sleep 2

"$BASE_DIR/evm-runnercore" \
  --chain "$BASE_DIR/spec.json" \
  --data-path "$DATA_DIR" \
  --dev-validator 6 \
  --pvm-backend compiler \
  --target-n 255 \
  --epoch-mode=true \
  --evm-rpc-port 8600 \
  --viewer-port 8602

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
