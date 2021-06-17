pragma solidity 0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./Ownable.sol";

contract DiceRoll is VRFConsumerBase, Ownable {

	bytes32 private s_keyHash;
	uint256 private s_fee;

	uint256 public gameId;
	uint256 public lastGameId;
	uint256 private constant GAME_NOT_STARTED = 0;
	uint256 private constant ROLL_IN_PROGRESS = 42;

	mapping(bytes32 => Game) public games;

	struct Game {
		bytes32 id;
		uint256 seed;
		uint256 guess;
		uint256 result;
		uint256 amount;
		address payable player;
	}

	event Received(address indexed sender, uint256 amount);
	event DiceRolled(bytes32 indexed requestId);
	event DiceLanded(bytes32 indexed requestId, uint256 indexed result);

	constructor(address vrfCoordinator, address link, bytes32 keyHash, uint256 fee) public VRFConsumerBase(vrfCoordinator, link) {
		s_keyHash = keyHash;
		s_fee = fee;
	}

	receive() external payable {
		emit Received(msg.sender, msg.value);
	}

	function rollDice(uint256 guess, uint256 seed) public payable returns (bytes32 requestId) {
		require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to pay fee");

		requestId = requestRandomness(s_keyHash, s_fee, seed);
		games[requestId] = Game(requestId, seed, guess, GAME_NOT_STARTED, msg.value, msg.sender);

		emit DiceRolled(requestId);
	}

	function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
		uint256 d6Value = randomness.mod(6).add(1);
		Game storage game = games[requestId];
		game.result = d6Value;
		emit DiceLanded(requestId, d6Value);
	}

	function checkResults(bytes32 requestId) public view returns (bool) {
		require(games[requestId].result != GAME_NOT_STARTED, "Dice not rolled");
		require(games[requestId].result != ROLL_IN_PROGRESS, "Roll in progress");
		return games[requestId].result == games[requestId].guess;
	}

	function claim(bytes32 requestId) public virtual {
		require(games[requestId].result != GAME_NOT_STARTED, "Dice not rolled");
		require(games[requestId].result != ROLL_IN_PROGRESS, "Roll in progress");
		require(games[requestId].player == msg.sender, "You cannot claim the rewards for this game");
		require(games[requestId].guess == games[requestId].result, "You did not win this game");
		if (games[requestId].guess == games[requestId].result) {
			games[requestId].player.transfer(address(this).balance.div(2));
		}
	}

	function withdrawLink(uint256 amount) external onlyOwner {
		require(LINK.transfer(msg.sender, amount), "Unable to transfer");
	}

	function withdraw(uint256 amount) external onlyOwner {
		require(address(this).balance >= amount, "Insufficient balance");
		payable(owner()).transfer(amount);
	}
}