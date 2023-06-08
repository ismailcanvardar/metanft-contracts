// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

/**
 * @title Divisible
 * @dev A contract for managing divisible tokens and their sale.
 */
contract Divisible is ERC20Upgradeable, ERC721HolderUpgradeable {
    address public originAddress;
    uint256 public tokenId;
    address public curator;
    uint256 public currentPrice;
    uint256 public priceRulePercentage = 5;
    mapping(address => uint256) public listPrices;
    mapping(address => uint256) public listAmount;

    uint256 public salePrice;
    uint256 public saleLength;
    uint256 public startBlock;
    SaleStatus public saleStatus;
    uint256 public saleAmount;
    uint256 public soldAmount = 0;

    enum SaleStatus {
        INACTIVE,
        ACTIVE,
        DONE
    }

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);
    event BuyDivisibleFromSale(address indexed account, uint256 amount);
    event CashOut(address indexed account, uint256 amount);
    event StartSale(
        address indexed curator,
        uint256 salePrice,
        uint256 saleLength
    );
    event List(address indexed account, uint256 amount, uint256 price);
    event DirectBuy(
        address indexed buyer,
        address indexed from,
        uint256 amount,
        uint256 price
    );
    event EndSale(SaleStatus saleStatus);
    event CancelListing(address indexed account, uint256 amount, uint256 price);

    /**
     * @dev Modifier that restricts the execution of a function to only the curator.
     * Throws an error if the caller is not the curator.
     */
    modifier onlyCurator() {
        require(_msgSender() == curator, "onlyCurator: Lack of permission.");
        _;
    }

    /**
     * @dev Initializes the Divisible contract.
     * @param _curator The address of the curator.
     * @param _originAddress The address of the original ERC721 contract.
     * @param _tokenId The ID of the token within the original ERC721 contract.
     * @param totalSupply The total supply of the divisible tokens.
     * @param name The name of the divisible token.
     * @param symbol The symbol of the divisible token.
     */
    function initialize(
        address _curator,
        address _originAddress,
        uint256 _tokenId,
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC20_init(name, symbol);
        __ERC721Holder_init();
        originAddress = _originAddress;
        tokenId = _tokenId;
        curator = _curator;

        _mint(curator, totalSupply);
    }

    /**
     * @dev Sets the price rule percentage for determining the price range.
     * Only the curator can invoke this function.
     * @param newPriceRulePercentage The new price rule percentage.
     */
    function setPriceRulePercentage(
        uint256 newPriceRulePercentage
    ) external onlyCurator {
        priceRulePercentage = newPriceRulePercentage;
    }

    /**
     * @dev Starts the sale of the divisible tokens.
     * Only the curator can invoke this function.
     * @param price The sale price of each divisible token.
     * @param length The length of the sale in blocks.
     * @param amount The total amount of tokens available for sale.
     */
    function startSale(
        uint256 price,
        uint256 length,
        uint256 amount
    ) external onlyCurator {
        require(
            saleStatus == SaleStatus.INACTIVE,
            "startSale: Sale was started, already."
        );
        require(
            allowance(curator, address(this)) >= amount,
            "startSale: Has to approve tokens first!"
        );

        saleStatus = SaleStatus.ACTIVE;
        saleLength = length;
        startBlock = block.timestamp;
        salePrice = price;
        currentPrice = price;
        saleAmount = amount;

        emit StartSale(_msgSender(), price, length);
    }

    /**
     * @dev Buys a specific amount of divisible tokens from the sale.
     * @param amount The amount of tokens to buy.
     */
    function buyDivisibleFromSale(uint256 amount) external payable {
        require(
            saleStatus == SaleStatus.ACTIVE,
            "buyDivisibleFromSale: Sale is not active."
        );
        require(
            block.timestamp < startBlock + saleLength,
            "buyDivisibleFromSale: Sale is ended."
        );
        require(
            soldAmount <= saleAmount && soldAmount + amount <= saleAmount,
            "buyDivisibleFromSale: Out of sale amount!"
        );

        uint256 cost = salePrice * (amount / 10 ** 18);
        require(msg.value >= cost, "buyDivisibleFromSale: Not enough funds.");

        (bool sent, ) = address(this).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                curator,
                _msgSender(),
                amount
            )
        );
        require(sent, "buyDivisibleFromSale: Unable to transfer tokens.");

        soldAmount += amount;

        emit BuyDivisibleFromSale(_msgSender(), amount);
    }

    /**
     * @dev Ends the sale of the divisible tokens.
     * Only the curator can invoke this function.
     */
    function endSale() external onlyCurator {
        require(
            saleStatus == SaleStatus.ACTIVE,
            "endSale: Sale is not active."
        );
        require(
            block.timestamp > startBlock + saleLength,
            "endSale: Sale has to be finished to make this action."
        );

        saleStatus = SaleStatus.DONE;

        emit EndSale(SaleStatus.DONE);
    }

    /**
     * @dev Allows the token holders to cash out their tokens.
     */
    function cashOut() external {
        require(
            saleStatus == SaleStatus.DONE,
            "cashOut: Cannot make this action before sale is ended."
        );

        uint256 balanceOfCaller = balanceOf(_msgSender());
        uint256 calculatedAmount = balanceOfCaller * salePrice;

        require(
            address(this).balance >= balanceOfCaller,
            "cashOut: Not enough balance in contract."
        );

        _burn(_msgSender(), balanceOfCaller);
        (bool sent, ) = _msgSender().call{value: calculatedAmount}("");
        require(sent, "cashOut: Unable to send.");

        emit CashOut(_msgSender(), balanceOfCaller);
    }

    /**
     * @dev Lists a specific amount of tokens for sale at a given price.
     * @param amount The amount of tokens to list.
     * @param price The listing price for each token.
     */
    function list(uint256 amount, uint256 price) external {
        require(
            saleStatus == SaleStatus.DONE,
            "list: Sale has to be finished in order to list tokens."
        );
        require(
            allowance(_msgSender(), address(this)) >= amount,
            "list: Has to approve tokens first!"
        );
        require(
            listPrices[_msgSender()] == 0 && listAmount[_msgSender()] == 0,
            "list: Already listed before."
        );

        (uint256 min, uint256 max) = _calculatePriceRule();

        require(price <= max && price >= min, "list: Must ensure price rule.");

        listPrices[_msgSender()] = price;
        listAmount[_msgSender()] = amount;

        emit List(_msgSender(), amount, price);
    }

    /**
     * @dev Cancels the listing of the tokens.
     */
    function cancelListing() external {
        require(
            listPrices[_msgSender()] > 0 && listAmount[_msgSender()] > 0,
            "cancelListing: Listing needed to make this action."
        );

        listPrices[_msgSender()] = 0;
        listAmount[_msgSender()] = 0;

        emit CancelListing(
            _msgSender(),
            listPrices[_msgSender()],
            listAmount[_msgSender()]
        );
    }

    /**
     * @dev Allows a direct purchase of tokens from a specific address.
     * @param from The address from which to buy the tokens.
     * @param amount The amount of tokens to buy.
     */
    function directBuy(address from, uint256 amount) external payable {
        require(
            listAmount[from] >= amount,
            "directBuy: Buy amount exceeds listing amount!"
        );

        uint256 individualCost = listPrices[from];
        uint256 cost = (amount / 10 ** 18) * individualCost;
        require(msg.value >= cost, "directBuy: Insufficient funds.");

        (bool sent, ) = from.call{value: cost}("");
        require(sent, "directBuy: Unable to send!");
        (bool sentVal, ) = address(this).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                _msgSender(),
                amount
            )
        );
        require(sentVal, "directBuy: Unable to transfer tokens.");

        currentPrice = individualCost;
        listAmount[from] -= amount;

        emit DirectBuy(_msgSender(), from, amount, individualCost);
    }

    /**
     * @dev Reclaims the remaining tokens to the original owner.
     */
    function reclaim() external {
        require(
            balanceOf(_msgSender()) == totalSupply(),
            "reclaim: Must own total supply of tokens."
        );

        IERC721(originAddress).transferFrom(
            address(this),
            _msgSender(),
            tokenId
        );

        emit Reclaim(_msgSender(), originAddress, tokenId);
    }

    /**
     * @dev Calculates the price range based on the current price and the price rule percentage.
     * @return The minimum and maximum price based on the price rule.
     */
    function _calculatePriceRule() internal view returns (uint256, uint256) {
        uint256 currentPricePercentage = (currentPrice * priceRulePercentage) /
            100;

        return (
            currentPrice - currentPricePercentage,
            currentPrice + currentPricePercentage
        );
    }
}
