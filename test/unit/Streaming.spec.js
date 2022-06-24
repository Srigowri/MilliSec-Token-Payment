const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Deployment", () => {

    let owner;

    beforeEach("#deploy", async () => {
        Streaming = await ethers.getContractFactory("Streaming");
        [owner] = await ethers.getSigners();

        streamingContract = await Streaming.deploy();

        await streamingContract.deployed();
    });

    describe("#success", function () {

        describe("Deployment", function () {
            it("Should set the right owner", async function () {
                expect(await streamingContract.owner()).to.equal(owner.address);
            });
        });

    });
});