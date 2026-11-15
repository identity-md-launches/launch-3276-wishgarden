# Ethereum dependency verification

Observed **2026-11-15 at 13:49 UTC**, using read-only mainnet calls through [Routescan's Ethereum proxy API](https://api.routescan.io/v2/network/mainnet/evm/1/etherscan/api?module=proxy&action=eth_getCode&address=0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7&tag=latest), [official IMD documentation](https://imd.fun/docs/), and Sourcify's verified source/runtime records. Raw call results, requests, verification identifiers and source links are in [ethereum-dependencies.json](evidence/ethereum-dependencies.json). These were independent `latest` calls, not a single pinned-block snapshot; rerun the checks before owner confirmation.

| Dependency | Verified runtime size | Keccak-256 |
| --- | ---: | --- |
| IMD `0xD34a99Bc0f67aE1bbd63C660e6d0b0dd03E263B7` | 22,990 bytes | `0x79a1ae149d27d4aae006d4dd75cb834222c9623799bbf34359428aaf66fec3bf` |
| identity.md `0x0000eC93127BAA929E58E97dd0095A2BFb38ec1D` | 5,231 bytes | `0x68d046e0bfb8185d9db0a9a7ed57420f22dfc38321c9c91453a001a47668c530` |

Both live `eth_getCode` results matched Sourcify's stored onchain runtime bytes exactly. Sourcify reports no proxy for either dependency. Fixture copies in `test/fixtures/` contain those deployed runtimes, not replacement production contracts.

## IMD price and burn conclusion

The official IMD documentation identifies the Ethereum token used by the approved brief. Live reads returned `name() = "Identity.md"`, `symbol() = "IMD"`, and `decimals() = 18`. The price therefore uses precisely `10^18` base units for one IMD. Names and symbols can be changed by the token's own administrator; the application uses its fixed address and checks decimals on each payment/withdrawal.

Verified contract: [`src/BridgedFP.sol:BridgedFP`](https://sourcify.dev/server/v2/contract/1/0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7?fields=all), Solidity 0.8.26, Sourcify match 27277375, exact runtime/creation match. Relevant implementations are its OFT parent and OpenZeppelin ERC20, included in that verification response.

Inspection found no public `burn(uint256)` or `burnFrom(address,uint256)` entrypoint. The token's OFT `_debit` performs an internal burn during a cross-chain `send`, paired with credit on a destination chain; that is not an application-level permanent supply burn. The ERC20 implementation rejects transfers to the zero address. Sending tokens to another address, including a sink, merely changes balances and leaves `totalSupply` unchanged.

Consequently this application uses a dedicated, verifiable, immutable sink contract for the fixed 30% allocation. It does not invent a dead-address recipient, invoke an unsupported burn selector, bridge tokens, introduce a replacement token, or take extra ETH for a bridge fee. The sink cannot call the token or release any asset. `WishGardenTreasury.recordPayment` verifies the exact amount delivered to the sink and unchanged token supply during that transfer. The burn allocation is nonwithdrawable and cannot become revenue.

This is a **permanent lock**, not a reduction of ERC20 supply or a claim about cross-chain supply. The frontend must distinguish `totalIMDLocked` from `totalSupplyBurned() == 0`, and must not subtract the lock from onchain `totalSupply` when presenting raw total supply. Circulating-supply and FDV methodology belong to the separate frontend/data work.

An attempted live `burn(0)` probe returned HTTP 500 from the explorer, so that response alone proves nothing. The conclusion instead rests on verified source, ABI/dispatcher absence, and `test_verifiedIMDRuntimeHas18DecimalsAndNoPublicBurn`, which executes the actual deployed runtime offline and proves that both burn selectors revert, zero-address transfer reverts, and sink transfers preserve supply.

## Official NFT and confirmation gate

The official IMD documentation's crosschain table names the Ethereum seat NFT address above. The [verified collection](https://sourcify.dev/server/v2/contract/1/0x0000ec93127baa929e58e97dd0095a2bfb38ec1d?fields=all) is `src/IdentityMD.sol:IdentityMD`, Solidity 0.8.26, Sourcify match 28853423. Sourcify reports a source/runtime match, rather than an exact metadata match; our pinned hash is of the actual deployed runtime, including its immutable renderer address, and matches the independently fetched live bytes.

Live reads returned `name() = "identity.md"`, `symbol() = "IDMD"`, total supply 2,000, ERC721 support `true`, and a nonzero `ownerOf(0)`. Its verified source restricts mint IDs to 0–1999 and uses ordinary ERC721 current-owner semantics. A renderer or metadata change cannot change garden records or consumed IDs.

The garden hardcodes **both the official address and actual deployed runtime hash**. `confirmOfficialCollection(bytes32)` accepts no alternative address. It additionally verifies ERC165/ERC721 support and requires a nonzero evidence hash and the explicit launch owner. The constructor leaves it unconfirmed; no contributor or service confirmation is implied. Every claim rechecks the code hash, then current ownership and lifetime consumption.

Offline fixtures deliberately have fresh local storage. Tests seed local token balances and mint/transfer test NFTs through the real runtime, without pretending these are mainnet transactions or using real holders' keys. They prove behavior of the verified code; the JSON evidence records the separate live reads. Tests never need RPC connectivity.
