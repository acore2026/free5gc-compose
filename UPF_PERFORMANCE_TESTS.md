# UPF Performance Tests

## Scope

This note records the local one-UPF performance tests run in this repo while comparing the kernel `gtp5g` forwarder with the userspace forwarder.

The focus was:

- local UE-to-UPF N3 latency
- local TCP throughput with `iperf3`
- local UDP behavior with `iperf3`
- coarse CPU usage during load

## Test Setup

- Repo: `/home/huawei/free5gc-compose`
- Stack file: `docker-compose.yaml`
- Test date: `2026-03-19`
- UE and gNB ran inside the same `ueransim` container
- An `nr-ue` process was started manually inside `ueransim`
- The first UE tunnel was used for tests: `uesimtun0` with source IP `10.60.0.1`
- `iperf3` server ran inside the `upf` container and was bound to the UPF container IP on `privnet`

Forwarder variants:

- `gtp5g`: `config/upfcfg.yaml`
- `userspace`: `config/upfcfg-userspace.yaml`

Compose switch:

- `docker-compose.yaml` was edited to mount either `config/upfcfg.yaml` or `config/upfcfg-userspace.yaml`
- userspace mode also required `/dev/net/tun`

Important routing detail:

- Throughput tests were only considered valid when the client was bound to the UE tunnel source with `-B 10.60.0.1`
- Unbound local transfers can bypass the UE tunnel and use `eth0`, which gives misleadingly high results

## Method

### Bring up the stack

```bash
docker compose -f docker-compose.yaml down --remove-orphans
docker compose -f docker-compose.yaml up -d
```

### Start the UE

```bash
docker exec ueransim ./nr-ue -c ./config/uecfg.yaml
```

### Confirm the tunnel and UPF mode

```bash
docker exec ueransim ip addr show uesimtun0
docker exec upf sh -lc 'grep -n "forwarder" /free5gc/config/upfcfg.yaml'
docker exec upf sh -lc 'ip link show | grep -E "upf(gtp|usr)" || true'
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf
```

### Ping test

```bash
docker exec ueransim ping -I uesimtun0 -c 10 <upf_ip>
```

### TCP throughput test

Start server:

```bash
docker exec upf sh -lc 'iperf3 -s -B <upf_ip>'
```

Run client:

```bash
docker exec ueransim sh -lc 'iperf3 -c <upf_ip> -B 10.60.0.1 -t 10'
```

### UDP throughput/loss test

Start server:

```bash
docker exec upf sh -lc 'iperf3 -s -B <upf_ip> -p <port>'
```

Run client:

```bash
docker exec ueransim sh -lc 'iperf3 -u -c <upf_ip> -p <port> -B 10.60.0.1 -b 100M -t 5'
```

### CPU sampling

```bash
docker stats --no-stream upf ueransim
```

## Results

### Userspace forwarder

Clean userspace TCP sample:

- UPF mode: `userspace`
- UPF IP during that run: `10.100.200.3`
- `ping -I uesimtun0 -c 10 10.100.200.3`
  - `0%` packet loss
  - avg RTT `7.41 ms`
- `iperf3 -c 10.100.200.3 -B 10.60.0.1 -t 10`
  - sender `110 Mbits/sec`
  - receiver `110 Mbits/sec`
  - retransmissions `194`

Clean userspace UDP `100 Mbit/s` sample:

- UPF mode: `userspace`
- UPF IP during that run: `10.100.200.2`
- `ping -I uesimtun0 -c 5 10.100.200.2`
  - `0%` packet loss
  - avg RTT `2.53 ms`
- `iperf3 -u -c 10.100.200.2 -p 5208 -B 10.60.0.1 -b 100M -t 5`
  - sender `100 Mbits/sec`
  - receiver `96.8 Mbits/sec`
  - receiver loss `1467/46372` = `3.2%`
  - jitter `0.184 ms`
  - out-of-order datagrams reported by server: `10415`

Userspace CPU snapshot around the UDP `100 Mbit/s` run:

- before: `upf 1.52%`, `ueransim 5.11%`
- after: `upf 4.19%`, `ueransim 0.51%`

Observed userspace behavior at higher offered UDP load:

- at `200 Mbit/s`, the path showed high loss from the start and could become unstable
- representative server-side loss during one run ranged roughly from `31%` to `67%`
- this pointed to packet handling / queueing limits rather than CPU saturation

### gtp5g forwarder

Clean `gtp5g` retest:

- UPF mode: `gtp5g`
- UPF IP during that run: `10.100.200.2`
- `ping -I uesimtun0 -c 10 10.100.200.2`
  - `30%` packet loss
  - avg RTT `21.39 ms`
- `iperf3 -c 10.100.200.2 -B 10.60.0.1 -t 10`
  - sender `20.7 Mbits/sec`
  - receiver `0 bits/sec`
  - retransmissions `95`
  - transfer collapsed after roughly 6 seconds

An earlier non-clean `gtp5g` sample in the same session was better:

- avg RTT `1.93 ms`
- sender `43.8 Mbits/sec`
- receiver `42.6 Mbits/sec`

That earlier result is kept here for reference, but the fully reset retest above is the cleaner comparison point.

## Interpretation

- The earlier catastrophic userspace cap around `1 Mbit/s` was fixed before these measurements.
- After that fix, the userspace forwarder outperformed the `gtp5g` retest in this local one-UPF setup.
- The remaining userspace issue is not CPU saturation.
- The main remaining userspace symptom is packet reordering plus some UDP loss under load.
- UDP at `100 Mbit/s` is mostly sustainable on a fresh userspace stack, but it is not lossless.
- Higher offered UDP rates can destabilize the local path.

## Caveats

- These are local container-to-container measurements over the simulated UE path, not external DN benchmarks.
- The UPF container IP changed across recreates, so each run must confirm the current UPF IP first.
- `iperf3` UDP teardown was sometimes awkward in this environment; server-side logs were used when needed.
- Results here are intended as reproducible debugging notes, not as formal performance claims.
