import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseUnits } from 'ethers/lib/utils';

import VestingDepoyment from './Vesting';
import ComptrollerDepoyment from './Comptroller';

const CONTRACT = 'Vault';
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const vesting = await get(VestingDepoyment.id!);

    const discountMantissa = '500000000000000000'; // 0.5
    const collateralFactorMantissa = '500000000000000000'; // 0.5

    const vault = await deploy(CONTRACT, {
        from: deployer,
        args: [
            vesting.address,
            discountMantissa,
            collateralFactorMantissa
        ],
        log: true,
        deterministicDeployment: false
    });

    // Suppport collateral on Comptroller
    await execute(ComptrollerDepoyment.id!, { from: deployer, log: true }, '_supportCollateralVault', vesting.address, vault.address);
};
export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = [ComptrollerDepoyment.id!, VestingDepoyment.id!]