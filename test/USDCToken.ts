import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signers';
import { USDCToken__factory, USDCToken } from '../typechain';
import { parseEther } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

describe("USDCToken", () => {
    let deployer: SignerWithAddress;
    let lender: SignerWithAddress;
    let borrower1: SignerWithAddress;
    let borrower2: SignerWithAddress;

    let USDCTokenFactory: USDCToken;
    let USDCTokenContract: USDCToken;

    before(async () => {
        [deployer, lender, borrower1, borrower2] = await ethers.getSigners();
    })

    it("Should deploy and transfer USDC mock", async () => {
        USDCTokenContract = await new USDCToken__factory(deployer).deploy(
            deployer.address,
            parseEther('1000000000'),
            "USD Coin",
            "USDC"
        );

        await USDCTokenContract.deployed();

        expect(await USDCTokenContract.callStatic.balanceOf(lender.address)).to.equal(0);

        const amount = BigNumber.from('1000000000');
        const transferTx = await USDCTokenContract.transfer(lender.address, amount)
        await transferTx.wait();

        expect(await USDCTokenContract.callStatic.balanceOf(lender.address)).to.equal(amount);
    });
});
