const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { setTime, currentTime } = require("../helpers");

describe("Withdraw from stream", () => {

    let owner;
    let sender;
    let recipient1, addrs;
    let startTimestamp;
    let stopTimestamp;

    let deposit = ethers.utils.parseEther("1");
    let now = currentTime();

    let blockSpacing = 1000;
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

        now = now + blockSpacing;

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

    describe("#success", function () {

        it("should emit the WithdrawFromStream event", async function () {
            let timeToSet = stopTimestamp + 1;
            await setTime(ethers.provider, timeToSet);

            await expect(
                streamingContract.connect(recipient1).withdrawFromStream(1)
            ).to
                .emit(streamingContract, "WithdrawFromStream")
                .withArgs(1, recipient1.address);
        });

    });

    describe("#gasCheck", function () {
        it("should happen within the gas limit", async function () {
            let timeToSet = stopTimestamp + 1;
            await setTime(ethers.provider, timeToSet);

            const BASE_GAS_USAGE = 58_100;

            const currentGas = (await streamingContract.connect(recipient1).estimateGas.withdrawFromStream(1)).toNumber();
            assert(currentGas < BASE_GAS_USAGE);
          });
    });

    describe("#reverts", function () {

        it("should fail when stream doesn't exist", async function () {
            let invalidStreamId = 3;
            await expect(
                streamingContract.connect(recipient1).withdrawFromStream(invalidStreamId)
            ).to.be.revertedWith("stream does not exist");
        });

        it("should fail when recipient is unknown", async function () {            
            await expect(
                streamingContract.connect(sender).withdrawFromStream(1)
            ).to.be.revertedWith("invalid recipient of the stream");
        });

    });
});