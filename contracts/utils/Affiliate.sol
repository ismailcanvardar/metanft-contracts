// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Affiliate is Ownable {
    // 20% invitor user percentage - 10% invited user percentage
    uint8 private _AFFILIATE_INVITOR_FEE_PERCENTAGE = 20;
    uint8 private _AFFILIATE_INVITED_FEE_PERCENTAGE = 10;
    uint8 private constant _BASE_DIVIDER = 100;
    mapping(address => address) private affiliates;

    event SetAffiliateFeePercentage(uint8 newInvitorFee, uint8 newInvitedFee);
    event RegisterAffiliate(address invitor, address invited);

    function getAffiliateAddress(
        address invited
    ) external view returns (address) {
        return affiliates[invited];
    }

    function getAffiliateFees()
        external
        view
        returns (uint8 invitorFeePercentage, uint8 invitedFeePercentage)
    {
        return (
            _AFFILIATE_INVITOR_FEE_PERCENTAGE,
            _AFFILIATE_INVITED_FEE_PERCENTAGE
        );
    }

    function setAffiliateFeePercentages(
        uint8 newInvitorFee,
        uint8 newInvitedFee
    ) external onlyOwner returns (bool) {
        _AFFILIATE_INVITOR_FEE_PERCENTAGE = newInvitorFee;
        _AFFILIATE_INVITED_FEE_PERCENTAGE = newInvitedFee;

        emit SetAffiliateFeePercentage(newInvitorFee, newInvitedFee);

        return true;
    }

    function registerAffiliate(
        address invitor,
        address invited
    ) external returns (bool) {
        require(
            invited == msg.sender,
            "registerAffiliate: Must register with your own address."
        );

        address affiliate = affiliates[invited];

        if (affiliate == address(0)) {
            affiliate = invitor;

            emit RegisterAffiliate(invitor, invited);

            return true;
        }

        return false;
    }

    function calculateAffiliateFees(
        uint256 exchangeFeeAmount
    )
        external
        view
        returns (uint256 invitorFeeAmount, uint256 invitedFeeAmount)
    {
        return (
            (exchangeFeeAmount * _AFFILIATE_INVITOR_FEE_PERCENTAGE) /
                _BASE_DIVIDER,
            (exchangeFeeAmount * _AFFILIATE_INVITED_FEE_PERCENTAGE) /
                _BASE_DIVIDER
        );
    }
}
