job "jamduna" {
  datacenters = ["dc1"]
  type = "batch"
  namespace = "jamduna"

//  parameterized {
//    meta_required = ["chain_name", "nomad_group"]
//    meta_optional = [ "node_count", "node_clean", "node_update", "jam_log", "jam_url", "jam_start_ip", "jam_ip_count", "role"]
//  }

  group "jamduna" {

    constraint {
       attribute = "${meta.jamduna}"
       operator = "="
       value     = "true"
      }
    constraint {
       distinct_hosts = true
     }

    meta {
      jam_url = "http://coretime.jamduna.org"
      jam_id = "jamduna"
      jam_log = "info"
      node_update = true
      node_clean = true
      node_disk_count = 1
      chain_name = "jamduna"
      nomad_group = 1
    }

    count = 6

    task "jamduna-task" {
      driver = "raw_exec"


template {
  data = <<EOH
#!/bin/bash
set -x

# Validate required environment variables
if [ -z "$${NOMAD_META_nomad_group:-}" ] || [ -z "$${NOMAD_META_node_disk_count:-}" ]; then
  echo "Error: Required metadata variables not set" >&2
  exit 1
fi

DISK_INDEX=$(( ($NOMAD_META_nomad_group - 1) % $NOMAD_META_node_disk_count + 1))
DISK_PATH="/mnt/nvme_drive_${DISK_INDEX}"


if [ "$${NOMAD_META_node_update:-false}" = "true" ]; then
  curl -fsSL -o local/jamduna-bin "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/jamduna"
  chmod +x local/jamduna-bin
fi

if [ "$${NOMAD_META_node_clean:-false}" = "true" ]; then
  echo "NOT Cleaning location ${DISK_PATH}/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_NAME}"
  #rm -rf "${DISK_PATH}/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_NAME}"
fi

mkdir -p local/${NOMAD_META_chain_name}/keys
curl -fsSL -o spec.json "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Ensure jamduna is executable
if [ -f local/jamduna-bin ]; then
  chmod +x local/jamduna-bin
fi

# Get short hostname (without domain)
HOST=$(hostname -s)

# Extract numeric suffix (everything after last dash), subtract 2 for validator index
INDEX=$(echo "$HOST" | awk -F- '{print $NF - 2}')

if ! [[ "$INDEX" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not extract numeric index from hostname $HOST" >&2
  exit 1
fi

export INDEX
echo "Detected HOST: $HOST"
echo "Computed INDEX from hostname: $INDEX"
echo "Computed GROUP INDEX: $NOMAD_META_nomad_group"
echo "Using disk $DISK_INDEX"

# Use NVMe storage for data files
DATA_DIR="${DISK_PATH}/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_NAME}"
mkdir -p "$DATA_DIR/keys"
echo "Data directory: $DATA_DIR"

# Fetch key using computed index
SEED_URL="${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_${INDEX}"
echo "Seed URL: $SEED_URL"

curl -fsSL -o "$DATA_DIR/keys/seed_${INDEX}" "$SEED_URL"

# Display key info
echo "=== Validator Key Info ==="
./local/jamduna-bin list-keys -d "$DATA_DIR"

# Kill any leftover jamduna processes holding the port
pkill -f "jamduna.*--dev-validator $INDEX" || true
sleep 2

# Run the process
./local/jamduna-bin \
  --chain=spec.json \
  -c local \
  -d "$DATA_DIR" \
  run \
  --pvm-backend compiler \
  --dev-validator "$INDEX"

sleep 6000
EOH
  destination = "local/start.sh"
  perms       = "0755"
}

      config {
        command = "local/start.sh"
        oom_score_adj = 0
      }

      env {
        RUST_BACKTRACE = "full"
        POLKAVM_BACKEND = "compiler"
      }
       resources {
         memory = 2000
        }

  logs {
    max_files     = 5
    max_file_size = 10
  }
    }
  }
}
