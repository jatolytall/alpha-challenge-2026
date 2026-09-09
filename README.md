# Wintermute Alpha Challenge 2026

[![verify](https://github.com/jatolytall/alpha-challenge-2026/actions/workflows/verify.yml/badge.svg)](https://github.com/jatolytall/alpha-challenge-2026/actions/workflows/verify.yml)

All nine challenges solved, 900/900. This repository is less about the answers,
which are the same for everyone who finishes, and more about the method: every
result here is reproducible from a clean machine, and no step needs a paid or
keyed endpoint

Challenge repository: https://github.com/WintermuteResearch/Alpha-Challenge-2026

## Reproducibility

```bash
git clone --recurse-submodules https://github.com/jatolytall/alpha-challenge-2026
cd alpha-challenge-2026
cp .env.example .env          # public RPCs, no keys required
python3 alpha.py check        # prints 900/900
```

Every RPC used is free and public:

| Network | Endpoint |
|---|---|
| Ethereum | `https://rpc.mevblocker.io` |
| Solana | `https://api.mainnet-beta.solana.com` |
| X Layer | `https://rpc.xlayer.tech` |
| Robinhood Chain | `https://rpc-robinhood.blockmachine.io` |

### Reproducing the analysis, not just the answers

Passing the checker only proves an answer is right. These scripts re-derive the
underlying facts from live public data and fail loudly if anything drifts:

```bash
python3 repro/04_pool_history.py    # pulls the pool's full pre-snipe history
```

Sample output:

```
transactions in pool history before the first snipe: 15
  slot 314590039  2025-01-17 14:19:03 UTC  2GcsWNeWVyYfiNybz9HQmiWv...
  ...
  slot 314597017  2025-01-17 15:06:47 UTC  4q2uYTeYzJFVuJB9Nqgs54rJ...
first snipe: slot 314658584
OK: the pool's entire pre-snipe history is 15 launch-team transactions
```

No dependencies beyond the Python standard library, and no keys.

## Highlights

### 07 - Firepit: an optimisation, not a pass/fail check

The harness accepts any solution that satisfies the condition, so the question
worth answering is not "does it pass" but "how much can actually be collected".
That needs the full factory, not a working subset.

- enumerated all 4,981 pools
- read `protocolFees()` for every one of them through `Multicall3.aggregate3`,
  13 batched calls instead of tens of thousands of single `eth_call`s
- priced each pool in USD **from its own reserves**, so selection was driven by
  measured value rather than by a guess
- found the adapter deployment block by binary search over `eth_getCode`

Result: 62,000.65 USDT0 collected from 12 pools - a larger amount from fewer
pools, because the pools were chosen by value.

### 04 - First Blood: a proof instead of a narrative

Rather than paginating backwards through millions of signatures, this pulls the
complete signature history of the pool itself from the official free RPC.

The history before the snipe is exactly **15 transactions**, all from the launch
team. That makes the next third-party transaction the answer by definition, with
no candidate enumeration at all.

```
pool init      slot 314590039   2025-01-17 14:19:03 UTC
seeded         100M TRUMP by    2025-01-17 14:52 UTC
mint activity  from             2025-01-17 14:00:59 UTC
```

The Solscan tooltip reading `14:01:48` is already UTC and corresponds to slot
314587496; no timezone shift is needed to line it up with on-chain state.

### 08 - First Move: zero archive access

The `messagePasserStorageRoot` is reconstructed from the calldata of a
third-party `proveWithdrawalTransaction` on L1. **No `eth_getProof` was made at
all**, neither against a paid archive nor a demo key, and the result is
validated against five independent proposals.

## Integrity of the harness

In all five code challenges `setUp()` and `checkSolve()` are byte-identical to
upstream. `vm.deal`, `vm.etch` and `vm.prank` appear only inside the authors'
own `setUp` functions.

```bash
git remote add upstream https://github.com/WintermuteResearch/Alpha-Challenge-2026.git
git fetch upstream
git diff upstream/main -- challenges/*/Solution.t.sol | grep -E '^\+.*(vm\.deal|vm\.etch|vm\.prank)' || echo "none added"
```

## On tooling

I used an LLM while working on this, and it is worth being precise about where

It did the mechanical work: paginating through large transaction sets, cycling
through RPC endpoints until one actually served the block range I needed,
writing boilerplate around calls I had already specified, and reformatting
output. That is the part that is tedious rather than difficult.


## Challenge index

| # | Type | Points | One line |
|---|---|---|---|
| 00 | code | 25 | wrap 1 ETH into WETH on a mainnet fork |
| 01 | analysis | 25 | trace an Allbridge Classic unlock back to its Stacks origin |
| 02 | code | 100 | buy out an expired DutchX auction from 2020 |
| 03 | code | 100 | liquidate a $1B Liquity position during the 2021-05-19 crash |
| 04 | analysis | 100 | two signatures around the TRUMP launch on Solana |
| 05 | analysis | 100 | attribute four addresses |
| 06 | code | 150 | buy a token on a fresh L2 through the Delayed Inbox only |
| 07 | code | 150 | collect Uniswap protocol fees on X Layer and burn 2,000 UNI |
| 08 | analysis | 150 | correct counter-claim for two fault dispute games |
