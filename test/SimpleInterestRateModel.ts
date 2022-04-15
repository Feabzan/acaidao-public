import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signers';
import { SimpleInterestRateModel, SimpleInterestRateModel__factory } from '../typechain';
import { BigNumber } from 'ethers';

describe("SimpleInterestRateModel", () => {
    let deployer: SignerWithAddress;
    let lender: SignerWithAddress;
    let borrower1: SignerWithAddress;
    let borrower2: SignerWithAddress;

    let SimpleInterestRateModelContract: SimpleInterestRateModel;


    before(async () => {
        [deployer, lender, borrower1, borrower2] = await ethers.getSigners();
    })

    it("Deploy contract", async () => {
        const baseRatePerYear = BigNumber.from('50000000000000000');
        const multiplierPerYear = BigNumber.from('150000000000000000');

        SimpleInterestRateModelContract = await new SimpleInterestRateModel__factory(deployer).deploy(
            baseRatePerYear,
            multiplierPerYear
        );

        await SimpleInterestRateModelContract.deployed();

        expect(await SimpleInterestRateModelContract.callStatic.isInterestRateModel()).to.be.true;
        const result = await SimpleInterestRateModelContract.callStatic.baseRatePerBlock();
        expect(result.eq(baseRatePerYear.div(await SimpleInterestRateModelContract.BLOCKS_PER_YEAR())));

    });
});
