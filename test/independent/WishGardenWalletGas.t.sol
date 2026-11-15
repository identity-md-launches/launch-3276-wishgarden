// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {GardenTestBase} from "../helpers/GardenTestBase.sol";
import {WalletGas} from "../helpers/WalletGas.sol";

/// @notice Offline runtime fixtures, locally minted NFTs and funded wallets; no live-chain claim.
/// @dev Both claim entrypoints reach the ownerOf try/catch. Use the supplied unmodified gas search.
contract IndependentWishGardenWalletGasTest is GardenTestBase, WalletGas {
    function setUp() public override {
        super.setUp();
        _confirmCollection();
        for (uint256 id; id < 50; ++id) {
            _mintNFT(alice, id);
        }
    }

    function test_singleClaimAtWalletGasIncludingTokenZero() public {
        assertSameAtWalletGas(alice, address(garden), abi.encodeCall(garden.claimFreeCandle, (0, 6)));
        assertEq(garden.nftClaimedCandle(0), 0, "helper must restore the unconsumed ID");
        assertEq(garden.totalCandles(), 0);
        vm.prank(alice);
        assertEq(garden.claimFreeCandle(0, 6), 1);
    }

    function test_currentOwnerSingleClaimAtWalletGasAfterTransferAndPaidRecords() public {
        _buy(bob, 10, 2);
        vm.prank(alice);
        nft.transferFrom(alice, bob, 49);
        assertSameAtWalletGas(bob, address(garden), abi.encodeCall(garden.claimFreeCandle, (49, 0)));
        vm.prank(bob);
        assertEq(garden.claimFreeCandle(49, 0), 11);
        _assertAccounting(10);
    }

    function test_oneElementClaimBatchAtWalletGas() public {
        _checkBatch(1);
    }

    function test_tenElementClaimBatchAtWalletGas() public {
        _checkBatch(10);
    }

    function test_maximumClaimBatchAtWalletGas() public {
        _checkBatch(50);
    }

    function test_maximumClaimBatchAtWalletGasWithExistingHistory() public {
        _buy(alice, 1, 0);
        _checkBatch(50);
        _assertAccounting(1);
    }

    function test_maximumPaidBatchAtWalletGas() public {
        vm.prank(alice);
        token.approve(address(garden), 50e18);
        assertSameAtWalletGas(alice, address(garden), abi.encodeCall(garden.buyCandles, (50, 6)));
        assertEq(token.allowance(alice, address(garden)), 50e18);
        assertEq(garden.totalCandles(), 0);
    }

    function test_allThreeBucketWithdrawalsAtWalletGas() public {
        _buy(alice, 10, 0);
        assertSameAtWalletGas(
            OWNER, address(treasury), abi.encodeCall(treasury.withdrawEcosystem, (bob, 5e18))
        );
        assertSameAtWalletGas(operations, address(treasury), abi.encodeCall(treasury.claimOperations, (1e18)));
        assertSameAtWalletGas(founder, address(treasury), abi.encodeCall(treasury.claimFounder, (1e18)));
        _assertAccounting(10);
    }

    function _checkBatch(uint256 count) private {
        uint256[] memory ids = new uint256[](count);
        // Descending order also exercises valid, unsorted batches ending in token ID zero.
        for (uint256 i; i < count; ++i) {
            ids[i] = count - 1 - i;
        }
        uint256 beforeCount = garden.totalCandles();
        assertSameAtWalletGas(alice, address(garden), abi.encodeCall(garden.claimFreeCandles, (ids, 4)));
        assertEq(garden.totalCandles(), beforeCount);
        for (uint256 i; i < count; ++i) {
            assertEq(garden.nftClaimedCandle(ids[i]), 0);
        }
        vm.prank(alice);
        assertEq(garden.claimFreeCandles(ids, 4), beforeCount + 1);
        assertEq(garden.totalCandles(), beforeCount + count);
    }
}
