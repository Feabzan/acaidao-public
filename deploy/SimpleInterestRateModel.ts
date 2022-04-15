import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseEther } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const baseRatePerYear =  BigNumber.from('50000000000000000');
    const multiplierPerYear =  BigNumber.from('150000000000000000');
    await deploy("SimpleInterestRateModel", {
        from: deployer,
        args: [
            baseRatePerYear,
            multiplierPerYear
        ],
        log: true,
        deterministicDeployment: false
    });
};
export default deployFunction;

deployFunction.id = "SimpleInterestRateModel";
deployFunction.tags = ["SimpleInterestRateModel"]
deployFunction.dependencies = ["DemoToken"]