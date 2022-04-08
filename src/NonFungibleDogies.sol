// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.4;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {VRFConsumerBase} from "chainlink/VRFConsumerBase.sol";

contract NonFungibleDogies is ERC721, VRFConsumerBase {
    error DogieDoesNotExist();

    event AdoptionRequested(bytes32 requestId, address trainerAddr);
    event BreedDetermined(uint256 newDogieId, Breed breed);

    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    string constant PUG =
        "ipfs://Qmd9MCGtdVz2miNumBHDbvj8bigSgTwnr4SbyH6DNnpWdt?filename=0-PUG.json";
    string constant SHIBA_INU =
        "ipfs://QmdryoExpgEQQQgJPoruwGJyZmz6SqV4FRTX1i73CT3iXn?filename=1-SHIBA_INU.json";
    string constant ST_BERNARD =
        "ipfs://QmbBnUjyHHN7Ytq9xDsYF9sucZdDJLRkWz7vnZfrjMXMxs?filename=2-ST_BERNARD.json";

    uint256 public tokenCounter;

    mapping(uint256 => string) internal dogieIdToTokenUri;
    mapping(uint256 => Breed) internal dogieIdToBreed;
    mapping(bytes32 => address) internal adoptionRequestIdToTrainerAddr;

    // Chainlink
    bytes32 public keyHash;
    uint256 public fee;

    constructor(
        string memory name,
        string memory symbol,
        address _vrfCoordinatorAddr,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    ) ERC721(name, symbol) VRFConsumerBase(_vrfCoordinatorAddr, _link) {
        keyHash = _keyHash;
        fee = _fee;
    }

    function tokenURI(uint256 dogieId)
        public
        view
        override
        returns (string memory)
    {
        if (ownerOf[dogieId] == address(0)) revert DogieDoesNotExist();
        return dogieIdToTokenUri[dogieId];
    }

    function adoptNewDogie() public returns (bytes32 adoptionRequestId) {
        adoptionRequestId = requestRandomness(keyHash, fee);
        adoptionRequestIdToTrainerAddr[adoptionRequestId] = msg.sender;
        emit AdoptionRequested(adoptionRequestId, msg.sender);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        Breed breed = Breed(randomness % 3);
        uint256 newDogieId = tokenCounter;
        dogieIdToBreed[newDogieId] = breed;
        emit BreedDetermined(newDogieId, breed);
        address trainer = adoptionRequestIdToTrainerAddr[requestId];
        _safeMint(trainer, newDogieId);
        string memory tokenUri;
        if (uint256(breed) == 0) {
            tokenUri = PUG;
        } else if (uint256(breed) == 1) {
            tokenUri = SHIBA_INU;
        } else {
            tokenUri = ST_BERNARD;
        }
        dogieIdToTokenUri[newDogieId] = tokenUri;
        ++tokenCounter;
    }
}
