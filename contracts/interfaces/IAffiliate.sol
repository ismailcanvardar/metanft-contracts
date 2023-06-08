// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAffiliate {
    function getAffiliateAddress(
        address invited
    ) external view returns (address);

    function getAffiliateFees()
        external
        view
        returns (uint8 invitorFeePercentage, uint8 invitedFeePercentage);

    function registerAffiliate(
        address invitor,
        address invited
    ) external returns (bool);

    function calculateAffiliateFees(
        uint256 exchangeFeeAmount
    )
        external
        view
        returns (uint256 invitorFeeAmount, uint256 invitedFeeAmount);
}
