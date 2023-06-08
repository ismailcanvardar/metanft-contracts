import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";

export interface IDomain {
  name: string;
  version: string;
  chainId: number;
  verifyingContract: string;
}

export interface IListing {
  originAddress: string;
  tokenId: number;
  seller: string;
  startTimestamp: number;
  endTimestamp: number;
  softCap: BigNumber;
  hardCap: BigNumber;
  isERC20: boolean;
  erc20TokenAddress: string;
  listingType: number;
}

export interface IBid {
  originAddress: string;
  tokenId: number;
  bidder: string;
  bidAmount: BigNumber;
  isERC20: boolean;
  erc20TokenAddress: string;
}

export interface ISignatureHelper {
  signListing(
    _signer: SignerWithAddress,
    _listing: IListing,
    _nonce: BigNumber
  ): Promise<string>;
  signBid(
    _signer: SignerWithAddress,
    _bid: IBid,
    _nonce: BigNumber
  ): Promise<string>;
}

export default class SignatureHelper implements ISignatureHelper {
  public domain: IDomain;

  constructor(_domain: IDomain) {
    this.domain = _domain;
  }

  public async signListing(
    _signer: SignerWithAddress,
    _listing: IListing,
    _nonce: BigNumber
  ): Promise<string> {
    const { name, version, chainId, verifyingContract } = this.domain;
    const {
      originAddress,
      tokenId,
      seller,
      startTimestamp,
      endTimestamp,
      softCap,
      hardCap,
      isERC20,
      erc20TokenAddress,
      listingType,
    } = _listing;

    const domain = {
      name,
      version,
      chainId,
      verifyingContract,
    };

    const types = {
      Listing: [
        { name: "originAddress", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "seller", type: "address" },
        { name: "startTimestamp", type: "uint256" },
        { name: "endTimestamp", type: "uint256" },
        { name: "softCap", type: "uint256" },
        { name: "hardCap", type: "uint256" },
        { name: "isERC20", type: "bool" },
        { name: "erc20TokenAddress", type: "address" },
        { name: "listingType", type: "uint256" },
        { name: "nonce", type: "uint256" },
      ],
    };

    return await _signer._signTypedData(domain, types, {
      originAddress,
      tokenId,
      seller,
      startTimestamp,
      endTimestamp,
      softCap,
      hardCap,
      isERC20,
      erc20TokenAddress,
      listingType,
      nonce: _nonce,
    });
  }

  public async signBid(
    _signer: SignerWithAddress,
    _bid: IBid,
    _nonce: BigNumber
  ): Promise<string> {
    const { name, version, chainId, verifyingContract } = this.domain;
    const {
      originAddress,
      tokenId,
      bidder,
      bidAmount,
      isERC20,
      erc20TokenAddress,
    } = _bid;

    const domain = {
      name,
      version,
      chainId,
      verifyingContract,
    };

    const types = {
      Bid: [
        { name: "originAddress", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "bidder", type: "address" },
        { name: "bidAmount", type: "uint256" },
        { name: "isERC20", type: "bool" },
        { name: "erc20TokenAddress", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    };

    return await _signer._signTypedData(domain, types, {
      originAddress,
      tokenId,
      bidder,
      bidAmount,
      isERC20,
      erc20TokenAddress,
      nonce: _nonce,
    });
  }
}
