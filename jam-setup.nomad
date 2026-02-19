job "jam-setup" {
  datacenters = ["dc1"]
  type        = "batch"

  group "setup" {

    restart {
      attempts = 0
      mode     = "fail"
    }

    task "init" {
      driver = "raw_exec"

      config {
        command = "bash"
        args = [
          "-c",
          "cd /root/go/src/github.com/colorfulnotion/jamt/release && make clean-state && make gen-keys && make gen-spec"
        ]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}

