job "jam-fib" {
  datacenters = ["dc1"]
  type        = "service"

  group "fib" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    task "fib-stream" {
      driver = "raw_exec"

      env {
        HOME = "/root"
      }

      config {
        command = "/opt/jamtestnet/release/fib-stream-runner"

        args = [
          "-chain", "/opt/jamtestnet/release/chainspecs/jamduna-spec.json"
        ]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}

