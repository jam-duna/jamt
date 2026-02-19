job "jamduna" {
  datacenters = ["dc1"]
  type = "batch"

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
      jam_url = "http://192.168.20.0/chains"
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
  curl -fsSL -o local/jamduna "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/jamduna"
  chmod +x local/jamduna
fi

if [ "$${NOMAD_META_node_clean:-false}" = "true" ]; then
  echo "NOT Cleaning location ${DISK_PATH}/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_NAME}"
  #rm -rf "${DISK_PATH}/${NOMAD_JOB_NAME}/${NOMAD_ALLOC_NAME}"
fi

mkdir -p local/${NOMAD_META_chain_name}/keys
curl -fsSL -o spec.json "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Ensure jamduna is executable
if [ -f local/jamduna ]; then
  chmod +x local/jamduna
fi

# Extract last octet from machine's IP
INDEX=$(ip -4 addr show | awk '/inet 192\.168\.20/ {print $2}' | cut -d/ -f1 | awk -F. '{print $4}')
export IP=$(ip -4 addr show | awk '/inet 192\.168\.20/ {print $2}' | cut -d/ -f1)

if [ -z "$IP" ]; then
  echo "Error: Could not determine IP address" >&2
  exit 1
fi


echo "Computed PEER_HOST: $PEER_HOST"
echo "Computed PORT: $PORT"
echo "Computed INDEX: $INDEX"
echo "Computed GROUP INDEX: $NOMAD_META_nomad_group"
echo "Using disk $DISK_INDEX"

VALIDATOR_SEED=$(grep "$IP:" local/validator-list | awk NR==$NOMAD_META_nomad_group | cut -d, -f1)
echo "Computed VALIDATOR_SEED: $VALIDATOR_SEED"

# Fetch key using computed index
SEED_URL="${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_${INDEX}"

echo "Seed URL: $SEED_URL"
echo "Peer ID: $PEER_ID"

mkdir -p keys
curl -fsSL -o keys/seed_${INDEX} "$SEED_URL"

# Run the process
exec ./local/jamduna \
  --chain=spec.json \
  -c local \
  -d . \
  run \
  --dev-validator "$INDEX" 
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
         memory = 16000
        }

  logs {
    max_files     = 5
    max_file_size = 10
  }
    }
  }
}
