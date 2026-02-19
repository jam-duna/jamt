# JAM DUNA Public Release Bundle (Linux AMD64)

This release is a **single-machine testnet bundle** for `jamduna`.

Primary goal:
- bring up a reproducible local JAM testnet (6 validators).

Optional goal:
- run FIB flow (`fib-stream-runner`) after validators are healthy, with log-based rollup health checks.

## Choose Your Path First

Use this bundle in one of these modes:

1. Single-machine local testnet (recommended)
- Use the included `Makefile` directly.
- This is the default and documented path.

2. Multi-machine deployment (advanced)
- Use your own deployment/orchestration system.
- See **Appendix: Multi-machine flow** at the end.

If you are not sure, use **single-machine**.

## What Is Included

- `jamduna`
- `fib-stream-runner`
- bundled FIB deps:
  - `runner/fib-builder`
  - `runner/fib-feeder`
- minimal genesis bundle for `gen-spec`:
  - `release_genesis_services/evm.pvm` (bootstrap host service for auth-code preimage on service 0)
  - `release_genesis_services/auth_copy.pvm`
  - `release_genesis_services/fib.jam`
  - `release_genesis_services/null_authorizer.pvm`
- `chainspecs/local-dev-config.json`
- `chainspecs/jamduna-spec.json`
- `Makefile`

## Prerequisites

- Linux AMD64
- `bash`, `make`
- Free local ports:
  - P2P: `40000..40005`
  - JSON-RPC: `19800..19805`
  - FIB RPC (optional): `8601`

## Single-Machine Quick Start (Recommended)

Run from this release directory (the folder containing this README and Makefile).

### 0) Always reset local state first

If this folder was reused or unpacked from someone else, reset first:

```bash
make clean-state
```

### 1) See available targets

```bash
make help
```

### 2) Generate keys

```bash
make gen-keys
```

This creates `seed_0..seed_6` under `state/keys/`.

Important:
- validators are `0..5`
- `seed_6` is reserved for optional builder role (FIB), not a validator process

Each seed is a deterministic 32-byte file derived from the validator index using the `trivial_seed()` scheme defined in [JIP-5](https://github.com/polkadot-fellows/JIPs/blob/main/JIP-5.md). The same seed is used to derive Bandersnatch, Ed25519, and BLS keys via domain-separated BLAKE2b hashing. You can verify with `xxd`:

```bash
# seed_0 = index 0 → all zeros (32 bytes)
xxd state/keys/seed_0
00000000: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................

# seed_1 = index 1 → 0x01000000 repeated 8 times (little-endian uint32)
xxd state/keys/seed_1
00000000: 0100 0000 0100 0000 0100 0000 0100 0000  ................
00000010: 0100 0000 0100 0000 0100 0000 0100 0000  ................
```

### 3) Generate chainspec

```bash
make gen-spec
```

### 4) Start validators

```bash
make run-validators
```

### 5) Check process and activity health

```bash
make status
make health
```

`make health` checks:
- validator logs for `Imported Block`

For deeper FIB signals (refine/accumulate/builder), see the FIB section at the end.

## Optional FIB Flow (After Validators Are Healthy)

Start FIB runner:

```bash
make run-fib-stream
```
- runs in background
- writes logs to files under `logs/`
- does not stream live output to terminal
- stop with:
```bash
make stop-fib
```

## Operational Checks (Concrete)

Validator block production (example for validator 0):

```bash
grep -n "Imported Block" logs/jamduna-v0.log | tail
```

Validator rollup/refine path (UP1 checkpoint announcements):

```bash
grep -n "Processed UP1 checkpoint announcement" logs/jamduna-v*.log | tail
```

Validator accumulate path:

```bash
grep -n "Work package accumulated\|SubmitAndWaitForWorkPackageBundle ACCUMULATED" logs/jamduna-v*.log | tail
```

FIB rollup blocks with Fib txns (aggregated ranges):

```bash
grep -n "FIB: built rollup block" logs/fib-builder-stream-runner.log | tail
```

FIB UBT roots (pre/post roots for witness generation):

```bash
grep -n "FIB: buildUBTWitnessesForRanges range timing" logs/fib-builder-stream-runner.log | tail
```

FIB submission path:

```bash
grep -n "Work package SUBMITTED\|SubmitBundleToCore CE146 SUCCESS" logs/fib-builder-stream-runner.log | tail
```

Feeder submission activity:

```bash
grep -n "submitted call=" logs/fib-feeder-stream-runner.log | tail
```

## Cleanup

Stop validators and background FIB runner:

```bash
make stop
```

Reset state:

```bash
make clean-state
```

## Using `jamduna` Binary Directly

If your deployment system manages startup itself, you can bypass the release Makefile.

1. Generate keys:

```bash
./jamduna gen-keys --data-path /var/lib/jamduna
```

2. Generate chainspec:

```bash
./jamduna gen-spec /etc/jam/chain-config.json /etc/jam/jamduna-spec.json
```

3. Start validator node (example index 0):

```bash
./jamduna run \
  --data-path /var/lib/jamduna \
  --chain /etc/jam/jamduna-spec.json \
  --dev-validator 0 \
  --pvm-backend compiler \
  --rpc-port 19800
```

Repeat for `--dev-validator 1..5`.

## Minimal Multi-Machine Example (3 Machines, 6 Validators)

Use this when you want a concrete deployment shape, not just principles.

### A) Topology

- Machine A (`10.0.0.11`): validator `0`, `1`
- Machine B (`10.0.0.12`): validator `2`, `3`
- Machine C (`10.0.0.13`): validator `4`, `5`

Optional proxy/builder node:
- Machine C also runs `--dev-validator 6 --role builder`

### B) Chain config (do this once on deploy controller)

Create a multi-machine chain config (do not use localhost addresses):

```json
{
  "genesis_validators": [
    {"index": 0, "net_addr": "10.0.0.11:40000"},
    {"index": 1, "net_addr": "10.0.0.11:40001"},
    {"index": 2, "net_addr": "10.0.0.12:40002"},
    {"index": 3, "net_addr": "10.0.0.12:40003"},
    {"index": 4, "net_addr": "10.0.0.13:40004"},
    {"index": 5, "net_addr": "10.0.0.13:40005"}
  ]
}
```

Then generate one shared chainspec:

```bash
./jamduna gen-spec /etc/jam/chain-config.json /etc/jam/jamduna-spec.json
```

Distribute exactly the same `jamduna` binary and `jamduna-spec.json` to all machines.

### C) Start commands per machine

Machine A:

```bash
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 0 --pvm-backend compiler --rpc-port 19800
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 1 --pvm-backend compiler --rpc-port 19801
```

Machine B:

```bash
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 2 --pvm-backend compiler --rpc-port 19802
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 3 --pvm-backend compiler --rpc-port 19803
```

Machine C:

```bash
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 4 --pvm-backend compiler --rpc-port 19804
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 5 --pvm-backend compiler --rpc-port 19805
```

Optional proxy/builder on Machine C:

```bash
./jamduna run --data-path /var/lib/jamduna --chain /etc/jam/jamduna-spec.json --dev-validator 6 --role builder --pvm-backend compiler --rpc-port 19806
```

### D) Rollout order

1. Start all validator processes (`0..5`) in a tight rollout window.
2. Verify each node shows block import activity in logs.
3. Start optional builder/proxy node (`6`) only after validator network is stable.

## Appendix: Multi-Machine Flow (Advanced)

Use this only when validators run on separate machines.

1. Generate one shared chainspec from one chain config.
2. Distribute the exact same `jamduna` binary and chainspec to all machines.
3. Distribute keys so node `i` has access to `seed_i` under its `--data-path/keys/`.
4. Start validator processes (`0..5`) in a tight rollout window.
5. Optionally run a proxy/builder node as `--dev-validator 6 --role builder` for external sync/debug integration.

This release bundle remains optimized for single-machine testing; multi-machine is an operational extension.

## FIB Rollup Test: What It Demonstrates

FIB is the smallest rollup service in this bundle. It is intended to demonstrate the rollup flow clearly:

- Fib transactions are generated as ranges and batched into rollup blocks.
- Builder logs show rollup block creation and Fib tx counts (`FIB: built rollup block`).
- Builder logs show UBT state transition witnesses with pre/post roots (`preRoot`, `postRoot`).
- Validators receive UP1 checkpoint announcements and execute the refine path in parallel.
- Work packages are then accumulated on-chain (`Work package accumulated`).

This is the core JAM rollup-host model: rollup txns -> rollup blocks -> witness/finality -> refine -> accumulate.  
The same abstractions can be reused for richer rollups.

### What To Watch In Logs

1. Refine signals:
```bash
grep -n "Fib refine started\|Fib refine payload\|Fib refine completed\|Fib refine rollup finality ok" logs/jamduna-v*.log | tail
```
2. Accumulate signals:
```bash
grep -n "Fib accumulate started\|Fib accumulate context\|Fib accumulate completed\|Finality: recorded BlockEntry" logs/jamduna-v*.log | tail
```
3. Builder health:
```bash
grep -n "FIB: built rollup block\|Work package SUBMITTED\|SubmitBundleToCore CE146 SUCCESS" logs/fib-builder-stream-runner.log | tail
```
Healthy builder behavior means these lines keep appearing over time and you do not see repeated auth-code-not-found failures.
4. Recommended runtime:
- Let the FIB flow run for around 30 minutes, then stop it manually:
```bash
make stop
```
