# Wintermute Alpha Challenge 2026

All nine challenges solved, 900/900. This repository is less about the answers,
which are the same for everyone who finishes, and more about the method: every
result here is reproducible from a clean machine, and no step needs a paid or
keyed endpoint.

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

## Highlights

### 07 — Firepit: an optimisation, not a pass/fail check

The harness accepts any solution that satisfies the condition, so the question
worth answering is not "does it pass" but "how much can actually be collected".
That needs the full factory, not a working subset.

- enumerated **all 4,981 pools** of the factory
- read `protocolFees()` for every one of them through `Multicall3.aggregate3`,
  **13 batched calls** instead of tens of thousands of single `eth_call`s
- priced each pool in USD **from its own reserves**, so selection was driven by
  measured value rather than by a guess
- found the adapter deployment block by binary search over `eth_getCode`

Result: **62,000.65 USDT0 collected from 12 pools** — a larger amount from fewer
pools, because the pools were chosen by value.

### 04 — First Blood: a proof instead of a narrative

Rather than paginating backwards through millions of signatures, this pulls the
**complete signature history of the pool itself** from the official free RPC.

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

### 08 — First Move: zero archive access

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

I used an LLM while working on this, and it is worth being precise about where.

It did the mechanical work: paginating through large transaction sets, cycling
through RPC endpoints until one actually served the block range I needed,
writing boilerplate around calls I had already specified, and reformatting
output. That is the part that is tedious rather than difficult.

The decisions that produced the results above were made by hand. Choosing to
pull the pool's own signature history instead of enumerating candidates in 04.
Deciding that the factory had to be enumerated in full rather than worked from a
subset in 07, which is the entire reason the collected amount differs. Refusing
to look at existing write-ups before finishing. Requiring a derivation rather
than a hash match, so that a right answer for a wrong reason would not pass.
Reading the numbers afterwards and rejecting the ones that did not hold up.

The distinction matters here because these challenges are not gated on writing
code. A published external evaluation ran this same challenge set against eleven
frontier and open-source models: the strongest closed 53% in two hours and 200
tool calls, and every model failed the analytical challenges — including 04,
where one burned 198 calls and roughly $9 brute-forcing 200,000 mint
transactions. The models do not get stuck on syntax, they get stuck on choosing
a direction. That choice is the work.

Worth noting that the organisers invite this explicitly. The challenge README
states `Rules. There are none worth enforcing`, and the announcement thread
suggests you `improve your LLM setup to one-shot similar cases`.

## Limitations

Stated because they are real, not because they are small.

- In 08 the safe head is derived by bracketing the window between proposals and
  filtering candidates through a sha256 oracle. Deriving it exactly from batch
  data is the stronger method and this repository does not do that.
- The calldata reconstruction in 08 is not a novel technique; it was published
  independently before this run.
- In 01 the sender address was derived manually via `c32check` before finding
  that a single Hiro API call returns it directly. The extra step was not needed.

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
