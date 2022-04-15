import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseUnits } from 'ethers/lib/utils';

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    await deploy("USDCToken", {
        from: deployer,
        args: [
            deployer,
            parseUnits("1000000000", 6),
            "USD Coin",
            "USDC"
        ],
        log: true,
        deterministicDeployment: true
    });

    // Transfer extra 1000 USDC to accounts
    await execute('USDCToken', { from: deployer, log: true }, 'transfer', lender, parseUnits("100000", 6));
    await execute('USDCToken', { from: deployer, log: true }, 'transfer', borrower1, parseUnits("100000", 6));
    await execute('USDCToken', { from: deployer, log: true }, 'transfer', borrower2, parseUnits("100000", 6));

    console.log('USDC deployed');
};
export default deployFunction;

deployFunction.id = "USDCToken";
deployFunction.tags = ["USDCToken"]
deployFunction.dependencies = []