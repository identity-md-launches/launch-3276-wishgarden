# Third-party provenance

- **OpenZeppelin Contracts v5.2.0**, MIT, vendored under `lib/openzeppelin-contracts/contracts/`. Archive origin, version and SHA-256 are recorded in `lib/openzeppelin-contracts/VENDORED.md`; license in `lib/openzeppelin-contracts/LICENSE`. The application imports Ownable/Ownable2Step, ReentrancyGuard, SafeERC20, SafeCast, and standard interfaces. No package install or network access is needed to compile.
- **forge-std v1.9.7**, MIT/Apache-2.0, vendored under `lib/forge-std/src/` with both license files and archive provenance. Used only for tests.
- **Ethereum runtime fixtures**, retrieved from Sourcify and compared to live code through Routescan. They are the existing deployed IMD and identity.md bytecode, included only as verification/test data with fresh local state. Their provenance and upstream contract/license declarations are separate from the original application MIT license; the token's verified source declares `UNLICENSED` and the NFT source declares MIT. No upstream unlicensed Solidity implementation is copied into the application.

The supplied security reference informed review of failure modes but is not a dependency. No copied art, website, key, account configuration, new launch token or external service credential is part of this contribution.
