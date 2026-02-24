job "jam-fib" {
  datacenters = ["dc1"]
  type        = "service"

  group "fib" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      value     = "coretime.us-central1-c.c.jamduna.internal"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "fib-stream" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args = [
          "-c",
          <<EOF
set -e
export HOME=/root
echo "Running only on coretime"

BASE_DIR="$${NOMAD_TASK_DIR}"
mkdir -p "$BASE_DIR/local"
mkdir -p /root/.jamduna/keys

echo "Cleaning previous fib builder DB: /root/.jamduna/jam-6/leveldb"
rm -rf /root/.jamduna/jam-6/leveldb

curl -fsSL -o "$BASE_DIR/local/fib-stream-runner" http://coretime.jamduna.org/jamduna/fib-stream-runner
chmod +x "$BASE_DIR/local/fib-stream-runner"

curl -fsSL -o "$BASE_DIR/local/fib-builder" http://coretime.jamduna.org/jamduna/fib-builder
chmod +x "$BASE_DIR/local/fib-builder"

curl -fsSL -o "$BASE_DIR/local/fib-feeder" http://coretime.jamduna.org/jamduna/fib-feeder
chmod +x "$BASE_DIR/local/fib-feeder"

curl -fsSL -o "$BASE_DIR/local/spec.json" http://coretime.jamduna.org/jamduna/spec.json

# Download all seeds (safe)
for i in 1 2 3 4 5 6; do
  curl -fsSL -o /root/.jamduna/keys/seed_$i \
    http://coretime.jamduna.org/jamduna/keys/seed_$i
done

export FIB_RUNNER_BUILDER_BIN="$BASE_DIR/local/fib-builder"
export FIB_RUNNER_FEEDER_BIN="$BASE_DIR/local/fib-feeder"

exec "$BASE_DIR/local/fib-stream-runner" \
  -chain "$BASE_DIR/local/spec.json"
EOF
        ]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
