# The Wish Garden — Ethereum contracts

Implemented contracts for permanent candles purchased with **existing IMD** on Ethereum chain 1. No token, pool, lottery, transferable candle NFT, yield, or financial rights are created. This source assignment supplies contracts, tests, ABIs, and deployment parameters. The separate manifest/review/deployment services produce the reviewed `launch.json`, deploy, publish confirmed addresses, and hand off to the frontend stage.

**Burn semantics:** Ethereum IMD has no public `burn` or `burnFrom`. The 30% burn allocation is transferred atomically into `WishGardenBurnSink`, an immutable contract with no withdrawal or execution capability. This permanently locks those tokens; **it does not reduce IMD `totalSupply`**. `totalIMDLocked` measures purchase allocations and `totalSupplyBurned()` returns zero. The interface must say “permanently locked IMD,” not “supply burned.” See [verification evidence](docs/verification.md).

## Build and verify offline

```sh
forge build
FOUNDRY_FUZZ_SEED=0x97c94f0a2c3e7194aefb08855d149d84c076632dfc983f4f1421acdc6c07edef forge test
forge fmt --check
python3 scripts/export-abis.py --check
```

Solidity is pinned to **0.8.26**, Cancun, optimizer 200 runs, `bytecode_hash = "none"`. OpenZeppelin 5.2.0 and forge-std 1.9.7 are ordinary vendored source files. The build and tests need no network, environment configuration, FFI, filesystem cheatcodes, submodules, or downloaded compiler binary in the repository. Foundry supplies the pinned compiler. After source changes, run `forge build` then `python3 scripts/export-abis.py` to regenerate the three application ABIs.

## Contracts and money flow

| Contract | Responsibility |
| --- | --- |
| `WishGarden` | Exact-price purchases, append-only candle records, purchaser pagination, lifetime NFT claims |
| `WishGardenTreasury` | Separate ecosystem, operations and founder balances; atomic allocations and withdrawals |
| `WishGardenBurnSink` | Permanent IMD lock; no owner, withdrawal, approval, proxy or arbitrary call |

IMD: `0xD34a99Bc0f67aE1bbd63C660e6d0b0dd03E263B7`, 18 decimals. Price is **1 IMD = 10^18 base units per candle**, identically for all seven styles. Ten candles cost 10 IMD. ETH pays transaction gas only; application functions are nonpayable.

| Allocation | Per candle, base units | Destination / control |
| --- | ---: | --- |
| Burn allocation / permanent lock | 300000000000000000 | `WishGardenBurnSink`; unrecoverable, supply unchanged |
| Ecosystem | 500000000000000000 | Treasury bucket; owner chooses destination on each withdrawal |
| Operations | 100000000000000000 | Separate bucket; only immutable operations recipient can claim to itself |
| Founder | 100000000000000000 | Separate bucket; only immutable founder recipient can claim to itself |

The garden pulls only from `msg.sender`, checks the exact payer debit and received amount, forwards the payment to its immutable treasury, and records all four allocations in the same transaction. Every transfer uses SafeERC20 and balance-delta checks. An insufficient allowance, failed transfer, changed burn sink, fee, or bad dependency reverts **all** payment, allowance spending, records, counters and events. There is no inter-contract token approval. Approve the garden for only the requested total.

The three revenue balances cannot borrow from each other or from the sink. Partial claims are supported. All withdrawals emit bucket, caller, destination and amount. Operations and founder recipients are both the approved owner at launch, but their permissions and ledgers stay distinct. Transferring treasury ownership does not change these immutable recipients.

Direct token donations do not create candles or enter purchase accounting. Treasury surplus is visible in `unallocatedBalance()` but cannot be withdrawn. IMD sent directly to the garden is also inaccessible; sink donations are permanently locked and appear in `lockedBalance()` but not `totalIMDLocked`. Do not send native ETH or other assets to these contracts: there is no rescue function.

## Persistent candles and claims

- IDs start at 1 and increase across both purchases and free claims. No expiration, transfer, sale, deletion, position mutation, or 10,000-candle supply cap exists.
- Each record preserves purchaser, timestamp, style, stable zero-based position, paid/free provenance and, for free claims, the NFT ID. Paid records use `freeClaim = false`; NFT ID 0 is valid for free claims.
- Styles `0..6`: Purity/white, Hope/blue, Love/red, Success/gold, Health/purple, Wealth/green, Happiness/pink. Cosmetics never change price or rights.
- One transaction accepts **1..50** paid candles of one style, or **1..50** eligible NFT IDs of one style. Larger orders use repeated bounded transactions. Pages contain at most **100** records/IDs. These are named constants, not lifetime caps.
- Position is permanently `candleId - 1`, independent of buyer, timestamp or later occupancy. A frontend can fix 256-slot sections with `section = position / 256`, `row = (position % 256) / 16`, `column = position % 16`; expand sections from the entrance without repositioning old candles. This rendering layout is an interpretation of the permanent slot, not mutable onchain state.
- `createdAt` supports an optional first-day glow in the renderer. Nothing expires after 24 hours. No server task, random seed, wish text, or private message is stored.

The only eligible collection is verified identity.md at **`0x0000eC93127BAA929E58E97dd0095A2BFb38ec1D`**. Its address and verified runtime hash are constants; the owner cannot substitute another collection. Confirmation is one-time and checks runtime identity and ERC165/ERC721 support. The collection's valid IDs are 0–1999. Every claim checks current `ownerOf`; approval or operator status alone is insufficient. Each ID is consumed for this garden forever, even after transfer. Multiple IDs held by one wallet may each claim. A bad/duplicate ID reverts the entire batch. Free claims touch no IMD and can succeed without token or treasury availability once NFT confirmation is complete.

Before owner confirmation, `freeClaimsStatus()` supplies a disabled reason and claim calls revert `CollectionNotConfirmed`. A runtime mismatch or wrong chain also fails closed. “Lifetime” is scoped to this deployed garden; no cross-application claim registry is implied.

## After launch

The approved owner is **`0x48E4E74fE1d0c14404cEB57B9fec5b21329C6ec9`**. No worker, factory or IMD service becomes the owner. Constructors do not call external contracts or require code at dependency addresses.

1. Read the service's confirmed deployment handoff and check all three deployed runtimes/constructor arguments against the independently reviewed source and manifest. Do not invent addresses. The owner calls `WishGardenTreasury.bindGarden(confirmedGardenAddress)` **once**. Obtain this address from the deployment receipt. The contract checks reciprocal treasury/token references, current matching ownership, and the burn sink's exact runtime. Paid purchases revert until bound.
2. Review [docs/evidence/ethereum-dependencies.json](docs/evidence/ethereum-dependencies.json), reconfirm the official collection and current code on chain 1, and call `WishGarden.confirmOfficialCollection(evidenceHash)` **once** from the owner. This delivered evidence file's Keccak-256 is `0x65ef8a042de0fb6fe40f2174fd7e4d13857f884c61912e56b20c38a122c8ee18`. If the reviewed evidence changes, compute and use its actual new hash. This transaction is the owner's confirmation; it has not been sent by the contributor. Claims remain disabled if confirmation is not appropriate or possible.
3. Check `treasury.garden()`, `garden.collectionConfirmed()`, `garden.freeClaimsStatus()`, owners, immutable recipients and the setup events. Owner and recipients retain ETH for gas. No further price, token, collection, split, signer, oracle, or schedule setting is needed.
4. Manage ecosystem custody using `withdrawEcosystem(destination, amount)`. The operations recipient uses `claimOperations(amount)` and the founder uses `claimFounder(amount)`, always paid to their fixed addresses. Keep withdrawal transaction links public. Both contracts support two-step owner transfer; renunciation is disabled. A future owner change requires separate transactions for each contract, and does not move founder/operations entitlements.

Setup may be performed in either order after verification; purchases and free claims have independent gates. Bind the garden before transferring either ownership to avoid mismatched owners during setup. Only the launch owner authorizes these post-deployment actions; services are not expected to initialize the applications.

## Operational responsibilities and limits

The owner manually controls ecosystem withdrawals. Investments made after withdrawal are outside these contracts, can lose value, and confer **no financial claim** on candle holders. The contracts do not invest, track offchain holdings, promise returns, or provide market-cap/FDV data. External IMD bridge/metadata administration and the official NFT remain dependencies of their respective issuers.

There is no pause, upgrade or arbitrary-call mechanism. Losing a required key before setup can leave the corresponding flow disabled. A permanently pinned collection cannot be migrated inside this deployment. Runtime evidence, adversarial tests and the author's security review are not an independent audit. The required independent contributor review and service deployment are subsequent stage responsibilities; no application address, transaction, public website or independent approval is claimed here.

See [deployment parameters](docs/deployment.md), [ABI and integration guide](docs/abi/README.md), and [validation/security notes](docs/validation.md).
