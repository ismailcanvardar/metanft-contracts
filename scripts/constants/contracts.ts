interface IContracts {
  [key: string]: Object;
  core: {
    Exchange: string;
  };
  helpers: {
    ExchangeConfig: string;
    RoyaltyFeeManager: string;
  };
  mocks: {
    MockERC20?: string;
    MockERC721?: string;
    WETH?: string;
  };
  utils: {
    Affiliate: string;
    Multicall: string;
  };
}

const CONTRACTS: IContracts = {
  core: {
    Exchange: "Exchange",
  },
  helpers: {
    ExchangeConfig: "ExchangeConfig",
    RoyaltyFeeManager: "RoyaltyFeeManager"
  },
  mocks: {
    MockERC20: "MockERC20",
    MockERC721: "MockERC721",
    WETH: "WETH",
  },
  utils: {
    Affiliate: "Affiliate",
    Multicall: "Multicall"
  },
};

export default CONTRACTS;
