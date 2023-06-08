// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Affiliate
 * @dev A contract for managing affiliate relationships and fees.
 */
contract Affiliate is Ownable2Step {
    uint8 public invitorFeePercentage;
    uint8 public invitedFeePercentage;
    uint8 public constant BASE_DIVIDER = 100;
    mapping(address => address) private affiliates;

    event SetAffiliateFeePercentage(uint8 newInvitorFee, uint8 newInvitedFee);
    event RegisterAffiliate(address invitor, address invited);

    /**
     * @dev Constructor.
     * Initializes the contract and sets the default fee percentages.
     */
    constructor() {
        _transferOwnership(_msgSender());

        invitorFeePercentage = 20;
        invitedFeePercentage = 10;
    }

    /**
     * @dev Sets the affiliate fee percentages.
     * Only the contract owner can call this function.
     * @param newInvitorFeePercentage The new fee percentage for the invitor.
     * @param newInvitedFeePercentage The new fee percentage for the invited user.
     * @return A boolean indicating whether the fee percentages were set successfully.
     */
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

    /**
     * @dev Registers an affiliate relationship.
     * @param invitor The address of the invitor.
     * @param invited The address of the invited user.
     * @return A boolean indicating whether the affiliate relationship was registered successfully.
     */
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

    /**
     * @dev Calculates the affiliate fees for a given exchange fee amount.
     * @param exchangeFeeAmount The amount of the exchange fee.
     * @return invitorFeeAmount The invitor's fee amount.
     * @return invitedFeeAmount The invited user's fee amount.
     */
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

    /**
     * @dev Retrieves the affiliate address for the given invited user.
     * @param invited The address of the invited user.
     * @return The affiliate address.
     */
    function getAffiliateAddress(
        address invited
    ) public view returns (address) {
        return affiliates[invited];
    }
}
