// SPDX-License-Identifier: MIT

/// @title ERC721 Enumerable Extension

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
// ERC721.sol modifies OpenZeppelin's ERC721Enumerable.sol:
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6618f9f18424ade44116d0221719f4c93be6a078/contracts/token/ERC721/extensions/ERC721Enumerable.sol
//
// ERC721Enumerable.sol 源代码版权所有 OpenZeppelin 在 MIT 许可下许可。 
// 由 Nounders DAO 修改。 
// 
// 修改： 
// 使用修改后的 `ERC721` 合约。请参阅 `ERC721.sol` 中的注释。

pragma solidity ^0.8.0;

import './ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';

/**
 * @dev 这实现了 EIP 中定义的 {ERC721} 的可选扩展， 它增加了合约中所有代币 ID 的 可枚举性 以及 每个账户拥有的 所有 token ID
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    
    // Mapping from owner to list of owned token IDs: owner --> owned token Index --> tokenId
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // token ID --> index
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // 包含所有 令牌 ID 的数组， 用于枚举
    uint256[] private _allTokens;

    // 从 token id 映射到 allTokens 数组中的位置
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), 'ERC721Enumerable: owner index out of bounds');
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), 'ERC721Enumerable: global index out of bounds');
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev 私有函数，用于向此扩展的所有权跟踪数据结构添加令牌
     * @param to address 表示给定令牌 ID 的新所有者 
     * @param tokenId uint256 要添加到 给定地址的令牌列表中的 令牌 ID
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokensIndex[tokenId] = length;

        _ownedTokens[to][length] = tokenId;
    }

    /**
     * @dev 私有函数，用于向此扩展的令牌跟踪数据结构添加令牌 
     * @param tokenId uint256 要添加到令牌列表的令牌的 ID
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev 私有函数，用于从此扩展的所有权跟踪数据结构中删除令牌。请注意 虽然没有为代币分配新所有者， 但 `_ownedTokensIndex` 映射_未_更新 ：
     * 这允许 气体优化，例如执行传输操作时（避免双重写入） 
     * 这具有 O(1) 时间复杂度，但会改变 _ownedTokens 数组的顺序
     * @param from address 代表给定令牌 ID 的先前所有者 
     * @param tokenId uint256 要从给定地址的令牌列表中删除的令牌的 ID
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // 为了防止 from 的 tokens 数组出现间隙， 我们将最后一个 token 存储在要删除的 token 的索引中，然后删除最后一个 slot（swap 和 pop）。

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // 当要删除的token是最后一个token时，不需要 swap 操作
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // 将最后一个令牌移动到要删除令牌的槽中
            _ownedTokensIndex[lastTokenId] = tokenIndex; // 更新移动令牌的索引
        }

        // 这也删除了数组最后一个位置的内容
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
    * @dev 用于从该扩展的标记跟踪数据结构中删除标记的私有函数。这具有 O(1) 时间复杂度，但会改变 _allTokens 数组的顺序。 
    * @param tokenId uint256 要从令牌列表中删除的令牌的 ID
   */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // 为了防止令牌数组中出现间隙，我们将最后一个令牌存储在要删除的令牌的索引中, 然后删除最后一个插槽（交换和弹出）。

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // 当要删除的 token 是最后一个 token 时， 不需要 swap 操作。
        // 然而，由于这种情况很少发生（当最后一个铸造的代币被烧毁时）， 我们仍然在这里进行交换以避免添加 
        // 'if' 语句的气体成本（如在 _removeTokenFromOwnerEnumeration 中）
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // 将最后一个令牌移动到要删除令牌的槽中
        _allTokensIndex[lastTokenId] = tokenIndex; // 更新移动令牌的索引

        // 这也删除了数组最后一个位置的内容
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}
