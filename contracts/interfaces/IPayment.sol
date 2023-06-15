// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPayment {
    function safeSendETH(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function safeSendToken(
        address contractAddress,
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
