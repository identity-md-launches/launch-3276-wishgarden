// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev Used only for the owner's one-time treasury binding after factory deployment.
interface IWishGarden {
    function treasury() external view returns (address);
    function owner() external view returns (address);
    function IMD() external view returns (address);
}
