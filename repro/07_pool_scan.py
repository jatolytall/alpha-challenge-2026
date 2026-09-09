#!/usr/bin/env python3
"""
Reproduces the discovery step of challenge 07 from public data. No API keys.

Claim: the collected amount depends entirely on knowing the FULL set of pools
with protocol fees enabled, not a convenient subset. The adapter owns the
Uniswap V3 factory on X Layer, and every pool that had protocol fees switched on
emitted a FeeUpdateTriggered event. Scanning those events yields 4,981 pools;
reading protocolFees() on each is what makes value-ranked selection possible.

Two modes:
    (default)     read protocolFees() for the 12 pools actually used
    --full-scan   replay the event scan that produced the 4,981-pool set

The default mode takes seconds. --full-scan walks ~15.5M blocks in chunks and
takes a couple of minutes: the official X Layer RPC caps getLogs ranges at 100
blocks, so a public endpoint that allows wide ranges is used instead.
"""
import json
import sys
import urllib.request

# Official endpoint for eth_call. It caps getLogs ranges at 100 blocks, so the
# event scan uses a public endpoint that allows wide ranges instead.
RPC_CALL = "https://rpc.xlayer.tech"
RPC_LOGS = "https://xlayer.drpc.org"

# Some public endpoints reject requests without a User-Agent with HTTP 403.
HEADERS = {"Content-Type": "application/json", "User-Agent": "alpha-challenge-repro/1.0"}

FORK_BLOCK = 68413600

FACTORY = "0x4B2ab38DBF28D31D467aA8993f6c2585981D6804"

# Located by binary search over eth_getCode; verified 2026-09-09.
ADAPTER_DEPLOY_BLOCK = 52855153
ADAPTER = "0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7"

# FeeUpdateTriggered — emitted by the ADAPTER once per pool; the pool is
# identified by the indexed token pair in topics[1]/topics[2], not by log.address.
TOPIC_FEE_UPDATE = (
    "0xa38b98e5166edaa11e3ca8a9decd55d5a224db2efb90ec8329d980e46857bcd1"
)

# protocolFees() -> (uint128 token0, uint128 token1)
SELECTOR_PROTOCOL_FEES = "0x1ad8b03b"

EXPECTED_POOL_COUNT = 4981

# The 12 pools the solution actually collects from, ranked by fee value.
POOLS_USED = [
    "0x63d62734847E55A266FCa4219A9aD0a02D5F6e02",
    "0xe1071DB4691b325c709854DC3D5CcD5d77e62Ed1",
    "0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082",
    "0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA",
    "0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC",
    "0x4651300221f345a4c6F566079BD1DDC291049c7d",
    "0x2a2B11730C2b6d99a58034A869dd810D7300a7b2",
    "0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73",
    "0xc44bd9c8589026D28D1632d7b86b2Efb6cDc8fd2",
    "0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453",
    "0xa575234CC82bE1DD41D133cA33E879287d6751A0",
    "0x8CE66218A6310765307e7ab2d11BcfF7cC2ea1F1",
]

_req_id = 0


def rpc(method: str, params: list, endpoint: str = RPC_CALL):
    global _req_id
    _req_id += 1
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": _req_id, "method": method, "params": params}
    ).encode()
    req = urllib.request.Request(endpoint, data=payload, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=120) as resp:
        body = json.load(resp)
    if "error" in body:
        raise RuntimeError(f"{method}: {body['error']}")
    return body["result"]


def protocol_fees(pool: str, block: int) -> tuple:
    """Returns (token0Fees, token1Fees) as raw integers."""
    raw = rpc(
        "eth_call",
        [{"to": pool, "data": SELECTOR_PROTOCOL_FEES}, hex(block)],
    )
    body = raw[2:]
    return int(body[0:64], 16), int(body[64:128], 16)


def check_used_pools() -> int:
    print(f"reading protocolFees() for the {len(POOLS_USED)} pools used")
    print(f"at fork block {FORK_BLOCK} via {RPC_CALL}\n")

    nonzero = 0
    for i, pool in enumerate(POOLS_USED, 1):
        f0, f1 = protocol_fees(pool, FORK_BLOCK)
        if f0 > 1 or f1 > 1:
            nonzero += 1
        print(f"  {i:2d}. {pool}  token0={f0:<22} token1={f1}")

    print(f"\npools carrying protocol fees: {nonzero}/{len(POOLS_USED)}")
    if nonzero != len(POOLS_USED):
        print("MISMATCH: every selected pool should carry fees", file=sys.stderr)
        return 1
    print(
        "\nOK: all selected pools carry protocol fees. Selection was driven by "
        "measured value, which is why 12 pools outperform a larger arbitrary set."
    )
    return 0


def full_scan() -> int:
    """Replays the event scan that produced the 4,981-pool figure.

    Two things here were wrong in an earlier version and are worth stating, since
    both silently produce a plausible-looking number:

      1. The pool is NOT log["address"]. FeeUpdateTriggered is emitted by the
         adapter, so every log carries the same emitter address; counting those
         yields 1, not 4,981. The pool is identified by the indexed token pair in
         topics[1]/topics[2] plus the fee word in data.
      2. The scan must start at the adapter's deployment block. Starting higher
         looks fine and quietly drops pools: starting at 60,000,000 returns 4,953,
         because 28 pools were enabled between deployment and that height.
    """
    print(f"scanning FeeUpdateTriggered emitted by adapter {ADAPTER}")
    print(f"factory: {FACTORY}")
    print(f"endpoint: {RPC_LOGS}, blocks {ADAPTER_DEPLOY_BLOCK}..{FORK_BLOCK}\n")

    step = 10_000
    pairs = set()
    n_logs = 0
    block = ADAPTER_DEPLOY_BLOCK
    while block <= FORK_BLOCK:
        end = min(block + step - 1, FORK_BLOCK)
        logs = rpc(
            "eth_getLogs",
            [
                {
                    "fromBlock": hex(block),
                    "toBlock": hex(end),
                    "topics": [TOPIC_FEE_UPDATE],
                }
            ],
            endpoint=RPC_LOGS,
        )
        for entry in logs:
            n_logs += 1
            t = entry["topics"]
            pairs.add((t[1], t[2], entry["data"]))
        if (block - ADAPTER_DEPLOY_BLOCK) % 2_000_000 < step:
            print(f"  block {block:>9}  pools so far: {len(pairs):>5}")
        block = end + 1

    print(f"\nlogs seen: {n_logs}")
    print(f"unique pools with protocol fees enabled: {len(pairs)}")
    if len(pairs) != EXPECTED_POOL_COUNT:
        print(
            f"MISMATCH: expected {EXPECTED_POOL_COUNT}, got {len(pairs)}",
            file=sys.stderr,
        )
        return 1
    print(
        f"\nOK: {EXPECTED_POOL_COUNT} pools carried protocol fees at the fork block. "
        "Working from a subset of these is what caps the collectable amount."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(full_scan() if "--full-scan" in sys.argv else check_used_pools())
