// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "./HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {RuleWhitelistMock} from "RuleEngine/mocks/rules/validation/RuleWhitelistMock.sol";
import {RuleWhitelistInvariantStorage} from "RuleEngine/mocks/rules/validation/abstract/RuleAddressList/invariantStorage/RuleWhitelistInvariantStorage.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

/**
* @title Integration test between the IncomeVault and the RuleEngine
*/
contract RuleEngineIntegration is HelperContract, RuleWhitelistInvariantStorage {
    // Defined by the RuleEngine
    uint8 constant TRANSFER_OK = 0;

    // Contracts
    RuleEngine ruleEngineMock;
    RuleWhitelistMock ruleWhitelist;

    // Other variable
    uint256 resUint256;
    bool resBool;

    // Arrange
    function setUp() public {
        ruleWhitelist = new RuleWhitelistMock(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        _deployContracts();

        // The vault is not a token bound to the engine: it only uses the read path,
        // so no token has to be bound at deployment.
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(incomeVault));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(IRule(address(ruleWhitelist)));

        // We set the Rule Engine
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setRuleEngine(ruleEngineMock);
    }

    /******* Claim *******/
    function testCannotClaimWithoutAddressWhitelisted() public {
        // Arrange
        _performDeposit();
        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Act
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testCannotClaimWithoutToAddressWhitelisted() public {
        // Arrange: only the vault (the sender) is whitelisted
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(address(incomeVault));

        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        vm.warp(defaultSnapshotTime + 50);

        // Act
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testCannotClaimWithoutFromAddressWhitelisted() public {
        // Arrange: only the holder (the recipient) is whitelisted
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(ADDRESS1);

        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        vm.warp(defaultSnapshotTime + 50);

        // Act
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);
    }

    function testCanClaimWithBothAddressesWhitelisted() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = address(incomeVault);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressesToTheList(whitelist);

        _performDeposit();

        // Timeout
        vm.warp(defaultSnapshotTime + 50);

        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);

        // Claim deposit
        vm.prank(ADDRESS1);
        incomeVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, defaultDepositAmount);
    }

    /******* canTransfer *******/
    function testCanTransferIsFalseWhenNotWhitelisted() public view {
        assertEq(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 11), false);
    }

    function testCanTransferIsTrueWhenWhitelisted() public {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = address(incomeVault);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressesToTheList(whitelist);

        assertEq(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 11), true);
    }

    function testCanTransferIsFalseWhenPausedEvenIfWhitelisted() public {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = address(incomeVault);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressesToTheList(whitelist);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.pause();

        assertEq(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 11), false);
    }

    /******* detectTransferRestriction & messageForTransferRestriction *******/
    function testDetectAndMessageWithFromNotWhitelisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(ADDRESS2);
        resBool = ruleWhitelist.addressIsListed(ADDRESS2);
        // Assert
        assertEq(resBool, true);
        uint8 res1 = incomeVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        string memory message1 = incomeVault.messageForTransferRestriction(
            res1
        );
        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithToNotWhitelisted() public {
        // Arrange
        // We add the sender to the whitelist
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(ADDRESS1);
        // Arrange - Assert
        resBool = ruleWhitelist.addressIsListed(ADDRESS1);
        assertEq(resBool, true);
        // Act
        uint8 res1 = incomeVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Act
        string memory message1 = incomeVault.messageForTransferRestriction(
            res1
        );
        // Assert
        assertEq(message1, TEXT_ADDRESS_TO_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithFromAndToNotWhitelisted() public view {
        // Act
        uint8 res1 = incomeVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );

        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        string memory message1 = incomeVault.messageForTransferRestriction(
            res1
        );

        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithAValidTransfer() public {
        // Arrange
        // We add the sender and the recipient to the whitelist.
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressesToTheList(whitelist);
        // Act
        uint8 res1 = incomeVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, TRANSFER_OK);
        // Act
        string memory message1 = incomeVault.messageForTransferRestriction(
            res1
        );
        // Assert
        assertEq(message1, TEXT_TRANSFER_OK);
    }

    /******* setRuleEngine *******/
    function testCannotSetRuleEngineWithTheSameValue() public {
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_SameValue.selector));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setRuleEngine(ruleEngineMock);
    }

    function testAdminCanUnsetTheRuleEngine() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setRuleEngine(IRuleEngine(ZERO_ADDRESS));
        assertEq(address(incomeVault.ruleEngine()), ZERO_ADDRESS);
        // Without a RuleEngine there is no rule restriction anymore
        assertEq(incomeVault.canTransfer(address(incomeVault), ADDRESS1, 11), true);
    }

    /******* distributeDividend — H-2 *******/
    /**
    * @notice The issuer cannot push a dividend to an address the RuleEngine refuses
    * @dev This is the compliance property the RuleEngine integration exists to provide: before the
    * H-2 fix the push path skipped the engine entirely, so a non-whitelisted holder could be paid.
    */
    function testCannotDistributeToANonWhitelistedHolder() public {
        // only the vault is whitelisted, not the holder
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(address(incomeVault));

        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.expectRevert(
        abi.encodeWithSelector(IncomeVault_InvalidTransfer.selector, address(incomeVault), ADDRESS1, defaultDepositAmount));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), 0);
        assertEq(incomeVault.claimedDividend(ADDRESS1, defaultSnapshotTime), false);
    }

    /**
    * @notice Once both addresses are whitelisted the distribution goes through
    */
    function testCanDistributeWhenBothAddressesWhitelisted() public {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = address(incomeVault);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressesToTheList(whitelist);

        _performDeposit();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.setStatusClaim(defaultSnapshotTime, true);
        vm.warp(defaultSnapshotTime + 50);

        address[] memory addresses = new address[](1);
        addresses[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        incomeVault.distributeDividend(addresses, defaultSnapshotTime);

        assertEq(tokenPayment.balanceOf(ADDRESS1), defaultDepositAmount);
    }
}
