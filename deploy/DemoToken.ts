import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseUnits } from 'ethers/lib/utils';

const CONTRACT = "DemoToken";
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();


    await deploy(CONTRACT, {
        from: deployer,
        args: [
            deployer,
            parseUnits("1000000000", 18),
            "Demo Token",
            "DEMO"
        ],
        log: true,
        deterministicDeployment: true
    });

    // Transfer extra 100 DemoToken to accounts
    await execute(CONTRACT, { from: deployer, log: true }, 'transfer', lender, parseUnits("100", 18));
    await execute(CONTRACT, { from: deployer, log: true }, 'transfer', borrower1, parseUnits("100", 18));
    await execute(CONTRACT, { from: deployer, log: true }, 'transfer', borrower2, parseUnits("100", 18));

    console.log('USDC deployed');
};
export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = []