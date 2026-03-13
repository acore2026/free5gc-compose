# Session Notes

## Host Facts

- Repo path: `/home/acore/proj/go/free5gc-compose`
- Host Docker CLI supports `docker-compose` v1.29.2, not `docker compose`.
- Host kernel: `6.6.87.2-microsoft-standard-WSL2`
- `gtp5g` kernel module is not available on this host.
- Result: full UPF/user-plane testing is blocked here, but control-plane registration works.

## Local Repo Changes Made

- Added registration-only stack:
  - [`docker-compose-registration.yaml`](/home/acore/proj/go/free5gc-compose/docker-compose-registration.yaml)
- Added UE config without initial PDU sessions:
  - [`config/uecfg-registration.yaml`](/home/acore/proj/go/free5gc-compose/config/uecfg-registration.yaml)
- Patched Debian-based Dockerfiles to rewrite apt sources to HTTPS before package install:
  - [`base/Dockerfile`](/home/acore/proj/go/free5gc-compose/base/Dockerfile)
  - [`base/Dockerfile.nf.webconsole`](/home/acore/proj/go/free5gc-compose/base/Dockerfile.nf.webconsole)
  - [`nf_upf/Dockerfile`](/home/acore/proj/go/free5gc-compose/nf_upf/Dockerfile)
  - [`webui/Dockerfile`](/home/acore/proj/go/free5gc-compose/webui/Dockerfile)
  - [`ueransim/Dockerfile`](/home/acore/proj/go/free5gc-compose/ueransim/Dockerfile)
  - [`n3iwue/Dockerfile`](/home/acore/proj/go/free5gc-compose/n3iwue/Dockerfile)

## Registration-Only Topology

Included services:

- `mongodb`
- `nrf`
- `amf`
- `ausf`
- `nssf`
- `pcf`
- `udm`
- `udr`
- `webui`
- `ueransim` (gNB container)

Excluded services:

- `upf`
- `smf`
- `n3iwf`
- `tngf`
- `nef`
- `chf`
- `n3iwue`

Important note:

- Removing `PCF` prevented registration completion.
- Final working registration-only stack still needs `PCF`, but does not need `UPF`.

## WebUI Credentials

- URL: `http://localhost:5000`
- Username: `admin`
- Password: `free5gc`

## Test UE / Subscriber Values

UE config used by the running stack:

- Mounted file: [`config/uecfg-registration.yaml`](/home/acore/proj/go/free5gc-compose/config/uecfg-registration.yaml)
- Mounted in container as `/ueransim/config/uecfg.yaml`

Key UE identity:

- SUPI: `imsi-208930000000001`
- MCC: `208`
- MNC: `93`
- AMF: `8000`
- Key: `8baf473f2f8fd09487cccbd7097c6862`
- OP type: `OPC`
- OPC: `8e27b6af0e692e750f32667a3b14605d`

Subscriber provisioning note:

- The subscriber must use `opc.opcValue = 8e27...`
- `milenage.op.opValue` must be empty for this UE, because the UE config uses `opType: OPC`.

## Commands That Worked

Start registration-only stack:

```bash
cd /home/acore/proj/go/free5gc-compose
docker-compose -f docker-compose-registration.yaml up -d
```

Trigger initial registration:

```bash
docker exec -it ueransim ./nr-ue -c ./config/uecfg.yaml
```

Restart UE to trigger a fresh initial registration:

```bash
docker exec -it ueransim pkill nr-ue
docker exec -it ueransim ./nr-ue -c ./config/uecfg.yaml
```

Useful logs:

```bash
docker logs -f amf
docker logs -f ueransim
docker logs -f pcf
```

## Expected Success Signals

UE log:

- `Sending Initial Registration`
- `Registration accept received`
- `Initial Registration is successful`

AMF log:

- `Handle Registration Request`
- `Send Registration Accept`
- `Handle Registration Complete`
- transition to `Registered`

## Failure Modes Seen During This Session

- Without `UPF`: user plane is unavailable, but registration can still work.
- Without `PCF`: AMF failed initial registration completion with `AMF can not select an PCF by NRF`.
- Wrong subscriber auth format:
  - First failure: `Mac Failure`
  - Second partial fix: `Synch Failure`
  - Final fix: correct `OPC` subscriber auth data

## Current Conclusion

- On this WSL2 host, we can test initial registration successfully.
- On this host, we cannot test UPF-dependent user plane unless `gtp5g` is available on a supported Linux kernel.
