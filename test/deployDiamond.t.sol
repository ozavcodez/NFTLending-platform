// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MerkleFacet.sol";
import "../contracts/facets/PresaleFacet.sol";

import "./helpers/DiamondUtils.sol";
import {Test, console2} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract DiamondDeployer is Test, DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;
    MerkleFacet merkleFacet;
    PresaleFacet presaleFacet;
    bytes32 public merkleRoot;
    address public owner;
    address public claimer;
    address public buyer;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        //upgrade diamond with facets
        erc721Facet = new ERC721Facet();
        merkleFacet = new MerkleFacet();
        presaleFacet = new PresaleFacet();

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](5);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = FacetCut({
            facetAddress: address(erc721Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        cut[3] = FacetCut({
            facetAddress: address(merkleFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("MerkleFacet")
        });

        cut[4] = FacetCut({
            facetAddress: address(presaleFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("PresaleFacet")
        });

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        owner = address(this);
        buyer = address(999999999);
        claimer = address(999988999);

        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "ts-node";
        inputs[2] = "../scripts/merkleRoot.ts";
        bytes memory result = vm.ffi(inputs);
        merkleRoot = abi.decode(result, (bytes32));

        uint256 oneWeek = 7 * 24 * 60 * 60;

        MerkleFacet(address(diamond)).initialiseFacet(merkleRoot, oneWeek);

        PresaleFacet(address(diamond)).initialisePresale(
            33333333333333333,
            0.01 ether,
            1 ether
        );

        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testFailInsufficientAmount() public {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        uint256 invalidAmount = 0.5 ether;
        vm.expectRevert("Insufficient payment"); //!fix this
        PresaleFacet(address(diamond)).buyNft{value: invalidAmount}(3);
    }

    function testFailUnauthorizedTransfer() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "..*/merkleRoot.ts";
        inputs[2] = vm.toString(claimer);
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proof = abi.decode(result, (bytes32[]));

        vm.prank(claimer);
        MerkleFacet(address(diamond)).claimAirdrop(proof);

        vm.prank(buyer);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        ERC721Facet(address(diamond)).transferFrom(claimer, buyer, 0);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
