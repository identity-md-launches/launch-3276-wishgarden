# Deployment handoff

This is a source-producing assignment. [manifest-handoff.json](deployment/manifest-handoff.json) is complete constructor input for the **separate generated manifest assignment**, which writes the repository-root `launch.json` after source acceptance. The independent reviewer must inspect the final source and manifest together. This source deliverable intentionally does not preempt that root file or claim independent review. Policy and signed artifact linkage are supplied by the services, not fabricated in this handoff.

Launch chain: **Ethereum, chain ID 1**. Owner: **`0x48E4E74fE1d0c14404cEB57B9fec5b21329C6ec9`**. Deployment sends **zero ETH** and deploys only these three application contracts, in this order:

| Order / contract | Constructor arguments, declaration order |
| --- | --- |
| 1. `WishGardenBurnSink` | None |
| 2. `WishGardenTreasury` | `owner_ = $owner`; `burnSink_ = $contract:WishGardenBurnSink`; `operationsRecipient_ = $owner`; `founderRecipient_ = 0x48E4E74fE1d0c14404cEB57B9fec5b21329C6ec9` |
| 3. `WishGarden` | `owner_ = $owner`; `treasury_ = $contract:WishGardenTreasury` |

All constructor arguments are static addresses, with backward-only contract references. The burn sink has no owner. The other contracts initialize ownership from the explicit argument, never `msg.sender` or `tx.origin`. No external library link, proxy, delegatecall, constructor dependency call, hidden contract creation, payable constructor, or external initialization by the factory is needed.

The deployment checker can instantiate these on an empty chain. Dependency presence and correctness are checked on configuration/use; the paid path requires Ethereum IMD and the correctly bound treasury/sink. NFT claims require a separately confirmed official collection. `DeploymentAndDependencies.t.sol` rehearses construction by a factory in one transaction with no token or NFT code and checks ownership, dependency links, EIP-170 size, and the protected floor's forbidden-opcode constraints.

## Owner setup transactions

Use confirmed addresses from the service's deployment receipt, with the approved owner as caller. These transaction descriptions are not broadcasts:

| Target | Function | Parameter source |
| --- | --- | --- |
| Confirmed `WishGardenTreasury` | `bindGarden(address)` | Confirmed `WishGarden` deployment address, after checking its treasury, token, owner and runtime |
| Confirmed `WishGarden` | `confirmOfficialCollection(bytes32)` | Keccak-256 of owner-reviewed verification evidence; delivered file digest is `0x65ef8a042de0fb6fe40f2174fd7e4d13857f884c61912e56b20c38a122c8ee18` |

No replacement collection address is configurable. If current official-address verification fails or the owner does not confirm, leave claims disabled and display `freeClaimsStatus()`'s reason. There is no success fallback. If a bound address or confirmation is wrong, this immutable deployment cannot be patched; verify first.

After setup, check the `GardenBound` and `OfficialCollectionConfirmed` events and corresponding storage. The owner then controls ecosystem withdrawals; the immutable operations/founder recipient roles control their own claims. Two-step ownership transfer changes only ownership, not those recipients. These responsibilities and manual custody risks are listed in README's “After launch” section.

## Required service completion

Independent adversarial review, source publication, attestation, admission, production simulation, factory deployment, explorer verification, and confirmed application addresses remain service/stage work. No worker wallet, signing key, attestation, hosted site, or transaction hash is required to build or test this source contribution. The frontend must consume the confirmed handoff and ABI exports, not this document as evidence that deployment occurred.
