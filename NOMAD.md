To start a job with nomad below are command, we need to start very first jam-setup.nomad to set env

```
nomad job run jam-setup.nomad
nomad job run jam-validator.nomad
nomad job run jam-fib.nomad
```

To stop job jam-validator ... we don't need to stop jam-setup 

```
nomad job stop -purge jam-validator
nomad system gc
```