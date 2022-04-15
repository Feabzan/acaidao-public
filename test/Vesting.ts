import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signers';
import { USDCToken__factory, USDCToken, Vesting__factory, Vesting, EVesting } from '../typechain';
import { parseEther } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';
import moment from 'moment';

describe("Vesting", () => {
    let deployer: SignerWithAddress;
    let lender: SignerWithAddress;
    let borrower1: SignerWithAddress;
    let borrower2: SignerWithAddress;

    let USDCTokenContract: USDCToken;
    let VestingContract: Vesting;

    before(async () => {
        [deployer, lender, borrower1, borrower2] = await ethers.getSigners();
        USDCTokenContract = await new USDCToken__factory(deployer).deploy(
            deployer.address,
            parseEther('1000000000'),
            "USD Coin",
            "USDC"
        );

        await USDCTokenContract.deployed();

    })

    it("Deploy Vesting contract", async () => {
        const amount = BigNumber.from('500000000');

        const start = moment().add(1, 'days').format('X');
        const end = moment().add(2, 'days').format('X');
        VestingContract = await new Vesting__factory(deployer).deploy(
            borrower1.address,
            USDCTokenContract.address,
            amount,
            start,
            end
        );

        await VestingContract.deployed();


        expect(await VestingContract.callStatic.isVesting()).to.be.true;
        expect(await VestingContract.callStatic.vestingAmount()).to.equal(amount);

    });

    it("Enable Vesting contract", async () => {
        const amount = BigNumber.from('500000000');

        const start = moment().add(1, 'days').format('X');
        const end = moment().add(2, 'days').format('X');
        VestingContract = await new Vesting__factory(deployer).deploy(
            borrower1.address,
            USDCTokenContract.address,
            amount,
            start,
            end
        );

        expect(await VestingContract.callStatic.isVesting()).to.be.true;
        expect(await VestingContract.callStatic.vestingAmount()).to.equal(amount);
        expect(await VestingContract.callStatic.canEnable()).to.equal(await VestingContract.REWARD_CONDITIONS_NOT_MET());
        {
            const tx = await USDCTokenContract.transfer(VestingContract.address, amount);
            await tx.wait();
        }
        expect(await VestingContract.callStatic.canEnable()).to.equal(await VestingContract.NO_ERROR());
        {
            const tx = await VestingContract.enable();
            await tx.wait();
        }

        expect(await VestingContract.callStatic.enabled()).to.equal(true);
    });
});
