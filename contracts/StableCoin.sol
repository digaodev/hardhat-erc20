//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {ERC20} from "./ERC20.sol";
import {DepositorCoin} from "./DepositorCoin.sol";
import {Oracle} from "./Oracle.sol";
import {WadLib} from "./WadLib.sol";

contract StableCoin is ERC20 {
    using WadLib for uint256;
    DepositorCoin public depositorCoin;
    Oracle public oracle;
    uint256 public feeRatePercentage;
    uint256 public constant INITIAL_COLLATERAL_RATIO_PERCENTAGE = 10;
    error InitialCollateralRatioError(
        string message,
        uint256 minimumDepositAmount
    );

    constructor(uint256 _feeRatePercentage, Oracle _oracle)
        ERC20("StableCoin", "STC")
    {
        feeRatePercentage = _feeRatePercentage;
        oracle = _oracle;
    }

    function mint() external payable {
        uint256 fee = _getFee(msg.value);
        uint256 remainingEth = msg.value - fee;
        // stable coin pegged to USD
        uint256 mintStableCoinAmount = remainingEth * oracle.getPrice();

        _mint(msg.sender, mintStableCoinAmount);
    }

    function _getFee(uint256 ethAmount) private view returns (uint256) {
        bool hasDepositors = address(depositorCoin) != address(0) &&
            depositorCoin.totalSupply() > 0;

        if (!hasDepositors) {
            return 0;
        }

        return (feeRatePercentage * ethAmount) / 100;
    }

    function burn(uint256 burnStableCoinAmount) external {
        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();

        require(
            deficitOrSurplusInUsd >= 0,
            "STC: cannot burn while in deficit"
        );

        _burn(msg.sender, burnStableCoinAmount);

        uint256 refundingEth = burnStableCoinAmount / oracle.getPrice();
        uint256 fee = _getFee(refundingEth);
        uint256 remainingRefundingEth = refundingEth - fee;

        (bool success, ) = msg.sender.call{value: remainingRefundingEth}("");
        require(success, "STC: burn refund failed");
    }

    function _getDeficitOrSurplusInContractInUsd()
        private
        view
        returns (int256)
    {
        uint256 ethContractBalanceInUsd = (address(this).balance - msg.value) *
            oracle.getPrice();

        uint256 totalStableCoinBalanceUsd = totalSupply;

        int256 deficitOrSurplus = int256(ethContractBalanceInUsd) -
            int256(totalStableCoinBalanceUsd);

        return deficitOrSurplus;
    }

    function _getDpcInUsdPrice(uint256 surplusInUsd)
        private
        view
        returns (WadLib.Wad)
    {
        return WadLib.fromFraction(depositorCoin.totalSupply(), surplusInUsd);
    }

    function depositCollateralBuffer() external payable {
        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();

        if (deficitOrSurplusInUsd <= 0) {
            uint256 deficitInUsd = uint256(deficitOrSurplusInUsd * -1);
            uint256 usdInEthPrice = oracle.getPrice();
            uint256 deficitInEth = deficitInUsd / usdInEthPrice;

            uint256 requiredInitialSurplusInUsd = (INITIAL_COLLATERAL_RATIO_PERCENTAGE *
                    totalSupply) / 100;
            uint256 requiredInitialSurplusInEth = requiredInitialSurplusInUsd /
                usdInEthPrice;

            if (msg.value < deficitInEth + requiredInitialSurplusInEth) {
                uint256 minimumDepositAmount = deficitInEth +
                    requiredInitialSurplusInEth;

                revert InitialCollateralRatioError(
                    "STC: unmet initial collateral, minimum is",
                    minimumDepositAmount
                );
            }

            uint256 newInitialSurplusInEth = msg.value - deficitInEth;
            uint256 newInitialSurplusInUsd = newInitialSurplusInEth *
                usdInEthPrice;

            depositorCoin = new DepositorCoin();
            uint256 mintDepositorCoinAmount = newInitialSurplusInUsd;
            depositorCoin.mint(msg.sender, mintDepositorCoinAmount);

            return;
        }

        uint256 surplusInUsd = uint256(deficitOrSurplusInUsd);

        WadLib.Wad dpcInUsdPrice = _getDpcInUsdPrice(surplusInUsd);

        uint256 mintDepositorCoinAmount = ((msg.value.mulWad(dpcInUsdPrice)) /
            oracle.getPrice());

        depositorCoin.mint(msg.sender, mintDepositorCoinAmount);
    }

    function withdrawCollateralBuffer(uint256 burnDepositorCoinAmount)
        external
    {
        require(
            depositorCoin.balanceOf(msg.sender) >= burnDepositorCoinAmount,
            "STC: insufficient DPC funds for sender"
        );

        depositorCoin.burn(msg.sender, burnDepositorCoinAmount);

        int256 deficitOrSurplus = _getDeficitOrSurplusInContractInUsd();

        require(deficitOrSurplus > 0, "STC: no funds to withdraw");

        uint256 surplusInUsd = uint256(deficitOrSurplus);
        WadLib.Wad dpcInUsdPrice = _getDpcInUsdPrice(surplusInUsd);
        uint256 refundInUsd = burnDepositorCoinAmount.mulWad(dpcInUsdPrice);
        uint256 refundInEth = refundInUsd / oracle.getPrice();

        (bool success, ) = msg.sender.call{value: refundInEth}("");

        require(success, "STC: withdraw refund transaction failed");
    }
}
