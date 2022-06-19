import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ERC20 } from "../typechain";

describe("ERC20", () => {
  let erc20Contract: ERC20;
  let sender: SignerWithAddress;
  let recipient: SignerWithAddress;

  beforeEach(async () => {
    const ERC20Factory = await ethers.getContractFactory("ERC20");
    erc20Contract = await ERC20Factory.deploy("ERC20", "ABC");
    await erc20Contract.deployed();

    const signersAddresses = await ethers.getSigners();
    sender = signersAddresses[1];
    recipient = signersAddresses[2];
  });

  describe("When I have 10 tokens", () => {
    beforeEach(async () => {
      erc20Contract.transfer(sender.address, 10);
    });

    describe("When I transfer 10 tokens", () => {
      it("Should transfer tokens correctly", async () => {
        await erc20Contract.connect(sender).transfer(recipient.address, 10);

        expect(await erc20Contract.balanceOf(recipient.address)).to.equal(10);
      });
    });

    describe("When I transfer 15 tokens", () => {
      it("Should revert the transaction", async () => {
        await expect(
          erc20Contract.connect(sender).transfer(recipient.address, 15)
        ).to.be.revertedWith("ERC20: balance exceeded");
      });
    });
  });
});
