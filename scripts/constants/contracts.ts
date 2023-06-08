interface IContracts {
  [key: string]: Object;
  core: {
    Exchange: string;
    Rentable: string;
  };
  helpers: {
    ExchangeConfig: string;
    RentableConfig: string;
    RoyaltyFeeManager: string;
  };
  mocks: {
    MockERC20?: string;
    MockERC721?: string;
    WETH?: string;
  };
  utils: {
    Affiliate: string;
    Divisible?: string;
    DivisibleProxyManager: string;
    Fractional?: string;
    FractionalProxyManager: string;
    Multicall: string;
  };
}

const CONTRACTS: IContracts = {
  core: {
    Exchange: "Exchange",
    Rentable: "Rentable",
  },
  helpers: {
    ExchangeConfig: "ExchangeConfig",
    RentableConfig: "RentableConfig",
    RoyaltyFeeManager: "RoyaltyFeeManager"
  },
  mocks: {
    MockERC20: "MockERC20",
    MockERC721: "MockERC721",
    WETH: "WETH",
  },
  utils: {
    Affiliate: "Affiliate",
    Divisible: "Divisible",
    DivisibleProxyManager: "DivisibleProxyManager",
    Fractional: "Fractional",
    FractionalProxyManager: "FractionalProxyManager",
    Multicall: "Multicall"
  },
};

export default CONTRACTS;
