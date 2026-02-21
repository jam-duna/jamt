
# JAM DUNA - Nomad Setup

To run tiny JAM testnets, we have a nomad cluster of 7 instances in GCP:
 * `jam-0`.. `jam-5` - 6 JAM validators forming a "tiny" testnet, setup with `duna.hcl` (see "Setup Validators")
 * `coretime` - 1 JAM builder submitting JAM work packages, setup with `fib.hcl` (see "Setup Builders")

Nomad runs on `coretime`:

```
http://coretime.jamduna.org:4646/ui/jobs
http://coretime.jamduna.org:4646/ui/clients
http://coretime.jamduna.org:4646/ui/servers
http://coretime.jamduna.org:4646/ui/jobs/jamduna@default
```

## Setup Validators

The [duna.hcl](duna.hcl) Nomad job file is used to start up validators:

```
# nomad run duna.hcl
==> View this job in the Web UI: http://127.0.0.1:4646/ui/jobs/jamduna@default

==> 2026-02-20T15:52:56Z: Monitoring evaluation "4a9c09be"
    2026-02-20T15:52:56Z: Evaluation triggered by job "jamduna"
    2026-02-20T15:52:57Z: Allocation "9f5bd9f5" created: node "a067b925", group "jamduna"
    2026-02-20T15:52:57Z: Allocation "df532c4a" created: node "90706a00", group "jamduna"
    2026-02-20T15:52:57Z: Allocation "46b26209" created: node "6c6f34a5", group "jamduna"
    2026-02-20T15:52:57Z: Allocation "6181e736" created: node "c176cefe", group "jamduna"
    2026-02-20T15:52:57Z: Allocation "62644fed" created: node "1792fcc8", group "jamduna"
    2026-02-20T15:52:57Z: Allocation "7a2e96c1" created: node "63cff9ac", group "jamduna"
    2026-02-20T15:52:57Z: Evaluation status changed: "pending" -> "complete"
==> 2026-02-20T15:52:57Z: Evaluation "4a9c09be" finished with status "complete"
root@coretime:~/go/src/github.com/colorfulnotion/jamt# nomad node status
ID        Node Pool  DC   Name                                       Class   Drain  Eligibility  Status
63cff9ac  default    dc1  jam-1.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
1792fcc8  default    dc1  jam-5.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
90706a00  default    dc1  jam-4.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
c176cefe  default    dc1  jam-3.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
a067b925  default    dc1  jam-2.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
a4489629  default    dc1  jam-1.us-central1-b.c.jamduna.internal     <none>  false  ineligible   down
2d05e850  default    dc1  jam-1.us-central1-b.c.jamduna.internal     <none>  false  ineligible   down
6c6f34a5  default    dc1  jam-0.us-central1-b.c.jamduna.internal     <none>  false  eligible     ready
ed111410  default    dc1  coretime.us-central1-c.c.jamduna.internal  <none>  false  eligible     ready
```

To stop the validators:

```
# nomad job stop -purge jamduna
==> 2026-02-20T15:52:00Z: Monitoring evaluation "e75bc39f"
    2026-02-20T15:52:00Z: Evaluation triggered by job "jamduna"
    2026-02-20T15:52:01Z: Evaluation status changed: "pending" -> "complete"
==> 2026-02-20T15:52:01Z: Evaluation "e75bc39f" finished with status "complete"
```

## Running Builders

### Fib

To run the fib service so that there is 1 builder runing on `coretime`, run the `fib.hcl` Nomad following the guide below.


To Run fib builder
```
nomad run fib.hcl 
```

A set of binaries:
* fib-builder - runs a JAM Validator and connects to the JAM tiny testnet
* fib-feeder + fib-stream-runner  - submits "transactions" to the builder


To Stop fib builder:
```
nomad stop -purge jam-fib
```

You can then see it in the UI here:

```
http://coretime.jamduna.org:4646/ui/jobs/jam-fib@default
```

and see logs here:

```
http://coretime.jamduna.org:4646/ui/allocations/e533614a-54ca-64d7-fbfa-45c81a9e262f/fib-stream/logs
```






