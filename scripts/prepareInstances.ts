import { Signer } from "ethers";
import {
  Exchange__factory,
  ExchangeConfig__factory,
  MockERC20__factory,
  MockERC721__factory,
  Divisible__factory,
  DivisibleProxyManager__factory,
  Fractional__factory,
  FractionalProxyManager__factory,
  Exchange,
  ExchangeConfig,
  MockERC20,
  MockERC721,
  Divisible,
  DivisibleProxyManager,
  Fractional,
  FractionalProxyManager,
} from "../typechain-types";

export interface IInstances {
  core: {
    Exchange: Exchange;
  };
  helpers: {
    ExchangeConfig: ExchangeConfig;
  };
  mocks: {
    MockERC20: MockERC20;
    MockERC721: MockERC721;
  };
  utils: {
    // Divisible: Divisible;
    DivisibleProxyManager: DivisibleProxyManager;
    // Fractional: Fractional;
    FractionalProxyManager: FractionalProxyManager;
  };
}

const prepareInstances = (signer: Signer, networkName: string): IInstances => {
  const addresses = require(`../tmp/deployments/${networkName}.json`);
  const exchange = Exchange__factory.connect(addresses.Exchange, signer);
  const exchangeConfig = ExchangeConfig__factory.connect(
    addresses.ExchangeConfig,
    signer
  );
  const mockERC20 = addresses["MockERC20"] && MockERC20__factory.connect(addresses.MockERC20, signer);
  const mockERC721 = addresses["MockERC721"] && MockERC721__factory.connect(addresses.MockERC721, signer);
  //   const divisible = Divisible__factory.connect(addresses.Divisible, signer);
  const divisibleProxyManager = DivisibleProxyManager__factory.connect(
    addresses.DivisibleProxyManager,
    signer
  );
  //   const fractional = Fractional__factory.connect(addresses.Fractional, signer);
  const fractionalProxyManager = FractionalProxyManager__factory.connect(
    addresses.FractionalProxyManager,
    signer
  );

  return {
    core: {
      Exchange: exchange,
    },
    helpers: {
      ExchangeConfig: exchangeConfig,
    },
    mocks: {
      MockERC20: mockERC20,
      MockERC721: mockERC721,
    },
    utils: {
      DivisibleProxyManager: divisibleProxyManager,
      FractionalProxyManager: fractionalProxyManager,
    },
  };
};

export default prepareInstances;