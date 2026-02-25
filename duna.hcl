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

curl -fsSL -o spec.json "${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/spec.json"

# Ensure jamduna is executable
if [ -f local/jamduna-bin ]; then
  chmod +x local/jamduna-bin
fi

# Extract last octet from machine's IP
#INDEX=$(ip -4 addr show | awk '/inet 192\.168\.20/ {print $2}' | cut -d/ -f1 | awk -F. '{print $4}')
#export IP=$(ip -4 addr show | awk '/inet 192\.168\.20/ {print $2}' | cut -d/ -f1)
#
#if [ -z "$IP" ]; then
#  echo "Error: Could not determine IP address" >&2
#  exit 1
#fi
# Get short hostname (without domain)
HOST=$(hostname -s)

# Extract numeric suffix (everything after last dash)
INDEX=$(echo "$HOST" | awk -F- '{print $NF}')

if ! [[ "$INDEX" =~ ^[0-9]+$ ]]; then
  echo "Error: Could not extract numeric index from hostname $HOST" >&2
  exit 1
fi

export INDEX
echo "Detected HOST: $HOST"
echo "Computed INDEX from hostname: $INDEX"

echo "Computed INDEX: $INDEX"
echo "Computed GROUP INDEX: $NOMAD_META_nomad_group"
echo "Using disk $DISK_INDEX"

# Fetch key using computed index
SEED_URL="${NOMAD_META_jam_url}/${NOMAD_META_chain_name}/keys/seed_${INDEX}"
echo "Seed URL: $SEED_URL"

mkdir -p keys
curl -fsSL -o keys/seed_${INDEX} "$SEED_URL"

export JAM_PATH="/root/go/src/github.com/colorfulnotion/jam"

# Run the process
exec ./local/jamduna-bin \
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
         memory = 5000
        }

  logs {
    max_files     = 5
    max_file_size = 10
  }
    }
  }
}
