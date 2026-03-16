# UE to UPF N3 Ping

## Purpose

This note captures the process used to verify that a simulated UE can ping the UPF N3 interface inside this `free5gc-compose` deployment.

## Environment

- Repo path: `/home/huawei/free5gc-compose`
- Stack file: `docker-compose.yaml`
- Running containers included `upf`, `amf`, `smf`, `ueransim`, and other core NFs
- `ueransim` was running as gNB, with a separate `nr-ue` process already started inside the same container

## Relevant Addresses

- UPF container IP on `privnet`: `10.100.200.3`
- gNB/UE container IP on `privnet`: `10.100.200.13`
- UE tunnel interface 1: `uesimtun0` with IP `10.60.0.1/16`
- UE tunnel interface 2: `uesimtun1` with IP `10.61.0.1/16`

The UPF N3 address comes from `config/upfcfg.yaml`, where the N3 interface is configured as `upf.free5gc.org`.

## Validation Steps

### 1. Confirm the core is running

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Expected:
- `upf`, `amf`, `smf`, and `ueransim` should all be `Up`

### 2. Confirm UE tunnels exist

```bash
docker exec ueransim ip addr
```

Expected:
- `uesimtun0` present with `10.60.0.1/16`
- `uesimtun1` present with `10.61.0.1/16`

### 3. Confirm the UPF N3-side IP

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf
```

Observed result:

```text
10.100.200.3
```

### 4. Ping the UPF N3 interface from the first UE tunnel

```bash
docker exec ueransim ping -I uesimtun0 -c 4 10.100.200.3
```

Observed result:

```text
PING 10.100.200.3 (10.100.200.3) from 10.60.0.1 uesimtun0: 56(84) bytes of data.
64 bytes from 10.100.200.3: icmp_seq=1 ttl=64 time=1.82 ms
64 bytes from 10.100.200.3: icmp_seq=2 ttl=64 time=3.49 ms
64 bytes from 10.100.200.3: icmp_seq=3 ttl=64 time=3.89 ms
64 bytes from 10.100.200.3: icmp_seq=4 ttl=64 time=2.77 ms

--- 10.100.200.3 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 1.819/2.990/3.885/0.785 ms
```

### 5. Ping the UPF N3 interface from the second UE tunnel

```bash
docker exec ueransim ping -I uesimtun1 -c 4 10.100.200.3
```

Observed result:

```text
PING 10.100.200.3 (10.100.200.3) from 10.61.0.1 uesimtun1: 56(84) bytes of data.
64 bytes from 10.100.200.3: icmp_seq=2 ttl=64 time=3.41 ms
64 bytes from 10.100.200.3: icmp_seq=3 ttl=64 time=3.61 ms
64 bytes from 10.100.200.3: icmp_seq=4 ttl=64 time=4.28 ms

--- 10.100.200.3 ping statistics ---
4 packets transmitted, 3 received, 25% packet loss, time 3033ms
rtt min/avg/max/mdev = 3.409/3.767/4.283/0.373 ms
```

## If the UE Is Not Already Running

If the `ueransim` container only has the gNB process, start the UE manually:

```bash
docker exec -it ueransim ./nr-ue -c config/uecfg.yaml
```

Then re-run:

```bash
docker exec ueransim ip addr
docker exec ueransim ping -I uesimtun0 -c 4 10.100.200.3
```

## Success Criteria

- UE registration completes successfully
- At least one `uesimtun` interface is created in `ueransim`
- `ping -I uesimtun0 -c 4 10.100.200.3` returns replies from the UPF

## Conclusion

The UE-to-UPF N3 connectivity test succeeded in this environment.
- `uesimtun0` to `10.100.200.3`: success, `0%` packet loss
- `uesimtun1` to `10.100.200.3`: partial success during the sample run
