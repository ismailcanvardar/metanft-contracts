interface IConstructorParams {
    Exchange: {
        WETH: string;
    },
    RoyaltyFeeManager: {
        MAXIMUM_FEE_PERCENTAGE: number;
    };
}

const CONSTRUCTOR_PARAMS: IConstructorParams = {
    Exchange: {
        WETH: "0x7C03cb7e9466FE13D1772b275809bcf1A0E67B9F",
    },
    RoyaltyFeeManager: {
        MAXIMUM_FEE_PERCENTAGE: 20
    }
};

export default CONSTRUCTOR_PARAMS;