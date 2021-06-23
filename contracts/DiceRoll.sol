pragma solidity 0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./Ownable.sol";

contract DiceRoll is VRFConsumerBase, Ownable {

	bytes32 private s_keyHash;
	uint256 private s_fee;

	uint256 private constant ROLL_IN_PROGRESS = 0;

	bool public paused = true;
	uint256 public minBid = 0;
	uint256 private MAX_BID = 1 ether;

	mapping(bytes32 => Game) public games;
	mapping(address => bytes32[]) public gamesByAddress;

	struct Game {
		bytes32 id;
		uint256 seed;
		uint256 guess;
		uint256 result;
		uint256 bid;
		address payable player;
		bool paid;
	}

	event Received(address indexed sender, uint256 amount);
	event DiceRolled(bytes32 indexed requestId, uint256 bid);
	event DiceLanded(bytes32 indexed requestId, uint256 indexed result);
	event WinnerPaid(address indexed sender, bytes32 indexed requestId, uint256 amount);

	constructor(address vrfCoordinator, address link, bytes32 keyHash, uint256 fee) public VRFConsumerBase(vrfCoordinator, link) {
		s_keyHash = keyHash;
		s_fee = fee;
	}

	receive() external payable {
		emit Received(msg.sender, msg.value);
	}

	function setPaused(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function setMinBid(uint256 _minBid) external onlyOwner {
		require(_minBid > 0, "Minimum bid cannot be less than 0");
		require(_minBid <= MAX_BID, "Minimum bid cannot be greater than maximum bid");
		minBid = _minBid;
	}

	function setMaxBid(uint256 _maxBid) external onlyOwner {
		require(_maxBid > 0, "Maximum bid cannot be less than 0");
		require(_maxBid >= minBid, "Maximum bid cannot be less than minimum bid");
		MAX_BID = _maxBid;
	}

	function maxBid() public view returns (uint256) {
		uint256 _maxBid = address(this).balance.div(2);
		if (MAX_BID < _maxBid) {
			return MAX_BID;
		}
		return _maxBid;
	}

	function rollDice(uint256 guess, uint256 seed) external payable returns (bytes32 requestId) {
		require(!paused, "Game is paused");
		require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to pay fee");
		require(address(this).balance >= msg.value, "Cannot bid more than held in pool");
		require(msg.value <= maxBid(), "Bid value too high for current max bid or pool value");
		require(msg.value >= minBid, "Bid value too low for current min bid");

		requestId = requestRandomness(s_keyHash, s_fee, seed);
		games[requestId] = Game(requestId, seed, guess, ROLL_IN_PROGRESS, msg.value, msg.sender, false);
		gamesByAddress[msg.sender].push(requestId);

		emit DiceRolled(requestId, msg.value);
	}

	function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
		uint256 d6Value = randomness.mod(6).add(1);
		Game storage game = games[requestId];
		game.result = d6Value;
		emit DiceLanded(requestId, d6Value);
	}

	function checkResults(bytes32 requestId) external view returns (bool) {
		require(games[requestId].result != ROLL_IN_PROGRESS, "Roll in progress");
		return games[requestId].result == games[requestId].guess;
	}

	function claim(bytes32 requestId) public virtual {
		require(games[requestId].result != ROLL_IN_PROGRESS, "Roll in progress");
		require(games[requestId].player == msg.sender, "You cannot claim the rewards for this game");
		require(games[requestId].guess == games[requestId].result, "You did not win this game");
		require(address(this).balance > games[requestId].bid.mul(2), "There are not enough winnings in the pool to pay out your claim. Either wait for pool to grow or withdraw your initial.");
		if (games[requestId].guess == games[requestId].result) {
			Game storage game = games[requestId];
			game.paid = true;
			games[requestId].player.transfer(games[requestId].bid.mul(2));
			emit WinnerPaid(games[requestId].player, requestId, games[requestId].bid.mul(2));
		}
	}

	function withdrawClaim(bytes32 requestId) external virtual {
		require(games[requestId].result != ROLL_IN_PROGRESS, "Roll in progress");
		require(games[requestId].player == msg.sender, "You cannot withdraw the bid for this game");
		require(games[requestId].guess == games[requestId].result, "You did not win this game");
		require(address(this).balance > games[requestId].bid, "There are not enough winnings in the pool to pay out your claim. Please wait for pool to grow.");
		if (games[requestId].guess == games[requestId].result) {
			Game storage game = games[requestId];
			game.paid = true;
			games[requestId].player.transfer(games[requestId].bid);
			emit WinnerPaid(games[requestId].player, requestId, games[requestId].bid);
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