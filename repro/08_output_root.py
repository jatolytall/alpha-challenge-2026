#!/usr/bin/env python3
"""
Reproduces the key step of challenge 08 from public data. No API keys, and
crucially no archive access.

Claim: an OP Stack output root needs the storage root of the L2ToL1MessagePasser
predeploy, which normally means eth_getProof against an archive node hundreds of
thousands of blocks back. No free endpoint serves that, and paid ones refuse it
too ("distance to target block exceeds maximum proof window").

It can be read off L1 instead. Anyone proving a withdrawal calls
proveWithdrawalTransaction on OptimismPortal2 and passes an OutputRootProof
struct in calldata, which contains that exact storage root. Since the window of
interest has no MessagePassed events, the storage root is constant across it,
so one third-party proof covers the whole range.

This script:
  1. reads the storage root out of a real L1 transaction's calldata
  2. fetches the L2 header from a free RPC
  3. recomputes the output root and checks it against the submitted answer

Output root = keccak256(version . stateRoot . messagePasserStorageRoot . blockHash)
"""
import json
import sys
import urllib.request

L1_RPC = "https://rpc.mevblocker.io"
OP_RPC = "https://mainnet.optimism.io"
HEADERS = {"Content-Type": "application/json", "User-Agent": "alpha-challenge-repro/1.0"}

# OptimismPortal2 on L1.
PORTAL = "0xbEb5Fc579115071764c7423A4f12eDde41f106Ed"

# A third-party withdrawal proof whose OutputRootProof falls inside the window.
PROOF_TX = "0xfadeae31804e8479f359083ec6022e4f0745722b023b25966f6c8056a4fbb733"

# In proveWithdrawalTransaction calldata the OutputRootProof struct is static and
# sits inline in the head: word2 version, word3 stateRoot, word4 storage root,
# word5 latestBlockhash.
WORD_STORAGE_ROOT = 4

EXPECTED_STORAGE_ROOT = (
    "0xa01a8efbb96fe07d1be06c608c3d0767daa6377dbdbd90831a8983826fb6a1d3"
)

# The answer submitted for the Optimism game.
OP_BLOCK = 155_749_670
OP_CLAIM = "0x192f163548d61d555a282e1ffcec8ec7b1e4cf9deced7e910b87292f0aeab5f1"


# --- Keccak-256 -------------------------------------------------------------
# Ethereum uses original Keccak, NOT the finalised NIST SHA3, so hashlib.sha3_256
# gives a different digest. Implemented here to keep the script dependency-free.
_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROT = [
    [0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56], [27, 20, 39, 8, 14],
]
_MASK = (1 << 64) - 1


def _rol(x, n):
    return ((x << n) | (x >> (64 - n))) & _MASK


def _keccak_f(a):
    for rnd in range(24):
        c = [a[x][0] ^ a[x][1] ^ a[x][2] ^ a[x][3] ^ a[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rol(c[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                a[x][y] ^= d[x]
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rol(a[x][y], _ROT[x][y])
        for x in range(5):
            for y in range(5):
                a[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y]) & _MASK) & b[(x + 2) % 5][y]
        a[0][0] ^= _RC[rnd]
    return a


def keccak256(data: bytes) -> bytes:
    rate = 136
    a = [[0] * 5 for _ in range(5)]
    padded = bytearray(data) + b"\x01"
    while len(padded) % rate:
        padded.append(0)
    padded[-1] ^= 0x80
    for off in range(0, len(padded), rate):
        block = padded[off:off + rate]
        for i in range(rate // 8):
            lane = int.from_bytes(block[i * 8:(i + 1) * 8], "little")
            a[i % 5][i // 5] ^= lane
        a = _keccak_f(a)
    out = b""
    for i in range(4):
        out += a[i % 5][i // 5].to_bytes(8, "little")
    return out[:32]


# --- RPC --------------------------------------------------------------------
def rpc(endpoint: str, method: str, params: list):
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    ).encode()
    req = urllib.request.Request(endpoint, data=payload, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.load(resp)
    if "error" in body:
        raise RuntimeError(f"{method}: {body['error']}")
    return body["result"]


def main() -> int:
    # Sanity-check the hash function before trusting anything it produces.
    empty = keccak256(b"").hex()
    if empty != "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470":
        print(f"keccak256 self-test FAILED: {empty}", file=sys.stderr)
        return 1
    print("keccak256 self-test: OK\n")

    # 1. storage root straight out of L1 calldata — no archive node involved
    tx = rpc(L1_RPC, "eth_getTransactionByHash", [PROOF_TX])
    if tx["to"].lower() != PORTAL.lower():
        print(f"unexpected callee {tx['to']}", file=sys.stderr)
        return 1
    body = tx["input"][2:][8:]  # strip 0x and the 4-byte selector
    word = body[WORD_STORAGE_ROOT * 64:(WORD_STORAGE_ROOT + 1) * 64]
    storage_root = "0x" + word
    print(f"withdrawal proof tx: {PROOF_TX}")
    print(f"  portal:              {tx['to']}")
    print(f"  storage root (L1):   {storage_root}")
    if storage_root != EXPECTED_STORAGE_ROOT:
        print(
            f"MISMATCH: expected {EXPECTED_STORAGE_ROOT}", file=sys.stderr
        )
        return 1

    # 2. plain header read, well within what free endpoints serve
    header = rpc(OP_RPC, "eth_getBlockByNumber", [hex(OP_BLOCK), False])
    state_root = header["stateRoot"]
    block_hash = header["hash"]
    print(f"\noptimism block {OP_BLOCK}")
    print(f"  stateRoot:           {state_root}")
    print(f"  blockHash:           {block_hash}")

    # 3. output root = keccak(version . stateRoot . storageRoot . blockHash)
    preimage = (
        b"\x00" * 32
        + bytes.fromhex(state_root[2:])
        + bytes.fromhex(storage_root[2:])
        + bytes.fromhex(block_hash[2:])
    )
    computed = "0x" + keccak256(preimage).hex()
    print(f"\ncomputed output root:  {computed}")
    print(f"submitted answer:      {OP_CLAIM}")

    if computed != OP_CLAIM:
        print("\nMISMATCH", file=sys.stderr)
        return 1

    print(
        "\nOK: the output root reproduces exactly, and every input came from a "
        "free endpoint — the storage root from L1 calldata, the header from a "
        "public L2 RPC. No eth_getProof, no archive node, no keys."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
