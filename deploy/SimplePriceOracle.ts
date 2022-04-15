import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseUnits } from 'ethers/lib/utils';
import DemoTokenDepoyment from './DemoToken';
import USDCTokenDeployment from './USDCToken';

const CONTRACT = 'SimplePriceOracle';
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const DemoToken = await get(DemoTokenDepoyment.id!);
    const USDCToken = await get(USDCTokenDeployment.id!);

    await deploy(CONTRACT, {
        from: deployer,
        args: [],
        log: true,
        deterministicDeployment: false
    });

    await execute(CONTRACT, { from: deployer, log: true }, 'setDirectPrice', DemoToken.address, parseUnits("1", 18));
    await execute(CONTRACT, { from: deployer, log: true }, 'setDirectPrice', USDCToken.address, parseUnits("0.0003", 18));

};
export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = [DemoTokenDepoyment.id!, USDCTokenDeployment.id!]