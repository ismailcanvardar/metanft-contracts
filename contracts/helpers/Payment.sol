// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IPayment.sol";

abstract contract Payment is IPayment {
     event SendETH(address from, address to, uint256 amount);
     event SendToken(address contractAddress, address from, address to, uint256 amount);

     function safeSendETH(address from, address to, uint256 amount) override public returns(bool) {
          require(from != address(0), "safeSendETH: Invalid from address.");
          require(to != address(0), "safeSendETH: Invalid to address.");
          require(amount > 0, "safeSendETH: Invalid amount");

          return _sendETH(from, to, amount);
     }

     function safeSendToken(address contractAddress, address from, address to, uint256 amount) override public returns(bool) {
          require(contractAddress != address(0), "safeSendToken: Invalid token contract address.");
          require(from != address(0), "safeSendToken: Invalid from address.");
          require(to != address(0), "safeSendToken: Invalid to address.");
          require(amount > 0, "safeSendToken: Invalid amount");

          return _sendToken(contractAddress, from, to, amount);
     }

     function _sendETH(address _from, address _to, uint256 _amount) internal returns(bool) {
          (bool sent, ) = _to.call{value: _amount}("");

          require(sent, "_sendETH: Unable to send.");

          emit SendETH(_from, _to, _amount);
          return sent;
     }

     function _sendToken(address _contractAddress, address _from, address _to, uint256 _amount) internal returns(bool) {
          IERC20 token = IERC20(_contractAddress);
          bool status = token.transferFrom(_from, _to, _amount);

          emit SendToken(_contractAddress, _from, _to, _amount);
          return status;
     }
}