const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { currentTime } = require("../helpers");

describe("Balance of stream", () => {

    let owner;
    let sender;
    let recipient1, addrs;
    let startTimestamp;
    let stopTimestamp;

    let deposit = ethers.utils.parseEther("1");
    let now = currentTime();

    let duration;

    beforeEach("#deploy", async () => {
        Streaming = await ethers.getContractFactory("Streaming");
        [owner, sender, recipient1, ...addrs] = await ethers.getSigners();

        streamingContract = await Streaming.deploy();

        await streamingContract.deployed();
    });

    beforeEach("#setup", async function () {
        duration = 100;
        let delay = 100;

        startTimestamp = now + delay;
        stopTimestamp = startTimestamp + duration;

        await streamingContract.connect(sender).createStream(
            recipient1.address,
            deposit,
            startTimestamp,
            stopTimestamp,
            { value: deposit }
        );
    });

    describe("#reverts", function () {

        it("should fail when stream doesn't exist", async function () {
            let invalidStreamId = 3;
            await expect(
                streamingContract.balanceOf(invalidStreamId, sender.address)
            ).to.be.revertedWith("stream does not exist");
        });

    });

    describe("#success", function () {

        it("should return 0 balance for address not involved in stream", async function () {
            const otherPartyBalance = await streamingContract.balanceOf(1, owner.address);
            assert(otherPartyBalance.eq(0));
        });

    });

    describe("#gasCheck", function () {
        it("should happen within the gas limit", async function () {
            const BASE_GAS_USAGE = 44_000;

            const currentGas = (await streamingContract.estimateGas.balanceOf(1, recipient1.address)).toNumber();
            assert(currentGas < BASE_GAS_USAGE);
        });
    });
});