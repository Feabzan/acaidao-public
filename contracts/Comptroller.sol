// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./AToken.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IComptroller.sol";
import "./utils/Exponential.sol";
import "./ComptrollerStorage.sol";
import "./ComptrollerErrorReporter.sol";

/**
 * @title Compound's Comptroller Contract
 * @author Compound
 */
contract Comptroller is
    ComptrollerStorage,
    IComptroller,
    ComptrollerErrorReporter,
    Exponential
{
    function isComptroller() external pure returns (bool) {
        return true;
    }

    struct Market {
        /**
         * @notice Whether or not this market is listed
         */
        bool isListed;
        /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 0.9 to allow borrowing 90% of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint256 collateralFactorMantissa;
        /**
         * @notice Per-market mapping of "accounts in this asset"
         */
        mapping(address => bool) accountMembership;

        // Mapping of account to vesting contract
        // mapping(address => IVesting) public accountToVesting;
    }

    /**
     * @notice Official mapping of aTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;

    /**
     * @notice Emitted when an admin supports a market
     */
    event MarketListed(AToken aToken);

    /**
     * @notice Emitted when an account enters a market
     */
    event MarketEntered(AToken aToken, address account);

    /**
     * @notice Emitted when an account exits a market
     */
    event MarketExited(AToken aToken, address account);

    /**
     * @notice Emitted when close factor is changed by admin
     */
    event NewCloseFactor(
        uint256 oldCloseFactorMantissa,
        uint256 newCloseFactorMantissa
    );

    /**
     * @notice Emitted when a collateral factor is changed by admin
     */
    event NewCollateralFactor(
        AToken aToken,
        uint256 oldCollateralFactorMantissa,
        uint256 newCollateralFactorMantissa
    );

    /**
     * @notice Emitted when liquidation incentive is changed by admin
     */
    event NewLiquidationIncentive(
        uint256 oldLiquidationIncentiveMantissa,
        uint256 newLiquidationIncentiveMantissa
    );

    /**
     * @notice Emitted when maxAssets is changed by admin
     */
    event NewMaxAssets(uint256 oldMaxAssets, uint256 newMaxAssets);

    /**
     * @notice Emitted when price oracle is changed
     */
    event NewPriceOracle(
        PriceOracle oldPriceOracle,
        PriceOracle newPriceOracle
    );

    // closeFactorMantissa must be strictly greater than this value
    uint256 private constant CLOSE_FACTOR_MIN_MANTISSA = 5e16; // 0.05

    // closeFactorMantissa must not exceed this value
    uint256 private constant CLOSE_FACTOR_MAX_MANTISSA = 9e17; // 0.9

    // No collateralFactorMantissa may exceed this value
    uint256 private constant COLLATERAL_FACTOR_MAX_MANTISSA = 9e17; // 0.9

    // liquidationIncentiveMantissa must be no less than this value
    uint256 private constant LIQUIDATION_INCENTIVE_MIN_MANTISSA = MANTISSA_ONE;

    // liquidationIncentiveMantissa must be no greater than this value
    uint256 private constant LIQUIDATION_INCENTIVE_MAX_MANTISSA = 15e17; // 1.5

    constructor() {
        admin = msg.sender;
    }

    /*** Assets You Are In ***/

    /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account)
        external
        view
        returns (AToken[] memory)
    {
        AToken[] memory assetsIn = accountAssets[account];

        return assetsIn;
    }

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param aToken The aToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, AToken aToken)
        external
        view
        returns (bool)
    {
        return markets[address(aToken)].accountMembership[account];
    }

    /**
     * @notice Registers vesting contract. Validates the recipient is the vault contract and then sets enabled as collateral to true
     */
    function registerVestingContract(address _vestingContractAddress) external {
        IVesting _vestingContract = IVesting(_vestingContractAddress);

        // Require only one vesting contract per account
        require(
            accountRegisteredVesting[msg.sender] == IVesting(address(0)),
            "Already registered a vesting contract"
        );

        // Require collateral is listed
        require(
            vestingContractInfo[_vestingContract].isListed,
            "Must be listed"
        );

        // Require collateral is not enabled yet
        require(
            !vestingContractInfo[_vestingContract].enabledAsCollateral,
            "Must not be enabled"
        );

        // Validate that the recipient of the vesting contract is this Comptroller
        require(
            _vestingContract.recipient() == address(this),
            "Recipient must be Comptroller"
        );

        // Validate original recipient is caller. This assumes that vault is already deployed in _supportCollateralVault
        require(
            IVault(vestingContractInfo[_vestingContract].vault)
                .originalRecipient() == msg.sender,
            "Original recipient must be caller"
        );

        // Enable collateral for user in the Comptroller
        vestingContractInfo[_vestingContract].enabledAsCollateral = true;
        accountRegisteredVesting[msg.sender] = _vestingContract;

        // Set recipient from this to vesting vault
        _vestingContract.setRecipient(
            vestingContractInfo[_vestingContract].vault
        );
    }

    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param aTokens The list of addresses of the aToken markets to be enabled
     * @return Success indicator for whether each corresponding market was entered
     */
    function enterMarkets(address[] memory aTokens)
        public
        returns (uint256[] memory)
    {
        uint256 len = aTokens.length;

        uint256[] memory results = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            AToken aToken = AToken(aTokens[i]);
            Market storage marketToJoin = markets[address(aToken)];

            if (!marketToJoin.isListed) {
                // if market is not listed, cannot join move along
                results[i] = uint256(Error.MARKET_NOT_LISTED);
                continue;
            }

            if (marketToJoin.accountMembership[msg.sender] == true) {
                // if already joined, move along
                results[i] = uint256(Error.NO_ERROR);
                continue;
            }

            if (accountAssets[msg.sender].length >= maxAssets) {
                // if no space, cannot join, move along
                results[i] = uint256(Error.TOO_MANY_ASSETS);
                continue;
            }

            // survived the gauntlet, add to list
            // NOTE: we store these somewhat redundantly as a significant optimization
            //  this avoids having to iterate through the list for the most common use cases
            //  that is, only when we need to perform liquidity checks
            //   and not whenever we want to check if an account is in a particular market
            marketToJoin.accountMembership[msg.sender] = true;
            accountAssets[msg.sender].push(aToken);

            emit MarketEntered(aToken, msg.sender);

            results[i] = uint256(Error.NO_ERROR);
        }

        return results;
    }

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @dev Sender must not have an outstanding borrow balance in the asset,
     *  or be providing neccessary collateral for an outstanding borrow.
     * @param aTokenAddress The address of the asset to be removed
     * @return Whether or not the account successfully exited the market
     */
    function exitMarket(address aTokenAddress) external returns (uint256) {
        AToken aToken = AToken(aTokenAddress);
        /* Get sender tokensHeld and amountOwed underlying from the aToken */
        (uint256 oErr, uint256 tokensHeld, uint256 amountOwed, ) = aToken
            .getAccountSnapshot(msg.sender);
        require(oErr == 0, "exitMarket: getAccountSnapshot failed"); // semi-opaque error code

        /* Fail if the sender has a borrow balance */
        if (amountOwed != 0) {
            return
                fail(
                    Error.NONZERO_BORROW_BALANCE,
                    FailureInfo.EXIT_MARKET_BALANCE_OWED
                );
        }

        /* Fail if the sender is not permitted to redeem all of their tokens */
        uint256 allowed = redeemAllowedInternal(
            aTokenAddress,
            msg.sender,
            tokensHeld
        );
        if (allowed != 0) {
            return
                failOpaque(
                    Error.REJECTION,
                    FailureInfo.EXIT_MARKET_REJECTION,
                    allowed
                );
        }

        Market storage marketToExit = markets[address(aToken)];

        /* Return true if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint256(Error.NO_ERROR);
        }

        /* Set aToken account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete aToken from the account’s list of assets */
        // load into memory for faster iteration
        AToken[] memory userAssetList = accountAssets[msg.sender];
        uint256 len = userAssetList.length;
        uint256 assetIndex = len;
        for (uint256 i = 0; i < len; i++) {
            if (userAssetList[i] == aToken) {
                assetIndex = i;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        assert(assetIndex < len);

        // copy last item in list to location of item to be removed, reduce length by 1
        AToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        emit MarketExited(aToken, msg.sender);

        return uint256(Error.NO_ERROR);
    }

    /*** Policy Hooks ***/

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param aToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(
        address aToken,
        address minter,
        uint256 mintAmount
    ) external returns (uint256) {
        minter; // currently unused
        mintAmount; // currently unused

        if (!markets[aToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // *may include Policy Hook-type checks

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param aToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of aTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowed(
        address aToken,
        address redeemer,
        uint256 redeemTokens
    ) external returns (uint256) {
        return redeemAllowedInternal(aToken, redeemer, redeemTokens);
    }

    function redeemAllowedInternal(
        address aToken,
        address redeemer,
        uint256 redeemTokens
    ) internal view returns (uint256) {
        if (!markets[aToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // *may include Policy Hook-type checks

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!markets[aToken].accountMembership[redeemer]) {
            return uint256(Error.NO_ERROR);
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (
            Error err,
            ,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                redeemer,
                AToken(aToken),
                redeemTokens,
                0
            );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall > 0) {
            return uint256(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param aToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function redeemVerify(
        address aToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external {
        aToken; // currently unused
        redeemer; // currently unused
        redeemAmount; // currently unused
        redeemTokens; // currently unused

        // Require tokens is zero or amount is also zero
        if (redeemTokens == 0 && redeemAmount > 0) {
            revert("redeemTokens zero");
        }
    }

    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param aToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function borrowAllowed(
        address aToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256) {
        if (!markets[aToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // *may include Policy Hook-type checks

        if (!markets[aToken].accountMembership[borrower]) {
            return uint256(Error.MARKET_NOT_ENTERED);
        }

        if (oracle.getUnderlyingPrice(AToken(aToken)) == 0) {
            return uint256(Error.PRICE_ERROR);
        }

        (
            Error err,
            ,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                borrower,
                AToken(aToken),
                0,
                borrowAmount
            );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall > 0) {
            return uint256(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to repay a borrow in the given market
     * @param aToken The market to verify the repay against
     * @param payer The account which would repay the asset
     * @param borrower The account which would borrowed the asset
     * @param repayAmount The amount of the underlying asset the account would repay
     * @return 0 if the repay is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function repayBorrowAllowed(
        address aToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256) {
        payer; // currently unused
        borrower; // currently unused
        repayAmount; // currently unused

        if (!markets[aToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // *may include Policy Hook-type checks

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param aTokenBorrowed Asset which was borrowed by the borrower
     * @param aTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(
        address aTokenBorrowed,
        address aTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256) {
        liquidator; // currently unused
        borrower; // currently unused
        repayAmount; // currently unused

        if (
            !markets[aTokenBorrowed].isListed ||
            !markets[aTokenCollateral].isListed
        ) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // *may include Policy Hook-type checks

        /* The borrower must have shortfall in order to be liquidatable */
        (Error err, , uint256 shortfall) = getAccountLiquidityInternal(
            borrower
        );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall == 0) {
            return uint256(Error.INSUFFICIENT_SHORTFALL);
        }

        /* The liquidator may not repay more than what is allowed by the closeFactor */
        uint256 borrowBalance = AToken(aTokenBorrowed).borrowBalanceStored(
            borrower
        );
        (MathError mathErr, uint256 maxClose) = mulScalarTruncate(
            Exp({mantissa: closeFactorMantissa}),
            borrowBalance
        );
        if (mathErr != MathError.NO_ERROR) {
            return uint256(Error.MATH_ERROR);
        }
        if (repayAmount > maxClose) {
            return uint256(Error.TOO_MUCH_REPAY);
        }

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the seizing of assets should be allowed to occur
     * @param aTokenCollateral Asset which was used as collateral and will be seized
     * @param aTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeAllowed(
        address aTokenCollateral,
        address aTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256) {
        liquidator; // currently unused
        borrower; // currently unused
        seizeTokens; // currently unused

        if (
            !markets[aTokenCollateral].isListed ||
            !markets[aTokenBorrowed].isListed
        ) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        if (
            AToken(aTokenCollateral).comptroller() !=
            AToken(aTokenBorrowed).comptroller()
        ) {
            return uint256(Error.COMPTROLLER_MISMATCH);
        }

        // *may include Policy Hook-type checks

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param aToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of aTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function transferAllowed(
        address aToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external returns (uint256) {
        aToken; // currently unused
        src; // currently unused
        dst; // currently unused
        transferTokens; // currently unused

        // *may include Policy Hook-type checks

        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        return redeemAllowedInternal(aToken, src, transferTokens);
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (
            Error err,
            uint256 liquidity,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                account,
                AToken(address(0)),
                0,
                0
            );

        return (uint256(err), liquidity, shortfall);
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code,
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidityInternal(address account)
        internal
        view
        returns (
            Error,
            uint256,
            uint256
        )
    {
        return
            getHypotheticalAccountLiquidityInternal(
                account,
                AToken(address(0)),
                0,
                0
            );
    }

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `aTokenBalance` is the number of aTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
        uint256 aTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;
        uint256 oraclePriceMantissa;
        uint256 collateralNPV;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToEther;
        VestingContractInfo vestingInfo;
        IVault _vault;
        IVesting _vesting;
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param aTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @dev Note that we calculate the exchangeRateStored for each collateral aToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        AToken aTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    )
        internal
        view
        returns (
            Error,
            uint256,
            uint256
        )
    {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint256 oErr;
        MathError mErr;

        vars.vestingInfo = vestingContractInfo[
            accountRegisteredVesting[account]
        ];

        vars._vault = IVault(vars.vestingInfo.vault);
        vars._vesting = IVesting(accountRegisteredVesting[account]);

        vars.collateralNPV =
            vars._vault.getNPV() -
            vars.vestingInfo.amountOwedToLiquidator;

        vars.oraclePriceMantissa = oracle.getPrice(
            vars._vesting.getTokenAddress()
        );
        if (vars.oraclePriceMantissa == 0) {
            return (Error.PRICE_ERROR, 0, 0);
        }
        vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

        vars.collateralFactor = Exp({
            mantissa: vars._vault.collateralFactorMantissa()
        });

        // calculate tokensToEther = collareralFactor * oraclePrice
        (mErr, vars.tokensToEther) = mulExp(
            vars.collateralFactor,
            vars.oraclePrice
        );
        if (mErr != MathError.NO_ERROR) {
            return (Error.MATH_ERROR, 0, 0);
        }

        // sumCollateral += tokensToEther * NPV Value
        (mErr, vars.sumCollateral) = mulScalarTruncateAddUInt(
            vars.tokensToEther,
            vars.collateralNPV,
            vars.sumCollateral
        );
        if (mErr != MathError.NO_ERROR) {
            return (Error.MATH_ERROR, 0, 0);
        }

        // For each asset the account is in
        AToken[] memory assets = accountAssets[account];
        for (uint256 i = 0; i < assets.length; i++) {
            AToken asset = assets[i];

            // Read the balances and exchange rate from the aToken
            (
                oErr,
                vars.aTokenBalance,
                vars.borrowBalance,
                vars.exchangeRateMantissa
            ) = asset.getAccountSnapshot(account);
            if (oErr != 0) {
                // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
                return (Error.SNAPSHOT_ERROR, 0, 0);
            }
            vars.collateralFactor = Exp({
                mantissa: markets[address(asset)].collateralFactorMantissa
            });
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            (mErr, vars.tokensToEther) = mulExp3(
                vars.collateralFactor,
                vars.exchangeRate,
                vars.oraclePrice
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // sumCollateral += tokensToEther * aTokenBalance
            (mErr, vars.sumCollateral) = mulScalarTruncateAddUInt(
                vars.tokensToEther,
                vars.aTokenBalance,
                vars.sumCollateral
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrowPlusEffects
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // Calculate effects of interacting with aTokenModify
            if (asset == aTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToEther * redeemTokens
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                    vars.tokensToEther,
                    redeemTokens,
                    vars.sumBorrowPlusEffects
                );
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                    vars.oraclePrice,
                    borrowAmount,
                    vars.sumBorrowPlusEffects
                );
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }
            }
        }

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (
                Error.NO_ERROR,
                vars.sumCollateral - vars.sumBorrowPlusEffects,
                0
            );
        } else {
            return (
                Error.NO_ERROR,
                0,
                vars.sumBorrowPlusEffects - vars.sumCollateral
            );
        }
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in aToken.liquidateBorrowFresh)
     * @param aTokenBorrowed The address of the borrowed aToken
     * @param aTokenCollateral The address of the collateral aToken
     * @param repayAmount The amount of aTokenBorrowed underlying to convert into aTokenCollateral tokens
     * @return (errorCode, number of aTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateCalculateSeizeTokens(
        address aTokenBorrowed,
        address aTokenCollateral,
        uint256 repayAmount
    ) external view returns (uint256, uint256) {
        /* Read oracle prices for borrowed and collateral markets */
        uint256 priceBorrowedMantissa = oracle.getUnderlyingPrice(
            AToken(aTokenBorrowed)
        );
        uint256 priceCollateralMantissa = oracle.getUnderlyingPrice(
            AToken(aTokenCollateral)
        );
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint256(Error.PRICE_ERROR), 0);
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = repayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = repayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint256 exchangeRateMantissa = AToken(aTokenCollateral)
            .exchangeRateStored(); // Note: reverts on error
        uint256 seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;
        MathError mathErr;

        (mathErr, numerator) = mulExp(
            liquidationIncentiveMantissa,
            priceBorrowedMantissa
        );
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, denominator) = mulExp(
            priceCollateralMantissa,
            exchangeRateMantissa
        );
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, ratio) = divExp(numerator, denominator);
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, seizeTokens) = mulScalarTruncate(ratio, repayAmount);
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        return (uint256(Error.NO_ERROR), seizeTokens);
    }

    /*** Admin Functions ***/

    /**
     * @notice Sets a new price oracle for the comptroller
     * @dev Admin function to set a new price oracle
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setPriceOracle(PriceOracle newOracle) public returns (uint256) {
        // Check caller is admin OR currently initialzing as new unitroller implementation
        if (!adminOrInitializing()) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_PRICE_ORACLE_OWNER_CHECK
                );
        }

        // Track the old oracle for the comptroller
        PriceOracle oldOracle = oracle;

        // Ensure invoke newOracle.isPriceOracle() returns true
        // require(newOracle.isPriceOracle(), "oracle method isPriceOracle returned false");

        // Set comptroller's oracle to newOracle
        oracle = newOracle;

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(oldOracle, newOracle);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets the closeFactor used when liquidating borrows
     * @dev Admin function to set closeFactor
     * @param newCloseFactorMantissa New close factor, scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setCloseFactor(uint256 newCloseFactorMantissa)
        external
        returns (uint256)
    {
        // Check caller is admin OR currently initialzing as new unitroller implementation
        if (!adminOrInitializing()) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_CLOSE_FACTOR_OWNER_CHECK
                );
        }

        Exp memory newCloseFactorExp = Exp({mantissa: newCloseFactorMantissa});
        Exp memory lowLimit = Exp({mantissa: CLOSE_FACTOR_MIN_MANTISSA});
        if (lessThanOrEqualExp(newCloseFactorExp, lowLimit)) {
            return
                fail(
                    Error.INVALID_CLOSE_FACTOR,
                    FailureInfo.SET_CLOSE_FACTOR_VALIDATION
                );
        }

        Exp memory highLimit = Exp({mantissa: CLOSE_FACTOR_MAX_MANTISSA});
        if (lessThanExp(highLimit, newCloseFactorExp)) {
            return
                fail(
                    Error.INVALID_CLOSE_FACTOR,
                    FailureInfo.SET_CLOSE_FACTOR_VALIDATION
                );
        }

        uint256 oldCloseFactorMantissa = closeFactorMantissa;
        closeFactorMantissa = newCloseFactorMantissa;
        emit NewCloseFactor(oldCloseFactorMantissa, closeFactorMantissa);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets the collateralFactor for a market
     * @dev Admin function to set per-market collateralFactor
     * @param aToken The market to set the factor on
     * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setCollateralFactor(
        AToken aToken,
        uint256 newCollateralFactorMantissa
    ) external returns (uint256) {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_COLLATERAL_FACTOR_OWNER_CHECK
                );
        }

        // Verify market is listed
        Market storage market = markets[address(aToken)];
        if (!market.isListed) {
            return
                fail(
                    Error.MARKET_NOT_LISTED,
                    FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS
                );
        }

        Exp memory newCollateralFactorExp = Exp({
            mantissa: newCollateralFactorMantissa
        });

        // Check collateral factor <= 0.9
        Exp memory highLimit = Exp({mantissa: COLLATERAL_FACTOR_MAX_MANTISSA});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return
                fail(
                    Error.INVALID_COLLATERAL_FACTOR,
                    FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION
                );
        }

        // If collateral factor != 0, fail if price == 0
        if (
            newCollateralFactorMantissa != 0 &&
            oracle.getUnderlyingPrice(aToken) == 0
        ) {
            return
                fail(
                    Error.PRICE_ERROR,
                    FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE
                );
        }

        // Set market's collateral factor to new collateral factor, remember old value
        uint256 oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = newCollateralFactorMantissa;

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(
            aToken,
            oldCollateralFactorMantissa,
            newCollateralFactorMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets maxAssets which controls how many markets can be entered
     * @dev Admin function to set maxAssets
     * @param newMaxAssets New max assets
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setMaxAssets(uint256 newMaxAssets) external returns (uint256) {
        // Check caller is admin OR currently initialzing as new unitroller implementation
        if (!adminOrInitializing()) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_MAX_ASSETS_OWNER_CHECK
                );
        }

        uint256 oldMaxAssets = maxAssets;
        maxAssets = newMaxAssets;
        emit NewMaxAssets(oldMaxAssets, newMaxAssets);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets liquidationIncentive
     * @dev Admin function to set liquidationIncentive
     * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa)
        external
        returns (uint256)
    {
        // Check caller is admin OR currently initialzing as new unitroller implementation
        if (!adminOrInitializing()) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK
                );
        }

        // Check de-scaled 1 <= newLiquidationDiscount <= 1.5
        Exp memory newLiquidationIncentive = Exp({
            mantissa: newLiquidationIncentiveMantissa
        });
        Exp memory minLiquidationIncentive = Exp({
            mantissa: LIQUIDATION_INCENTIVE_MIN_MANTISSA
        });
        if (lessThanExp(newLiquidationIncentive, minLiquidationIncentive)) {
            return
                fail(
                    Error.INVALID_LIQUIDATION_INCENTIVE,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION
                );
        }

        Exp memory maxLiquidationIncentive = Exp({
            mantissa: LIQUIDATION_INCENTIVE_MAX_MANTISSA
        });
        if (lessThanExp(maxLiquidationIncentive, newLiquidationIncentive)) {
            return
                fail(
                    Error.INVALID_LIQUIDATION_INCENTIVE,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION
                );
        }

        // Save current value for use in log
        uint256 oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;

        // Set liquidation incentive to new incentive
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(
            oldLiquidationIncentiveMantissa,
            newLiquidationIncentiveMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Add the market to the markets mapping and set it as listed
     * @dev Admin function to set isListed and add support for the market
     * @param aToken The address of the market (token) to list
     * @return uint 0=success, otherwise a failure. (See enum Error for details)
     */
    function _supportMarket(AToken aToken) external returns (uint256) {
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SUPPORT_MARKET_OWNER_CHECK
                );
        }

        if (markets[address(aToken)].isListed) {
            return
                fail(
                    Error.MARKET_ALREADY_LISTED,
                    FailureInfo.SUPPORT_MARKET_EXISTS
                );
        }

        aToken.isAToken(); // Sanity check to make sure its really a AToken

        Market storage market = markets[address(aToken)];
        market.isListed = true;
        market.collateralFactorMantissa = 0;

        emit MarketListed(aToken);

        return uint256(Error.NO_ERROR);
    }

    function _supportCollateralVault(
        address _vestingContractAddress,
        address _vaultAddress
    ) external returns (uint256) {
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SUPPORT_MARKET_OWNER_CHECK
                );
        }

        IVault _vault = IVault(_vaultAddress);
        require(_vault.admin() == admin, "Vault admin must also be admin");

        IVesting _vestingContract = IVesting(_vestingContractAddress);

        require(
            !vestingContractInfo[_vestingContract].isListed,
            "Vault already listed"
        );

        require(_vestingContract.isVesting(), "Vesting listed");
        require(_vault.isVault(), "Vault check");

        vestingContractInfo[_vestingContract] = VestingContractInfo({
            isListed: true,
            enabledAsCollateral: false,
            vault: address(_vault),
            unvestedTokenLiquidator: address(0),
            amountOwedToLiquidator: 0
        });

        return uint256(Error.NO_ERROR);
    }

    // function _become(Unitroller unitroller, PriceOracle _oracle, uint _closeFactorMantissa, uint _maxAssets, bool reinitializing) public {
    //     require(msg.sender == unitroller.admin(), "only unitroller admin can change brains");
    //     uint changeStatus = unitroller._acceptImplementation();

    //     require(changeStatus == 0, "change not authorized");

    //     if (!reinitializing) {
    //         ComptrollerG1 freshBrainedComptroller = ComptrollerG1(address(unitroller));

    //         // Ensure invoke _setPriceOracle() = 0
    //         uint err = freshBrainedComptroller._setPriceOracle(_oracle);
    //         require (err == uint(Error.NO_ERROR), "set price oracle error");

    //         // Ensure invoke _setCloseFactor() = 0
    //         err = freshBrainedComptroller._setCloseFactor(_closeFactorMantissa);
    //         require (err == uint(Error.NO_ERROR), "set close factor error");

    //         // Ensure invoke _setMaxAssets() = 0
    //         err = freshBrainedComptroller._setMaxAssets(_maxAssets);
    //         require (err == uint(Error.NO_ERROR), "set max asssets error");

    //         // Ensure invoke _setLiquidationIncentive(LIQUIDATION_INCENTIVE_MIN_MANTISSA) = 0
    //         err = freshBrainedComptroller._setLiquidationIncentive(LIQUIDATION_INCENTIVE_MIN_MANTISSA);
    //         require (err == uint(Error.NO_ERROR), "set liquidation incentive error");
    //     }
    // }

    /**
     * @dev Check that caller is admin or this contract is initializing itself as
     * the new implementation.
     * There should be no way to satisfy msg.sender == comptrollerImplementaiton
     * without tx.origin also being admin, but both are included for extra safety
     */
    function adminOrInitializing() internal view returns (bool) {
        bool initializing = (msg.sender == comptrollerImplementation &&
            //solium-disable-next-line security/no-tx-origin
            tx.origin == admin);
        bool isAdmin = msg.sender == admin;
        return isAdmin || initializing;
    }
}
