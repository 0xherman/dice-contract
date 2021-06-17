// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const DiceRoll = await hre.ethers.getContractFactory("DiceRoll");
  const diceRoll = await DiceRoll.deploy("0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B", "0x01BE23585060835E02B77ef475b0Cc51aA1e0709", "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311", 100000000000000000);

  await diceRoll.deployed();

  console.log("DiceRoll deployed to:", diceRoll.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
