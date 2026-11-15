# Validation and author security review

This is implementation validation by the contributor, **not** the independent adversarial review required before release. The separate reviewer must assess the accepted source and final `launch.json` together, especially owner/recipient arguments, dependency evidence and permanent-lock disclosures. No production transaction was sent.

## Local results

Solidity 0.8.26, Foundry 1.8.5. The exact requested fuzz seed was used: `0x97c94f0a2c3e7194aefb08855d149d84c076632dfc983f4f1421acdc6c07edef`.

- 61 Foundry tests passed (including the grouped stateful invariant suite); zero failures/skips. Three parameterized fuzz tests ran 512 inputs each.
- The invariant group checked two invariants over 128 sequences, depth 64: 8,192 handler calls, zero unexpected reverts. Actions mix purchases, free claims, NFT transfers, partial withdrawals, and donations.
- Measured maximum-batch call gas: 50 paid candles approximately **4,015,685**; 50 free claims approximately **6,167,827**. Both tested below 8 million. These are local in-transaction measurements with setup warming some state, not mainnet fee quotes or transaction gas limits. Estimate each production call with margin. The 10,001-record test uses many separate bounded calls; it is not one supported purchase transaction.
- `forge build --sizes`, `forge fmt --check`, and `python3 scripts/export-abis.py --check` passed. A final `forge test --offline` run with the same requested seed also passed all 61 tests. Tests use no environment variables or filesystem permissions.

Application runtime / initcode sizes from the pinned compiler:

| Contract | Runtime bytes | Initcode bytes |
| --- | ---: | ---: |
| `WishGardenBurnSink` | 324 | 352 |
| `WishGardenTreasury` | 6,508 | 7,162 |
| `WishGarden` | 7,854 | 8,288 |

All application runtimes are below 24,576 bytes, initcode is below 49,152 bytes, and link-reference maps are empty. The manifest handoff's argument counts/types were checked against built constructor ABIs.

## Coverage

| Area | Success and failure evidence |
| --- | --- |
| Economy | 1/10/50 purchases, seven styles, exact decimal math, exact allowance consumption, fuzzed quantity/split conservation |
| Atomicity | Insufficient allowance/balance, false-return/no-op/taxed ERC20, sender surcharge, treasury forwarding failure, final sink transfer failure; all records and ledgers roll back |
| Persistence | 10,001 actual records, unchanged old record after ten years/later purchases, contiguous stable slots, purchaser/global pagination, paid/free interleaving |
| NFT | Actual verified runtime fixture; owner-only one-time confirmation; missing/wrong code; ERC165 checks; NFT 0; current ownership; operators rejected; transfer before/after consumption; duplicate/invalid atomic batches; 50-claim boundary |
| Treasury | Distinct bucket permissions, partial withdrawals, overdraws, invalid destinations, failed-transfer rollback, immutable recipients across owner transfer, nonwithdrawable burn allocation, donation separation |
| Reentrancy | Reentrant paid purchase, cross-function free claim, authorized owner's nested treasury withdrawal rejected by guard; outer call settles once |
| Launch | Constructors on an empty chain in one factory call, explicit ownership, static dependencies, zero-address errors, EIP-170 sizes, no reachable delegatecall/callcode/selfdestruct |
| IMD semantics | Live verified bytecode fixture reports 18 decimals, rejects public burn/burnFrom and zero-address transfer, preserves supply when locking the allocation |
| Stateful conservation | No supply change; every IMD accounted across buyers/recipients/garden/treasury/sink; exact four allocations; balances remain solvent; donations distinct; claims cannot reset on transfers |

## Reviewed constraints and trust boundaries

Application contracts have no callable token mint, upgrade, destruction, arbitrary execution, signature approval, oracle, randomness, staking, automated investment, or external library-link path. Token pulls always use `msg.sender`. All quantities/pages are bounded; persistent supply itself is not capped. Checked integer arithmetic and a safe timestamp cast avoid truncation. NonReentrant guards cover payment, claim, configuration and withdrawal operations involving external calls. Effects and records revert atomically on any interaction failure.

The owner can bind the treasury's garden only once. Reciprocal references and matching owners are checked, but **choosing the actual reviewed garden address is an owner responsibility**: a malicious same-owner contract could imitate those getters. The service handoff and independent review establish the intended source. Neither binding nor constructors are a general contract-authenticity oracle. The sink, in contrast, is checked against the exact compiled sink runtime, and the NFT address/runtime are both pinned.

The IMD address is fixed and its live implementation was verified as nonproxy. Payment/withdrawal calls check availability/decimals and exact transfer effects; they do not pin the token's code hash. The existing token's bridge configuration and metadata administrator remain external trust assumptions. A hypothetical token with dishonest `balanceOf` or arbitrary supply changes is outside this verified dependency model. Fault-injection tests deliberately replace code at that fixed address locally to test rejection/guard behavior; no production setter permits such replacement.

The immutable sink permanently removes the allocation from spendable application custody. It offers no recovery even for mistaken transfers. Revenue and unsolicited assets are also constrained as documented. The owner controls ecosystem destination choices and can lose value through manual investment after withdrawal. There is no pause to stop users after setup and no upgrade to repair a defect; independent review is particularly important for irreversible configuration.

Foundry's build linter may flag exact balance comparisons, external calls in bounded claim loops, and external-call/event order. Exact comparisons deliberately enforce the specified exact-price/non-taxed IMD economy; the loops are bounded to 50 and revert atomically; payment methods are guarded and emit only committed logs on successful transactions. Reentrancy fault-injection tests cover the guarded paths. Slither/Mythril were not run; no independent tool audit or security approval is claimed.
