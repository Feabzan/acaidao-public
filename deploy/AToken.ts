import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { BigNumber } from 'ethers';
import { parseUnits } from 'ethers/lib/utils';
import SimplePriceOracleDeployment from './SimplePriceOracle';
import ComptrollerDeployment from './Comptroller';
import SimpleInterestRateModelDeployment from './SimpleInterestRateModel';
import USDCTokenDeployment from './USDCToken';

const CONTRACT = "AErc20";
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const USDCToken = await get(USDCTokenDeployment.id!);
    const Comptroller = await get(ComptrollerDeployment.id!);
    const SimpleInterestRateModel = await get(SimpleInterestRateModelDeployment.id!);

    const initialExchangeRateMantissa = '200000000000000';

    const AErc20 = await deploy(CONTRACT, {
        from: deployer,
        args: [
            USDCToken.address,
            Comptroller.address,
            SimpleInterestRateModel.address,
            initialExchangeRateMantissa,
            'Acai USDC',
            "aUSDC",
            6
        ],
        log: true,
        deterministicDeployment: true
    });

    const currentPrice = parseUnits('0.0003', 18);

    await execute(ComptrollerDeployment.id!, { from: deployer, log: true }, '_supportMarket', AErc20.address);
    await execute(SimplePriceOracleDeployment.id!, { from: deployer, log: true }, 'setUnderlyingPrice', AErc20.address, currentPrice);
    await execute(ComptrollerDeployment.id!, { from: deployer, log: true }, '_setCollateralFactor', AErc20.address, '0');

    await execute(USDCTokenDeployment.id!, { from: deployer, log: true }, 'approve', AErc20.address, parseUnits("10000000", 6));

    // Supply USDC to AToken pool
    await execute(CONTRACT, { from: deployer, log: true }, 'mint', BigNumber.from("3000000000000"));
};

export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = [SimplePriceOracleDeployment.id!, SimpleInterestRateModelDeployment.id!, ComptrollerDeployment.id!, USDCTokenDeployment.id!]