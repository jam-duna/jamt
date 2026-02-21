# JAM DUNA Nomad Deployment

This document explains the `jamduna` Nomad job configuration used to deploy and bootstrap a JAM validator cluster in duna.hcl


## Overview

This Nomad job deploys multiple JAM validator nodes across a cluster in a deterministic, disk-aware way.

The job:

* Schedules **6 JAM validator processes**
* Ensures each runs on a separate physical host
* Auto-downloads binaries and chain specifications
* Binds node identity to host IP and disk
* Deterministically assigns validator keys

```
Nomad
  ↓
Deterministic Validator Scheduler
  ↓
IP → Identity Mapping
  ↓
Auto Key Distribution
  ↓
JAM Network Bootstrap
```

Nomad acts as the chain bootstrap and validator orchestrator.

Features:

* Stateless deployment
* Host anti-affinity
* Binary auto-upgrade
* Zero-touch chain bring-up

## Job Definition

```hcl
job "jamduna" {
  datacenters = ["dc1"]
  type = "batch"
}
```

* Job name: `jamduna`
* Runs in datacenter `dc1`
* Uses `batch` mode for bootstrap-style execution

Typical flow:

```
spin up validators → chain starts → job completes
```

---

## Parameterization (Optional)

A parameterized block can allow runtime metadata injection using `nomad job dispatch`.

Currently, metadata values are hardcoded.

---

## Task Group

```hcl
group "jamduna"
```

A group represents co-scheduled allocations. All tasks inside the group are scheduled together.

---

## Host Constraints

### Node Label Constraint

```hcl
constraint {
  attribute = "${meta.jamduna}"
  operator  = "="
  value     = "true"
}
```

Only Nomad clients labeled with:

```
meta.jamduna = true
```

are eligible to run validators.

### Anti-Affinity

```hcl
constraint {
  distinct_hosts = true
}
```

Ensures one validator per physical machine.

---

## Group Metadata

```hcl
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
```

Nomad exposes these values as environment variables:

```
NOMAD_META_*
```

Used for distributed configuration injection.

---

## Replica Count

```hcl
count = 6
```

Creates six allocations corresponding to six validator nodes.

---

## Task Execution

```hcl
driver = "raw_exec"
```

Validators run directly on the host rather than inside containers.

Benefits:

* Native NVMe access
* Direct networking
* Maximum performance

---

## Startup Script Template

Nomad renders a template into:

```
local/start.sh
```

This script performs all bootstrap logic.

---

## Disk Selection Logic

Validators are distributed across NVMe drives:

```bash
DISK_INDEX=$(( ($NOMAD_META_nomad_group - 1) % $NOMAD_META_node_disk_count + 1))
```

Resulting storage path:

```
/mnt/nvme_drive_X
```

Prevents disk contention.

---

## Binary Auto-Update

```bash
curl -o local/jamduna ${jam_url}/${chain}/jamduna
```

Each node downloads the validator binary at startup, enabling simple rolling upgrades.

---

## Chain Spec Distribution

```bash
curl -o spec.json ...
```

All validators receive the same chain specification.

---

## Node Identity from Host IP

Validator identity is derived from the host IP address:

```bash
INDEX=$(ip ... | awk -F. '{print $4}')
```

Example mapping:

| Host IP       | Validator |
| ------------- | --------- |
| 192.168.20.11 | 11        |
| 192.168.20.12 | 12        |

No central coordinator is required.

---

## Validator Seed Fetch

Each node downloads its validator key:

```bash
SEED_URL=.../keys/seed_${INDEX}
```

This creates deterministic validator assignment and reproducible cluster setup.

---

## Node Launch

```bash
exec ./local/jamduna \
  --chain=spec.json \
  run \
  --dev-validator "$INDEX"
```

Nomad supervises the validator process lifecycle.

---

## Runtime Environment

```hcl
env {
  RUST_BACKTRACE = "full"
  POLKAVM_BACKEND = "compiler"
}
```

Enables detailed debugging and selects runtime backend behavior.

---

## Resource Limits

```hcl
resources {
  memory = 16000
}
```

Each validator reserves 16 GB RAM.

---

## Log Management

Nomad rotates logs automatically:

```hcl
logs {
  max_files     = 5
  max_file_size = 10
}
```


## Notes

* If host IP addresses change, validator identity may break.
* Keys are currently downloaded over HTTP. 
* Validators are typically long-lived services. Consider using `type = "service"` for production networks.

