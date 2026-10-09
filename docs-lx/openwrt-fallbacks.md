# Ordered reserves in the OpenWrt Podkop profile

These extensions are applied by `scripts/prepare-openwrt.sh` only for the Podkop
profile. The ordinary lx source and non-profile builds retain the author API.
Patch 0012 adapts the ordered-member policy of FiyeroT/podkop-engine
(`c89d4587dc22b6668e88061eb169ae4d98a1a153`, GPL-3.0-or-later) to lx's lifecycle
and reactive dial path. Patch 0013 adds independent, optional recovery confirmation.

```json
{
  "type": "urltest",
  "tag": "section",
  "outbounds": ["primary"],
  "fallbacks": ["reserve-one", "reserve-two"],
  "interval": "30s",
  "fallback_recovery": {"successes": 3, "min_healthy_time": "60s"}
}
```

Responding primary members win over reserves regardless of latency; multiple
primary members retain URLTest's tolerance. Reserves are selected in list order.
All members are probed each interval and included in dependencies and Clash API.
`fallbacks` requires `least_test` (or omitted mode); it cannot be combined with
lx's hold-until-failure mode or rotation pool. A failed proxy-server TCP dial can
trigger lx's one reserve retry, including connection refusal. Cancellation by the
caller does not declare a member dead. This is not the full podkop-engine
first-response watcher: a connection established successfully but then silent is
still detected by the periodic URLTest.

Without `fallback_recovery`, the first responding primary is immediately eligible,
as in the author policy. With it, a failed member needs the configured number of
successful probes, spaced by at least the group interval, and successful proof
spanning the healthy duration. A new failure resets confirmation; elapsed time,
stale history, and a burst of manual tests cannot satisfy it. Confirmation state
is synchronized, per-group and in memory. When every stable alternative is down,
a responding member still in confirmation remains usable as a last resort.

Defaults when the object is present are 3 successes and 1 minute. Successes may
be 1–100 (0 means default); healthy time may be explicitly 0–24h. Restarting the
core clears confirmation history. Existing connections are not migrated to another
server; a reactive retry affects new TCP connections, and UDP health still relies
on probes.
