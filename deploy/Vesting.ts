import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { parseUnits } from 'ethers/lib/utils';

import ComptrollerDepoyment from './Comptroller';
import DemoTokenDepoyment from './DemoToken';
import USDCTokenDeployment from './USDCToken';

import moment from 'moment';

const CONTRACT = 'Vesting';
const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer, lender, borrower1, borrower2 } = await getNamedAccounts();

    const DemoToken = await get(DemoTokenDepoyment.id!);

    const amount = parseUnits("100", 18);
    const start = moment().format('X');                             // Start Now
    const end = moment().add(1, 'days').format('X');    // End after 1 day

    const vesting = await deploy(CONTRACT, {
        from: deployer,
        args: [
            borrower1,
            DemoToken.address,
            amount,
            start,
            end
        ],
        log: true,
        deterministicDeployment: false
    });

    // Transfer 100 DemoToken to vesting contract
    await execute(DemoTokenDepoyment.id!, { from: deployer, log: true }, 'transfer', vesting.address, amount);

    // Enable vesting contract
    await execute(CONTRACT, { from: deployer, log: true }, 'enable');
};
export default deployFunction;

deployFunction.id = CONTRACT;
deployFunction.tags = [CONTRACT]
deployFunction.dependencies = ["SimplePriceOracle", ComptrollerDepoyment.id!, DemoTokenDepoyment.id!, USDCTokenDeployment.id!]