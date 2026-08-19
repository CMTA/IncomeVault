// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {IERC7741} from "../src/interfaces/IERC7741.sol";
import {IERC7540Operator} from "../src/interfaces/IERC7540Operator.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";

/**
* @title ERC-7741 signed operator authorisation
* @dev The holder signs; anyone may submit. Nothing here uses `vm.prank` on the holder for the
* authorisation itself — that is the entire point of the standard.
*/
contract OperatorAuthorizationTest is HelperContract {
    using SlotDerivation for string;

    uint256 holderKey;
    address holder;
    address constant CUSTODIAN = address(31);
    address constant RELAYER = address(33);

    bytes32 constant TYPEHASH =
        keccak256("AuthorizeOperator(address controller,address operator,bool approved,bytes32 nonce,uint256 deadline)");

    function setUp() public {
        holderKey = 0xA11CE;
        holder = vm.addr(holderKey);
        _deployContracts();
    }

    function _sign(uint256 key, address controller, address operator, bool approved, bytes32 nonce, uint256 deadline)
        internal view returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, controller, operator, approved, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", incomeVault.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    /* ============ the standard's identifier ============ */
    /**
    * @notice The interface id matches the value ERC-7741 assigns
    * @dev Pins all four signatures: change any of them and this fails.
    */
    function testInterfaceIdMatchesTheStandard() public pure {
        assertEq(type(IERC7741).interfaceId, bytes4(0xa9e50872));
    }

    /**
    * @notice ERC-7741 requires the id to be advertised — both variants do
    */
    function testBothVariantsAdvertiseErc7741() public {
        assertTrue(incomeVault.supportsInterface(bytes4(0xa9e50872)), "role-based variant");
        _deployOwnableVault();
        assertTrue(ownableVault.supportsInterface(bytes4(0xa9e50872)), "single-owner variant");
    }

    /**
    * @notice The module's ERC-7201 slot is what its comment claims
    */
    function testModuleStorageSlotDerivation() public pure {
        assertEq(
            string("IncomeVault.storage.ERC7741Module").erc7201Slot(),
            0xb93ff011b98f03386917a7b9b9106f5d9f85ba058e0b4e9b3aad1f6474a96800
        );
    }

    /* ============ the happy path ============ */
    /**
    * @notice A relayer submits the holder's signature; the holder never transacts
    */
    function testRelayerSubmitsTheHoldersAuthorization() public {
        bytes32 nonce = keccak256("nonce-1");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.expectEmit(true, true, false, true);
        emit IERC7540Operator.OperatorSet(holder, CUSTODIAN, true);
        vm.prank(RELAYER);
        bool ok = incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);

        assertTrue(ok, "MUST return true");
        assertEq(incomeVault.isOperator(holder, CUSTODIAN), true);
        assertEq(incomeVault.authorizations(holder, nonce), true, "the nonce is spent");
    }

    /**
    * @notice And the authorised operator can then actually claim for the holder
    */
    function testAuthorizedOperatorCanClaim() public {
        vm.prank(CMTAT_ADMIN);
        snapshotEngine.scheduleSnapshot(defaultSnapshotTime);
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(holder, ADDRESS1_INITIAL_AMOUNT);
        _performOnlyDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        bytes32 nonce = keccak256("nonce-claim");
        uint256 deadline = block.timestamp + 1 hours;
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(
            holder, CUSTODIAN, true, nonce, deadline,
            _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline)
        );

        vm.prank(CUSTODIAN);
        incomeVault.claimDividendFor(holder, defaultSnapshotTime);
        assertEq(tokenPayment.balanceOf(holder), defaultDepositAmount);
    }

    function testSignedRevocation() public {
        bytes32 n1 = keccak256("grant");
        bytes32 n2 = keccak256("revoke");
        uint256 deadline = block.timestamp + 1 hours;
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, n1, deadline, _sign(holderKey, holder, CUSTODIAN, true, n1, deadline));
        assertEq(incomeVault.isOperator(holder, CUSTODIAN), true);

        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, false, n2, deadline, _sign(holderKey, holder, CUSTODIAN, false, n2, deadline));
        assertEq(incomeVault.isOperator(holder, CUSTODIAN), false);
    }

    /* ============ refusals ============ */
    function testCannotReplayANonce() public {
        bytes32 nonce = keccak256("replay");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);

        vm.expectRevert(abi.encodeWithSignature(
            "IncomeVault_AuthorizationUsed(address,bytes32)", holder, nonce));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);
    }

    function testCannotUseAnExpiredSignature() public {
        bytes32 nonce = keccak256("expired");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSignature("IncomeVault_AuthorizationExpired(uint256)", deadline));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);
    }

    /**
    * @notice A signature from anyone but the controller is refused
    */
    function testCannotForgeAnAuthorization() public {
        uint256 attackerKey = 0xBAD;
        bytes32 nonce = keccak256("forged");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(attackerKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.expectRevert(abi.encodeWithSignature("IncomeVault_InvalidAuthorization(address)", holder));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);
        assertEq(incomeVault.isOperator(holder, CUSTODIAN), false);
    }

    /**
    * @notice Tampering with any signed field invalidates the signature
    */
    function testCannotTamperWithTheSignedTerms() public {
        bytes32 nonce = keccak256("tamper");
        uint256 deadline = block.timestamp + 1 hours;
        // signed for CUSTODIAN, submitted for the relayer instead
        bytes memory sig = _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.expectRevert(abi.encodeWithSignature("IncomeVault_InvalidAuthorization(address)", holder));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, RELAYER, true, nonce, deadline, sig);
    }

    function testCannotAuthorizeForTheZeroController() public {
        bytes32 nonce = keccak256("zero");
        uint256 deadline = block.timestamp + 1 hours;
        vm.expectRevert(abi.encodeWithSignature("IncomeVault_ControllerWithAddressZeroNotAllowed()"));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(ZERO_ADDRESS, CUSTODIAN, true, nonce, deadline, hex"00");
    }

    /* ============ invalidateNonce ============ */
    /**
    * @notice A holder can burn a nonce so a leaked signature can never be used
    */
    function testInvalidateNonceBurnsAPendingSignature() public {
        bytes32 nonce = keccak256("leaked");
        uint256 deadline = block.timestamp + 365 days;
        bytes memory sig = _sign(holderKey, holder, CUSTODIAN, true, nonce, deadline);

        vm.prank(holder);
        incomeVault.invalidateNonce(nonce);
        assertEq(incomeVault.authorizations(holder, nonce), true);

        vm.expectRevert(abi.encodeWithSignature(
            "IncomeVault_AuthorizationUsed(address,bytes32)", holder, nonce));
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, nonce, deadline, sig);
    }

    /**
    * @notice Invalidating is per holder — it cannot burn someone else's nonce
    */
    function testInvalidateNonceIsPerHolder() public {
        bytes32 nonce = keccak256("mine");
        vm.prank(RELAYER);
        incomeVault.invalidateNonce(nonce);
        assertEq(incomeVault.authorizations(holder, nonce), false, "the holder's nonce is untouched");
    }

    /**
    * @notice Nonces are unordered: a later one can be used before an earlier one
    */
    function testNoncesAreUnordered() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        bytes memory sigA = _sign(holderKey, holder, CUSTODIAN, true, a, deadline);
        bytes memory sigB = _sign(holderKey, holder, RELAYER, true, b, deadline);

        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, RELAYER, true, b, deadline, sigB);
        vm.prank(RELAYER);
        incomeVault.authorizeOperator(holder, CUSTODIAN, true, a, deadline, sigA);

        assertEq(incomeVault.isOperator(holder, CUSTODIAN), true);
        assertEq(incomeVault.isOperator(holder, RELAYER), true);
    }
}
