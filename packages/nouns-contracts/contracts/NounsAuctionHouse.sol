// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns DAO auction house

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

// LICENSE
// NounsAuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// AuctionHouse.sol 源代码 版权所有 Zora 在 GPL-3.0 许可下许可。 
// 由 Nounders DAO 修改。

pragma solidity ^0.8.6;

import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import { INounsAuctionHouse } from './interfaces/INounsAuctionHouse.sol';
import { INounsToken } from './interfaces/INounsToken.sol';
import { IWETH } from './interfaces/IWETH.sol';

contract NounsAuctionHouse is INounsAuctionHouse, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    // 名词 ERC721 代币合约
    INounsToken public nouns;

    // WETH合约地址
    address public weth;

    // 创建新出价后 拍卖中剩余的最短时间
    uint256 public timeBuffer;

    // 拍卖中接受的最低价格
    uint256 public reservePrice;

    // 上次出价与当前出价之间的最小百分比差异
    uint8 public minBidIncrementPercentage;

    // 单次拍卖的持续时间
    uint256 public duration;

    // 主动拍卖
    INounsAuctionHouse.Auction public auction;

    /**
     * @notice 初始化拍卖行和基础合约，填充配置值，并暂停合约
     * @dev 这个函数只能被调用一次
     */
    function initialize(
        INounsToken _nouns,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();

        _pause();

        nouns = _nouns;
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
    }

    /**
     * @notice 解决当前的拍卖，创造一个新的名词，然后将其拍卖
     */
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice 解决当前的拍卖
     * @dev 该函数只能在合约暂停时调用
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice 为给定数量的名词创建 出价。 
     * @dev 此合约仅接受 ETH 付款。
     */
    function createBid(uint256 nounId) external payable override nonReentrant {

        INounsAuctionHouse.Auction memory _auction = auction;
        
        // nft 未拍卖
        require(
            _auction.nounId == nounId, 
            'Noun not up for auction'
        );
        // 拍卖已过期
        require(
            block.timestamp < _auction.endTime, 
            'Auction expired'
        );
        // 底价
        require(
            msg.value >= reservePrice, 
            'Must send at least reservePrice'
        );
        // 出价 必须比 上次出价多 minBidIncrementPercentage 金额 （出价最少需要增加的百分比） 
        require(
            msg.value >= _auction.amount + ((_auction.amount * minBidIncrementPercentage) / 100),
            'Must send more than last bid by minBidIncrementPercentage amount'
        );

        address payable lastBidder = _auction.bidder;

        // 退还最后一位投标人
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // 如果在拍卖结束时间的 `timeBuffer` 内收到出价， 则延长拍卖
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.nounId, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.nounId, _auction.endTime);
        }
    }

    /**
     * @notice 暂停名词拍卖行。 
     * @dev 这个函数只能在合约未暂停时被所有者调用。虽然暂停时无法开始新的拍卖，但任何人都可以解决正在进行的拍卖。
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice 取消暂停名词拍卖行。 
     * @dev 这个函数只能在合约暂停时被所有者调用。如果需要，此功能将启动新的拍卖。
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /**
     * @notice 设置拍卖时间缓冲区。 
     * @dev 只能由所有者调用。
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice 设置拍卖底价。 
     * @dev 只能由所有者调用。
     */
    function setReservePrice(uint256 _reservePrice) external override onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice 设置拍卖最低出价增量百分比。 
     * @dev 只能由所有者调用。
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external override onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    /**
     * @notice 创建拍卖。 
     * @dev 将拍卖详情存储在 `auction` 状态变量中并发出 AuctionCreated 事件。 
     * 如果铸币厂恢复，铸币厂在没有先暂停此合约的情况下更新。为了解决这个问题，捕获还原并暂停此合同。
     */
    function _createAuction() internal {
        try nouns.mint() returns (uint256 nounId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({
                nounId: nounId,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            emit AuctionCreated(nounId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice 进行拍卖，最终确定出价 并支付给所有者。 
     * @dev 如果没有出价，名词被烧毁。
     */
    function _settleAuction() internal {
        INounsAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, 'Auction has already been settled');
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            nouns.burn(_auction.nounId);
        } else {
            nouns.transferFrom(address(this), _auction.bidder, _auction.nounId);
        }

        if (_auction.amount > 0) {
            _safeTransferETHWithFallback(owner(), _auction.amount);
        }

        emit AuctionSettled(_auction.nounId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice 转移 ETH。 如果 ETH 传输失败，将 ETH 打包并尝试将其作为 WETH 发送。
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice 转账 ETH 并返回成功状态。 
     * @dev 此函数仅将 30,000 gas 转发给被调用者
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}
