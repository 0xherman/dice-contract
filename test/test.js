const { expect } = require("chai");

describe("DiceRoll", function() {
  it("Should be able to withdraw and receive eth", async function() {
    const DiceRoll = await ethers.getContractFactory("DiceRoll");
    const diceRoll = await DiceRoll.deploy("Hello, world!");
    
    await diceRoll.deployed();
    expect(await diceRoll.greet()).to.equal("Hello, world!");

    await diceRoll.setGreeting("Hola, mundo!");
    expect(await diceRoll.greet()).to.equal("Hola, mundo!");
  });
});
