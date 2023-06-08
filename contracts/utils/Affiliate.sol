// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Affiliate is Ownable2Step {
    uint8 public invitorFeePercentage;
    uint8 public invitedFeePercentage;
    uint8 public constant BASE_DIVIDER = 100;
    mapping(address => address) private affiliates;

    event SetAffiliateFeePercentage(uint8 newInvitorFee, uint8 newInvitedFee);
    event RegisterAffiliate(address invitor, address invited);

    constructor() {
        _transferOwnership(_msgSender());

        invitorFeePercentage = 20;
        invitedFeePercentage = 10;
    }

    function setAffiliateFeePercentages(
        uint8 newInvitorFeePercentage,
        uint8 newInvitedFeePercentage
    ) external onlyOwner returns (bool) {
        invitorFeePercentage = newInvitorFeePercentage;
        invitedFeePercentage = newInvitedFeePercentage;

        emit SetAffiliateFeePercentage(
            newInvitorFeePercentage,
            newInvitedFeePercentage
        );

        return true;
    }

    function registerAffiliate(
        address invitor,
        address invited
    ) external returns (bool) {
        require(
            invited == _msgSender(),
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
            (exchangeFeeAmount * invitorFeePercentage) / BASE_DIVIDER,
            (exchangeFeeAmount * invitedFeePercentage) / BASE_DIVIDER
        );
    }

    function getAffiliateAddress(
        address invited
    ) public view returns (address) {
        return affiliates[invited];
    }
}
