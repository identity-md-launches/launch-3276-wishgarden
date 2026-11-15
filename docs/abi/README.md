# ABI and integration guide

The application ABIs are [WishGarden.json](WishGarden.json), [WishGardenTreasury.json](WishGardenTreasury.json), and [WishGardenBurnSink.json](WishGardenBurnSink.json). They include constructors, custom errors, functions, and events. Regenerate with `forge build && python3 scripts/export-abis.py`; verify with `python3 scripts/export-abis.py --check`. All amounts below are raw IMD base units (18 decimals).

## Paid purchase

1. Confirm Ethereum chain 1 and service-confirmed addresses; check `treasury.garden() == garden`.
2. Select quantity `1..50` and style `0..6`. Compute `quantity * CANDLE_PRICE()` using integers. Ten is exactly `10000000000000000000` base units. Larger orders are separate transactions, and may partially complete across transactions.
3. Read ERC20 `allowance(wallet, garden)` and approve exactly the requested total when needed. There is no permit, relayer, gift recipient or arbitrary payer argument. The wallet invoking the purchase owns the records.
4. Simulate `buyCandles(quantity, style)` from that wallet with zero ETH, estimate gas, and submit. Wallet rejection makes no state change. Pending transactions are not candles. A reverted transaction creates no records and consumes no IMD (gas is still spent).
5. After a successful receipt, index `CandleCreated` and `CandlesPurchased`. Obtain IDs from logs; return values from write calls are generally unavailable to ordinary wallet clients. Deduplicate by `(chainId, transactionHash, logIndex)`, and store candle IDs uniquely. A repeated **new** paid transaction intentionally buys more candles; the contract has no client idempotency nonce.

## Free claims

Read `freeClaimsStatus()` first. If disabled, show its exact reason. Read the official collection's `ownerOf(tokenId)` and the garden's `nftClaimedCandle(tokenId)`. A zero claim mapping means unused; a nonzero value is the previous candle ID. Check both again by simulating because the NFT may transfer before mining.

Call `claimFreeCandle(tokenId, style)` or `claimFreeCandles(tokenIds, style)` with zero ETH. No IMD approval, fee, or burn is involved. NFT token ID zero is eligible. Only the current NFT owner can call; neither an approved operator nor a previous owner can claim. The whole batch reverts on duplicates, a previously consumed ID, or an ownership failure. Check `FreeCandleClaimed` and `CandleCreated` only in confirmed receipts.

## Records, pagination and stable rendering

`getCandle(id)` returns `(purchaser, createdAt, style, freeClaim, position, nftTokenId)` in that order. `createdAt` is a Unix timestamp in seconds. `position` is the stable zero-based slot; ID is always `position + 1`. Paid `nftTokenId = 0` is distinguished from a free claim on NFT 0 by `freeClaim`. Style values are listed in README.

`getCandles(firstId, limit)` returns records and `nextId`. Begin at 1. `candleIdsOf(purchaser, offset, limit)` returns IDs and `nextOffset`; begin at 0. Both limit page size to 100. A cursor exactly after the last record returns an empty page; a cursor beyond that reverts. Read related pages at a common block tag for a consistent snapshot, then catch up with events. `candleCountOf`, `totalCandles`, `paidCandles`, and `freeCandles` support progress indicators. Cursor-based pages and purchaser indices work without a connected wallet or an indexer.

Pan/zoom, sections, lighting, newborn glow, culling and fixtures belong to the frontend. Render flames only for confirmed records. Event reconciliation should handle chain reorganizations by removing orphaned logs and rereading state; RPC failures are unavailable data, not empty gardens or successful transactions. Private wish text must never be encoded into contract calls or public metadata.

## Treasury

Display each of `ecosystemBalance`, `operationsBalance`, `founderBalance`, and its corresponding cumulative withdrawal/claim counter. `totalPayments` is gross paid IMD; `totalIMDLocked` is the 30% purchase allocation. `totalSupplyBurned()` is **zero**. `burnSink.lockedBalance()` also includes direct donations. Show these different measurements with their correct labels. The treasury's raw ERC20 balance can exceed `accountedBalance()` because unsolicited deposits are not candle revenue; `unallocatedBalance()` reports the excess.

The owner calls `withdrawEcosystem(destination, amount)`. Only `operationsRecipient` can call `claimOperations(amount)`; only `founderRecipient` can call `claimFounder(amount)`. Claims cannot select another destination. Partial claims are allowed. Investments and custody after a withdrawal are manual, outside onchain accounting, and must not be presented as audited holdings, yields or visitor entitlements.

| Event | Indexing / meaning |
| --- | --- |
| `CandleCreated` | Indexed ID/purchaser; complete permanent record data |
| `CandlesPurchased` | Indexed purchaser/first ID; quantity, style, exact total |
| `FreeCandleClaimed` | Indexed purchaser/NFT ID/candle ID; official collection |
| `PaymentAllocated` | Indexed purchaser/first ID; exact four allocations and quantity |
| `BurnAllocationLocked` | Indexed sink; newly locked amount and cumulative purchase lock, **not a supply reduction** |
| `BucketWithdrawn` | Indexed bucket/caller/destination; amount; buckets 0 ecosystem, 1 operations, 2 founder |
| `GardenBound` | One-time treasury setup |
| `OfficialCollectionConfirmed` | Owner, collection, verified code hash and evidence hash |
| `OwnershipTransferStarted`, `OwnershipTransferred` | Two-step owner administration |

Decode custom errors using the relevant ABI. `CollectionNotConfirmed`, `CollectionVerificationFailed`, `TreasuryNotConfigured`, `WrongChain`, `NotNFTOwner`, `NFTAlreadyClaimed`, `InvalidQuantity`, `InvalidStyle`, insufficient ERC20 allowance/balance and unauthorized withdrawals are actual failures. Do not turn them into fake successful candles.
