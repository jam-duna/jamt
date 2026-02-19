job "jam-validators" {
  datacenters = ["dc1"]
  type        = "service"

  group "validators" {
    count = 5

    network {
      port "p2p" {}
      port "rpc" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "validator" {
      driver = "raw_exec"

      config {
        command = "/root/go/src/github.com/colorfulnotion/jamt/release/jamduna"

        args = [
          "run",
          "--dev-validator", "${NOMAD_ALLOC_INDEX}",
          "--chain", "/root/go/src/github.com/colorfulnotion/jamt/release/chainspecs/jamduna-spec.json",
          "--data-path", "/root/go/src/github.com/colorfulnotion/jamt/release/state/validator_${NOMAD_ALLOC_INDEX}",
          "--port", "${NOMAD_PORT_p2p}",
          "--rpc-port", "${NOMAD_PORT_rpc}",
          "--role", "validator"
        ]
      }

      resources {
        cpu    = 2000
        memory = 4096
      }
    }
  }
}

