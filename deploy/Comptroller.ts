import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import SimplePriceOracleDeployment from './SimplePriceOracle';

const CONTRACT = 'Comptroller';
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const SimplePriceOracle = await get(SimplePriceOracleDeployment.id!);

    await deploy(CONTRACT, {
        from: deployer,
        args: [],
        log: true,
        deterministicDeployment: false
    });

    await execute(CONTRACT, { from: deployer, log: true }, '_setPriceOracle', SimplePriceOracle.address);
    await execute(CONTRACT, { from: deployer, log: true }, '_setMaxAssets', 10);
    await execute(CONTRACT, { from: deployer, log: true }, '_setCloseFactor', '500000000000000000');
    await execute(CONTRACT, { from: deployer, log: true }, '_setLiquidationIncentive', '1080000000000000000');
};
export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = [SimplePriceOracleDeployment.id!]