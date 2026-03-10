
# JAM DUNA - Nomad Setup

To run tiny JAM testnets, we have a Nomad cluster of instances in GCP managed from `coretime`.

Nomad UI:

```
https://nomad.jamtoaster.network/ui/jobs?namespace=jamduna
```

## HCL Jobs

### duna_toaster.hcl - Validators

Starts 6 JAM validators (`jam-0` .. `jam-5`) forming a "tiny" testnet. Each validator downloads the `jamduna` binary and `spec.json` from `coretime`, fetches its validator key based on hostname index, and runs as a `--dev-validator`.

```
nomad run duna_toaster.hcl
nomad job stop -purge -namespace jamduna jamduna
```

Nomad UI: `https://nomad.jamtoaster.network/ui/jobs/jamduna@jamduna`

---

### fib_toaster.hcl - Fib Builder (Rollup Stream)

Runs 3 fib stream tasks (`fib-stream-6`, `fib-stream-7`, `fib-stream-8`) as validators 6/7/8. Uses `rollup-stream-runner --service fib` to continuously submit Fibonacci computation work packages to the JAM testnet.

```
nomad run fib_toaster.hcl
nomad job stop -purge -namespace jamduna jamduna-fib
```

Nomad UI: `https://nomad.jamtoaster.network/ui/jobs/jamduna-fib@jamduna`

---

### evm_toaster.hcl - EVM Builder

Runs 1 EVM stream task on `coretime`. Downloads `evm-stream-runner`, `evm-builder`, and `evm-feeder` binaries and submits EVM-based work packages to the JAM testnet. Fetches seeds 0-6 and runs with validator index 6 implied via the evm-stream-runner.

```
nomad run evm_toaster.hcl
nomad job stop -purge -namespace jamduna jamduna-evm
```

Nomad UI: `https://nomad.jamtoaster.network/ui/jobs/jamduna-evm@jamduna`

---

### monero_toaster.hcl - Monero Rollup

Runs 1 Monero rollup stream task using `rollup-stream-runner --service monero --mode testmonero`. Operates as validator 6, submitting Monero-style rollup work packages to the JAM testnet.

```
nomad run monero_toaster.hcl
nomad job stop -purge -namespace jamduna jamduna-monero
```

Nomad UI: `https://nomad.jamtoaster.network/ui/jobs/jamduna-monero@jamduna`

---

### orchard_toaster.hcl - Orchard Rollup

Runs 1 Orchard rollup stream task using `rollup-stream-runner --service orchard --mode testorchard`. Operates as validator 6, submitting Orchard (Zcash-style) rollup work packages to the JAM testnet.

```
nomad run orchard_toaster.hcl
nomad job stop -purge -namespace jamduna jamduna-orchard
```

Nomad UI: `https://nomad.jamtoaster.network/ui/jobs/jamduna-orchard@jamduna`
