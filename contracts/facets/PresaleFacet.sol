// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibDiamond.sol";
import "./ERC721Facet.sol";

contract PresaleFacet {
    error InsufficientAmount();
    error MaxItemsExceeded();

    function initialisePresale(
        uint256 _price,
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (msg.sender != ds.contractOwner) revert LibDiamond.NotDiamondOwner();

        ds.nftPrice = _price;
        ds.minPurchase = _minPurchase;
        ds.maxPurchase = _maxPurchase;
    }

    function buyNft(uint256 _noOfTokens) external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (_noOfTokens < ds.minPurchase) revert InsufficientAmount();
        if (_noOfTokens > ds.maxPurchase) revert MaxItemsExceeded();
        if (msg.value < _noOfTokens * ds.nftPrice) revert InsufficientAmount();

        for (uint256 i = 0; i < _noOfTokens; i++) {
            ERC721Facet(address(this)).safeMint(msg.sender, ds.totalSupply);

            ds.totalSupply += 1;
        }
    }
}
