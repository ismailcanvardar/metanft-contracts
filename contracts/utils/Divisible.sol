// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

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

    modifier onlyCurator() {
        require(_msgSender() == curator, "onlyCurator: Lack of permission.");
        _;
    }

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

    function setPriceRulePercentage(
        uint256 newPriceRulePercentage
    ) external onlyCurator {
        priceRulePercentage = newPriceRulePercentage;
    }

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

    function _calculatePriceRule() internal view returns (uint256, uint256) {
        uint256 currentPricePercentage = (currentPrice * priceRulePercentage) /
            100;

        return (
            currentPrice - currentPricePercentage,
            currentPrice + currentPricePercentage
        );
    }
}
