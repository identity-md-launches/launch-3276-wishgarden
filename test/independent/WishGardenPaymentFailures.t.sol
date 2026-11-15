// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {GardenTestBase} from "../helpers/GardenTestBase.sol";
import {AdversarialIMD} from "../helpers/AdversarialIMD.sol";
import {GardenEconomy} from "src/GardenEconomy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Deliberately substituted ERC20 faults, not behavior attributed to deployed IMD.
/// @dev Exercise every transfer leg after existing revenue and donations, not just an empty ledger.
contract IndependentWishGardenPaymentFailuresTest is GardenTestBase {
    AdversarialIMD private faulty;

    function setUp() public override {
        super.setUp();
        AdversarialIMD implementation = new AdversarialIMD();
        vm.etch(IMD, address(implementation).code);
        faulty = AdversarialIMD(IMD);
        faulty.mint(alice, 10_000e18);
        _buy(alice, 10, 3);
        // Existing excess must not conceal a short transfer, surcharge or a no-op transfer.
        faulty.mint(address(garden), 7e18);
        faulty.mint(address(treasury), 11e18);
        faulty.mint(address(sink), 13e18);
        faulty.mint(bob, 5e18);
        faulty.mint(operations, 5e18);
        faulty.mint(founder, 5e18);
    }

    function testFuzz_failureAtEveryPaymentLegIsAtomicAndRetryable(
        uint8 legSeed,
        uint8 modeSeed,
        uint8 quantitySeed
    ) public {
        uint8 leg = legSeed % 3;
        uint8 mode = modeSeed % 4 + 1; // false return, recipient tax, no movement, sender surcharge
        uint256 quantity = uint256(quantitySeed) % 50 + 1;
        if (leg == 0) faulty.configureModes(mode, 0, address(0));
        else faulty.configureModes(0, mode, leg == 1 ? address(treasury) : address(sink));

        vm.prank(alice);
        token.approve(address(garden), quantity * 1e18);
        bytes32 beforeState = _stateDigest();
        vm.prank(alice);
        vm.expectRevert(_failure(mode));
        garden.buyCandles(quantity, 6);
        assertEq(_stateDigest(), beforeState, "failed payment changed balances, allowance or records");

        faulty.configureModes(0, 0, address(0));
        vm.prank(alice);
        assertEq(garden.buyCandles(quantity, 6), 11, "failed purchase must not reserve IDs");
        assertEq(token.allowance(alice, address(garden)), 0);
        _assertWithDonations(10 + quantity);
    }

    function testFuzz_failureInEveryWithdrawalBucketPreservesEntitlement(
        uint8 bucketSeed,
        uint8 modeSeed,
        uint96 amountSeed
    ) public {
        uint8 bucket = bucketSeed % 3;
        uint8 mode = modeSeed % 4 + 1;
        uint256 available = bucket == 0 ? 5e18 : 1e18;
        uint256 amount = uint256(amountSeed) % available + 1;
        address recipient = bucket == 0 ? bob : bucket == 1 ? operations : founder;
        address caller = bucket == 0 ? OWNER : recipient;
        faulty.configureModes(0, mode, recipient);
        bytes32 beforeState = _stateDigest();

        vm.prank(caller);
        vm.expectRevert(_failure(mode));
        _withdraw(bucket, amount);
        assertEq(_stateDigest(), beforeState, "failed withdrawal changed entitlement or custody");

        faulty.configureModes(0, 0, address(0));
        vm.prank(caller);
        _withdraw(bucket, amount);
        assertEq(token.balanceOf(recipient), 5e18 + amount);
        assertEq(treasury.totalEcosystemWithdrawn(), bucket == 0 ? amount : 0);
        assertEq(treasury.totalOperationsClaimed(), bucket == 1 ? amount : 0);
        assertEq(treasury.totalFounderClaimed(), bucket == 2 ? amount : 0);
        _assertWithDonations(10);
    }

    function test_noReturnWithdrawalsStillPayExactAmountsFromAllBuckets() public {
        faulty.configureModes(5, 5, address(0));
        vm.prank(OWNER);
        treasury.withdrawEcosystem(bob, 5e18);
        vm.prank(operations);
        treasury.claimOperations(1e18);
        vm.prank(founder);
        treasury.claimFounder(1e18);
        assertEq(token.balanceOf(bob), 10e18);
        assertEq(token.balanceOf(operations), 6e18);
        assertEq(token.balanceOf(founder), 6e18);
        assertEq(treasury.accountedBalance(), 0);
        _assertWithDonations(10);
    }

    function _withdraw(uint8 bucket, uint256 amount) private {
        if (bucket == 0) treasury.withdrawEcosystem(bob, amount);
        else if (bucket == 1) treasury.claimOperations(amount);
        else treasury.claimFounder(amount);
    }

    function _failure(uint8 mode) private pure returns (bytes memory) {
        return mode == 1
            ? abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, IMD)
            : abi.encodeWithSelector(GardenEconomy.InexactTransfer.selector);
    }

    function _assertWithDonations(uint256 paid) private view {
        assertEq(garden.paidCandles(), paid);
        assertEq(garden.totalCandles(), paid);
        assertEq(garden.candleCountOf(alice), paid);
        assertEq(treasury.totalPayments(), paid * 1e18);
        assertEq(treasury.totalIMDLocked(), paid * 0.3e18);
        assertEq(sink.lockedBalance(), paid * 0.3e18 + 13e18);
        assertEq(token.balanceOf(address(garden)), 7e18);
        assertEq(treasury.unallocatedBalance(), 11e18);
        assertEq(token.balanceOf(address(treasury)), treasury.accountedBalance() + 11e18);
        assertEq(treasury.ecosystemBalance() + treasury.totalEcosystemWithdrawn(), paid * 0.5e18);
        assertEq(treasury.operationsBalance() + treasury.totalOperationsClaimed(), paid * 0.1e18);
        assertEq(treasury.founderBalance() + treasury.totalFounderClaimed(), paid * 0.1e18);
    }

    function _stateDigest() private view returns (bytes32) {
        bytes32 balances = keccak256(
            abi.encode(
                token.totalSupply(),
                token.balanceOf(alice),
                token.balanceOf(bob),
                token.balanceOf(operations),
                token.balanceOf(founder),
                token.balanceOf(address(garden)),
                token.balanceOf(address(treasury)),
                token.balanceOf(address(sink)),
                token.allowance(alice, address(garden))
            )
        );
        bytes32 ledger = keccak256(
            abi.encode(
                treasury.totalPayments(),
                treasury.totalIMDLocked(),
                treasury.ecosystemBalance(),
                treasury.operationsBalance(),
                treasury.founderBalance(),
                treasury.totalEcosystemWithdrawn(),
                treasury.totalOperationsClaimed(),
                treasury.totalFounderClaimed()
            )
        );
        (uint256[] memory ids,) = garden.candleIdsOf(alice, 0, 100);
        return keccak256(
            abi.encode(
                balances,
                ledger,
                garden.totalCandles(),
                garden.paidCandles(),
                garden.freeCandles(),
                ids,
                garden.getCandle(1),
                garden.getCandle(10)
            )
        );
    }
}
