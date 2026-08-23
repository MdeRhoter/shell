# Shared ccache on the Talos cluster

Continue-here notes for standing up a shared compilation cache. The laptop-side
work is already done and committed; what remains needs `kubectl` access to the
Talos cluster.

## Why this exists

Measured on the Surface laptop (4 cores, 8 GB), full rebuild of the native
plugin — 125 compile steps, 18 link steps:

| Scenario | Wall time | ccache hits |
|---|---|---|
| Baseline: GNU ld, no ccache | **335 s** | — |
| Warm local ccache + mold | **14 s** | 123/125 (98.4%) |

So the *common* case is already solved locally, and no amount of remote compute
can beat 14 s. This cache exists for the one case a local cache cannot help:

**A `pacman -Syu` that bumps `gcc` or `qt6-*` changes the compiler hash and the
header contents, invalidates every local entry, and drops you back to a full
335 s cold build.** On Arch that happens a few times a month. The nightly job
hits the new toolchain first, overnight, and publishes the results — so the
laptop's next build after an upgrade pulls hits over the LAN instead of
recompiling 125 TUs on 4 cores.

## Why a shared cache and not a remote build target

The obvious idea — build on a big machine, copy the `.so` files back (they are
only 5.8 MB) — was rejected, and the reason matters:

- **Artifact copying is fail-dangerous.** The plugin must link against the
  libraries present on *this* laptop at install time. A builder that has drifted
  produces a plausible binary that only fails at load. That is precisely the
  2026-08-23 `libcava` 0.10.7 → 1.0.0 incident, re-created as permanent
  infrastructure.
- **A shared ccache is fail-safe.** ccache's hash covers the compiler binary and
  every preprocessed header. A drifted builder produces a **miss** — you compile
  locally, exactly as today. It is structurally incapable of handing you an
  object built against the wrong libcava.

An `ldd -r` gate could make artifact copying safe, but not needing a gate beats
having one.

## Architecture

```
  laptop ──┐                                   ┌── nginx (WebDAV) ── PVC 20Gi
           ├── HTTP GET/PUT ── ccache-lan LB ──┤
  other  ──┘        (LAN)                      └── in-cluster Service
  machine                                              ▲
                                                       │ nightly 03:00
                                            CronJob: pacman -Syu, clone, build
                                            (publishes entries, installs nothing)
```

Manifests live in `system/k8s/ccache/`, numbered in apply order.

## Prerequisites

1. `kubectl` context pointing at the Talos cluster.
2. A default `StorageClass`. If the cluster has more than one provisioner,
   uncomment `storageClassName` in `10-pvc.yaml`.
3. **A way to get a LAN IP.** Talos ships no cloud load-balancer controller, so
   `type: LoadBalancer` stays `<pending>` unless MetalLB or Cilium L2
   announcements are running. If neither is, switch `ccache-lan` to
   `type: NodePort` and point the laptops at a node IP.
4. If the fork's ghcr package is private, a pull secret for
   `ghcr.io/MdeRhoter/shell-arch-env:latest`, referenced in
   `50-cronjob-prewarm.yaml`.

## Deploy

```bash
kubectl apply -f system/k8s/ccache/00-namespace.yaml

# Credentials. Do NOT commit these; the manifests read them from this secret.
PASS=$(openssl rand -base64 24)
htpasswd -nbB caelestia "$PASS" > /tmp/htpasswd
kubectl -n ccache create secret generic ccache-auth \
  --from-file=htpasswd=/tmp/htpasswd \
  --from-literal=username=caelestia \
  --from-literal=password="$PASS"
shred -u /tmp/htpasswd
echo "save this: $PASS"

kubectl apply -f system/k8s/ccache/
```

Then confirm the image actually has WebDAV — the whole design rests on it:

```bash
kubectl -n ccache exec deploy/ccache -- nginx -V 2>&1 | tr ' ' '\n' | grep dav
# must print --with-http_dav_module
```

If it does not, see [Fallback](#fallback-redis).

Get the address:

```bash
kubectl -n ccache get svc ccache-lan
```

## Point the laptops at it

Edit `system/ccache/ccache.conf`, uncomment the last line, substitute the host
and password:

```
remote_storage = http://caelestia:PASSWORD@10.0.0.50/|connect-timeout=200|operation-timeout=5000
```

Then `./update` to install it (the file is under `$HOME`, so no root needed).

Keep the timeouts short. With an unreachable host every single compile pays the
connect timeout before falling back to local, which makes builds *slower* on any
machine that cannot see the cluster — a laptop away from home, for instance.
That is why the line ships commented out.

## Verify it actually works

```bash
ccache -z
ninja -C build -t clean
cmake --build build
ccache --show-stats --verbose | grep -iA4 remote
```

You want non-zero **Remote storage / Hits**. Zero remote hits with healthy local
hits means the cache is reachable but nothing matches — go read the gotchas
below, particularly `compiler_check`.

Server side:

```bash
kubectl -n ccache exec deploy/ccache -- du -sh /data
kubectl -n ccache logs -l app=ccache --tail=50
```

## Gotchas

These are the settings that produce a cache which looks healthy and silently
does nothing.

| Setting | Default | Why it must change |
|---|---|---|
| `compiler_check` | `mtime` | **The one that decides whether sharing works at all.** Folds `/usr/bin/g++`'s mtime into the hash. Two machines with the identical gcc package have different mtimes, so the default guarantees a 100% cross-machine miss rate while looking perfect locally. Set to `content`. |
| `base_dir` | unset | The laptop builds in `/home/martijn/.config/quickshell/caelestia`, the job in `/workspace`. Without rewriting, no hash ever agrees. Set to `/home` locally, `/workspace` in the job. |
| `hash_dir` | `true` | Folds the CWD into the hash, same problem. |
| `sloppiness` | unset | The build uses PCH (9 files, 193 MB each). Without `pch_defines,time_macros` ccache refuses to cache any PCH-consuming compile — a ~0% hit rate that reads as "ccache does not help here". |
| nginx `create_full_put_path` | off | ccache's `subdirs` layout PUTs to `/ab/cdef…`; without this every PUT 409s. |
| nginx `client_body_temp_path` | `/var/cache/nginx` | Must be on the **same filesystem** as `root`. nginx buffers then `rename(2)`s; across filesystems that is `EXDEV` and every PUT 500s. Moved under `/data`. |
| nginx `client_max_body_size` | `1m` | Truncates larger objects into 413s. |
| `fsGroup` | unset | The nginx worker is uid 101. Without it PUTs 500 while GETs succeed — a cache that never fills. |

**Changing the three cross-machine settings invalidates your existing local
cache exactly once.** Verified on one target: 0/59 hits at 209 s, then 59/59 at
8 s on the next build. They are set unconditionally in `ccache.conf` — even
before `remote_storage` is enabled — so the local cache is already populated in
the shared format and turning the remote on later costs nothing extra.

## Operations

**Prune.** nginx never evicts; ccache clients only GET/PUT. When `/data`
approaches the PVC size:

```bash
kubectl -n ccache exec deploy/ccache -- find /data -type f -atime +30 -delete
```

**Rotate credentials.** Recreate the `ccache-auth` secret, `kubectl -n ccache
rollout restart deploy/ccache`, and update `ccache.conf` on every machine.

**Run the pre-warm now** instead of waiting for 03:00:

```bash
kubectl -n ccache create job --from=cronjob/ccache-prewarm prewarm-manual
kubectl -n ccache logs -f job/prewarm-manual
```

The last thing it prints is `ccache --show-stats --verbose`.

**Disable.** Comment out `remote_storage` and re-run `./update`. Everything
keeps working at local-cache speed; nothing else depends on the cluster.

## Fallback: Redis

If the nginx image lacks the dav module, ccache also speaks
`remote_storage = redis://host:6379`. It is a simpler deployment but holds the
cache in RAM, so size the pod against the cache rather than the 20 Gi PVC. The
laptop-side settings in the gotchas table are unchanged — they are properties of
the hash, not the transport.

## Open questions for whoever picks this up

- Does the cluster have MetalLB / Cilium L2, or is NodePort the path?
- Is `ghcr.io/MdeRhoter/shell-arch-env:latest` published under the fork? The CI
  workflows already assume it; if it was never built, run **Update Docker CI
  image** once via `workflow_dispatch`.
- Is the nightly schedule right? It only needs to beat the morning's first
  build, and only matters on days when Arch shipped a new gcc or qt6.
