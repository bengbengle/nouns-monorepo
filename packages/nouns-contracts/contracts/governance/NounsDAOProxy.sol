// SPDX-License-Identifier: BSD-3-Clause

/// @title The Nouns DAO proxy contract

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
// NounsDAOProxy.sol is a modified version of Compound Lab's GovernorBravoDelegator.sol:
// https://github.com/compound-finance/compound-protocol/blob/b9b14038612d846b83f8a009a82c38974ff2dcfe/contracts/Governance/GovernorBravoDelegator.sol
//
// GovernorBravoDelegator.sol 源代码 版权所有 2020 Compound Labs, Inc.，根据 BSD-3-Clause 许可进行许可。 
// 由 Nounders DAO 修改。 
// 
// BSD-3-Clause 的附加条件可以在这里找到：https://opensource.org/licenses/BSD-3-Clause 
// 
// 
// NounsDAOProxy.sol 使用了 Open Zeppelin 的 Proxy.sol 的一部分： 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5c8746f56b4bed8cc9e0e044f5f69ab2f9428ce1/contracts/proxy/Proxy.sol 
// 
// Proxy.sol 源代码在 MIT 许可下授权。 
// 
// 修改 
// Proxy.sol 的 fallback() 和 receive() 函数已用于允许 Solidity > 0.6.0 兼容性

pragma solidity ^0.8.6;

import './NounsDAOInterfaces.sol';

contract NounsDAOProxy is NounsDAOProxyStorage, NounsDAOEvents {
    constructor(
        address timelock_,
        address nouns_,
        address vetoer_,
        address admin_,
        address implementation_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThresholdBPS_,
        uint256 quorumVotesBPS_
    ) {
        // 管理员设置为 msg.sender 进行初始化
        admin = msg.sender;

        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                'initialize(address,address,address,uint256,uint256,uint256,uint256)',
                timelock_,
                nouns_,
                vetoer_,
                votingPeriod_,
                votingDelay_,
                proposalThresholdBPS_,
                quorumVotesBPS_
            )
        );

        _setImplementation(implementation_);

        admin = admin_;
    }

    /**
     * @notice 由管理员调用以更新委托者的实现 
     * @param implementation_ 委托的新实现的地址
     */
    function _setImplementation(address implementation_) public {
        require(msg.sender == admin, 'NounsDAOProxy::_setImplementation: admin only');
        require(implementation_ != address(0), 'NounsDAOProxy::_setImplementation: invalid implementation address');

        address oldImplementation = implementation;
        implementation = implementation_;

        emit NewImplementation(oldImplementation, implementation);
    }

    /**
     * @notice 将 执行 委托 给另一个 合约 的 内部方法 
     * @dev 无论实现返回或转发还原， 它都会返回给外部调用者 
     * @param callee 委托调用的合约 
     * @param data 委托调用的原始数据
     */
    function delegateTo(address callee, bytes memory data) internal {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
    }

    /**
     * @dev 将执行委托给实现合同。 
     * 无论实现返回什么，它都会返回给外部调用者 或 forwards 还原。
     */
    function _fallback() internal {
        // 将所有其他功能委托给当前实现 
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
            case 0 {
                revert(free_mem_ptr, returndatasize())
            }
            default {
                return(free_mem_ptr, returndatasize())
            }
        }
    }

    /**
     * @dev 后备函数， 将调用委托给 “实现” 。 如果合约中没有其他函数与调用数据匹配，则将运行。
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev 将调用委托给“实现”的后备函数。如果呼叫数据为空，将运行
     */
    receive() external payable {
        _fallback();
    }
}
