// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;


import "./HelperContract.sol";
import "RuleEngine/rules/validation/abstract/RuleAddressList/RuleWhitelistInvariantStorage.sol";

/**
* @title Integration test with the CMTAT
*/
contract RuleEngineIntegration is RuleWhitelistInvariantStorage, Test, HelperContract {
    // Defined in CMTAT.sol
    uint8 constant TRANSFER_OK = 0;
    string constant TEXT_TRANSFER_OK = "No restriction";
    // Contracts
    RuleEngine ruleEngineMock;
    RuleWhitelist ruleWhitelist;

    // Other variable
    uint256 resUint256;
    bool resBool;

    uint256 ADDRESS1_BALANCE_INIT = 31;
    uint256 ADDRESS2_BALANCE_INIT = 32;
    uint256 ADDRESS3_BALANCE_INIT = 33;

    uint256 tokenBalance = 5000;
    // Arrange
    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        // global arrange
        uint8 decimals = 0;
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT = new CMTAT_STANDALONE(
            ZERO_ADDRESS,
            CMTAT_ADMIN,
            IAuthorizationEngine(address(0)),
            "CMTA Token",
            "CMTAT",
            decimals,
            "CMTAT_ISIN",
            "https://cmta.ch",
            IRuleEngine(address(0)),
            "CMTAT_info",
            FLAG
        );

        // specific arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRuleValidation(ruleWhitelist);

        // Token payment
        tokenPayment = new CMTAT_STANDALONE(
            ZERO_ADDRESS,
            TOKEN_PAYMENT_ADMIN,
            IAuthorizationEngine(address(0)),
            "CMTA Token",
            "CMTAT",
            DECIMALS,
            "CMTAT_ISIN",
            "https://cmta.ch",
            IRuleEngine(address(0)),
            "CMTAT_info",
            FLAG
        );

        // Deploy DebtVault
        debtVault = new DebtVault(
            ZERO_ADDRESS
        );
        debtVault.initialize(
            DEFAULT_ADMIN_ADDRESS,
            tokenPayment,
            ICMTATSnapshot(address(CMTAT_CONTRACT)),
            IRuleEngine(ZERO_ADDRESS),
            IAuthorizationEngine(ZERO_ADDRESS)
        );

        // We set the Rule Engine
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setRuleEngine(ruleEngineMock);
        /**
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(DEFAULT_ADMIN_ADDRESS, ADDRESS1_INITIAL_AMOUNT);
        */
        vm.prank(TOKEN_PAYMENT_ADMIN);
        tokenPayment.mint(DEFAULT_ADMIN_ADDRESS, tokenBalance);
    }

    function _performOnlyDeposit() internal {
        // Allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenPayment.approve(address(debtVault), defaultDepositAmount);
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.deposit(defaultSnapshotTime, defaultDepositAmount);
    }

    function _performDeposit() internal {
        _performOnlyDeposit();
        // Configure snapshot

        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.scheduleSnapshot(defaultSnapshotTime);
        
        // Mint token for Address 1
        vm.prank(CMTAT_ADMIN);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_INITIAL_AMOUNT);
    }

    /******* Transfer *******/
    function testCannotClaimWithoutAddressWhitelisted() public {
        // Arrange
        _performDeposit();
        // Act
        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Contract pause
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.pause();
        
        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(Errors.CMTAT_InvalidTransfer.selector, address(debtVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        debtVault.claimDividend(defaultSnapshotTime);
    }

    function testCannotTransferWithoutFromAddressWhitelisted() public {
        // Arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(address(debtVault));

        // Arrange
        _performDeposit();
        // Act
        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Contract pause
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.pause();
        
        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(Errors.CMTAT_InvalidTransfer.selector, address(debtVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        debtVault.claimDividend(defaultSnapshotTime);
    }

    function testCannotTransferWithoutToAddressWhitelisted() public {
        // Arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(ADDRESS1);

        // Arrange
        _performDeposit();
        // Act
        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);

        // Contract pause
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.pause();
        
        // Act
        // Claim deposit
        vm.expectRevert(
        abi.encodeWithSelector(Errors.CMTAT_InvalidTransfer.selector, address(debtVault), ADDRESS1, defaultDepositAmount));
        vm.prank(ADDRESS1);
        debtVault.claimDividend(defaultSnapshotTime);
    }

    function testCanMakeATransfer() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = address(debtVault);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success, ) = address(ruleWhitelist).call(
            abi.encodeWithSignature(
                "addAddressesToTheList(address[])",
                whitelist
            )
        );
        require(success);
       
        // Act
        // Arrange
        _performDeposit();

        // Timeout
        uint256 timeout = defaultSnapshotTime + 50;
        vm.warp(timeout);
        
        // Open claim
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        debtVault.setStatusClaim(defaultSnapshotTime, true);
        
        // Claim deposit
        vm.prank(ADDRESS1);
        debtVault.claimDividend(defaultSnapshotTime);

        // Check balance
        resUint256 = tokenPayment.balanceOf(ADDRESS1);
        assertEq(resUint256, defaultDepositAmount); 
    }

    /******* detectTransferRestriction & messageForTransferRestriction *******/
    function testDetectAndMessageWithFromNotWhitelisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddressToTheList(ADDRESS2);
        resBool = ruleWhitelist.addressIsListed(ADDRESS2);
        // Assert
        assertEq(resBool, true);
        uint8 res1 = debtVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        string memory message1 = debtVault.messageForTransferRestriction(
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
        uint8 res1 = debtVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Act
        string memory message1 = debtVault.messageForTransferRestriction(
            res1
        );
        // Assert
        assertEq(message1, TEXT_ADDRESS_TO_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithFromAndToNotWhitelisted() public {
        // Act
        uint8 res1 = debtVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );

        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        string memory message1 = debtVault.messageForTransferRestriction(
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
        (bool success, ) = address(ruleWhitelist).call(
            abi.encodeWithSignature(
                "addAddressesToTheList(address[])",
                whitelist
            )
        );
        require(success);
        // Act
        uint8 res1 = debtVault.detectTransferRestriction(
            ADDRESS1,
            ADDRESS2,
            11
        );
        // Assert
        assertEq(res1, TRANSFER_OK);
        // Act
        string memory message1 = debtVault.messageForTransferRestriction(
            res1
        );
        // Assert
        assertEq(message1, TEXT_TRANSFER_OK);
    }
}
