// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "../utils/MerkleProof.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Diamond} from "../Diamond.sol";
import {ERC721Facet} from "./ERC721Facet.sol";

contract MerkleFacet {
    error ZeroAddress();
    error InvalidProof();
    error UserClaimed();
    error OnlyOwner();
    error AirdropEnded();
    error AirdropExhausted();

    event AirdropClaimed(address indexed account, uint time, uint256 tokenId);

    function initialiseFacet(bytes32 _merkleRoot, uint _duration) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (msg.sender != ds.contractOwner) revert LibDiamond.NotDiamondOwner();

        ds.merkleRoot = _merkleRoot;
        ds.endDate = block.timestamp + _duration;
    }

    function claimAirdrop(bytes32[] memory _merkleProof) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (msg.sender == address(0)) revert ZeroAddress();
        if (ds.claimedAddresses[msg.sender] == true) revert UserClaimed();
        if (block.timestamp >= ds.endDate) revert AirdropEnded();
        if (ds.totalSupply > 100) revert AirdropExhausted();

        verifyProof(_merkleProof, msg.sender);

        ds.totalSupply += 1;

        uint256 _tokenId = ds.totalSupply;

        ds.claimedAddresses[msg.sender] = true;

        ERC721Facet(address(this)).safeMint(msg.sender, _tokenId);

        emit AirdropClaimed(msg.sender, block.timestamp, _tokenId);
    }

    function verifyProof(
        bytes32[] memory _proof,
        address _account
    ) private view {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        bytes32 leaf = keccak256(abi.encode(_account));

        bool validProof = MerkleProof.verify(_proof, ds.merkleRoot, leaf);

        if (!validProof) revert InvalidProof();
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (msg.sender != ds.contractOwner) revert OnlyOwner();

        ds.merkleRoot = _merkleRoot;
    }
}
