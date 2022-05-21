// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns ERC-721 token

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

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ERC721Checkpointable } from './base/ERC721Checkpointable.sol';
import { INounsDescriptor } from './interfaces/INounsDescriptor.sol';
import { INounsSeeder } from './interfaces/INounsSeeder.sol';
import { INounsToken } from './interfaces/INounsToken.sol';
import { ERC721 } from './base/ERC721.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';

contract NounsToken is INounsToken, Ownable, ERC721Checkpointable {
    // nounders DAO 地址（creators org）
    address public noundersDAO;

    // 有权铸造 Nouns Token 的地址
    address public minter;

    // URI 描述符
    INounsDescriptor public descriptor;

    // The Nouns token seeder
    INounsSeeder public seeder;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // 描述符是否可以更新
    bool public isDescriptorLocked;

    // 播种机是否可以更新
    bool public isSeederLocked;

    // 名词种子
    mapping(uint256 => INounsSeeder.Seed) public seeds;

    // The internal noun ID tracker
    uint256 private _currentNounId;

    // IPFS content hash of contract-level metadata
    string private _contractURIHash = 'QmZi1n79FqWt2tTLwCqiy6nLM6xLGRsEPQ5JmReJQKNNzX';

    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    /**
     * @notice 要求描述符没有被锁定。
     */
    modifier whenDescriptorNotLocked() {
        require(!isDescriptorLocked, 'Descriptor is locked');
        _;
    }

    /**
     * @notice 要求播种机没有被锁定。
     */
    modifier whenSeederNotLocked() {
        require(!isSeederLocked, 'Seeder is locked');
        _;
    }

    /**
     * @notice 要求发送者是名词者 DAO
     */
    modifier onlyNoundersDAO() {
        require(
            msg.sender == noundersDAO, 
            'Sender is not the nounders DAO'
        );
        _;
    }

    /**
     * @notice 要求发件人是铸币者。
     */
    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    constructor(
        address _noundersDAO,
        address _minter,
        INounsDescriptor _descriptor,
        INounsSeeder _seeder,
        IProxyRegistry _proxyRegistry
    ) ERC721('Nouns', 'NOUN') {
        noundersDAO = _noundersDAO;
        minter = _minter;
        descriptor = _descriptor;
        seeder = _seeder;
        proxyRegistry = _proxyRegistry;
    }

    /**
     * @notice 合约级元数据的 IPFS URI
     */
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked('ipfs://', _contractURIHash));
    }

    /**
     * @notice 设置 _contractURIHash。 
     * @dev 只能由所有者调用。
     */
    function setContractURIHash(string memory newContractURIHash) external onlyOwner {
        _contractURIHash = newContractURIHash;
    }

    /**
     * @notice 覆盖 isApprovedForAll 以将用户的 OpenSea 代理帐户列入白名单以启用无气体列表。
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // 将 OpenSea 代理合约列入白名单以方便交易.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice 向铸币者 铸造一个 noun nft 
     * 其中，每 10 个 noun nft 向 noundersDAO 奖励一个 NFT， 从 0 开始， 直到铸造了 183 个 NFT（5 年， 24 小时拍卖） 
     * @dev 使用收件人地址调用 _mintTo
     */
    function mint() public override onlyMinter returns (uint256) {
        if (_currentNounId <= 1820 && _currentNounId % 10 == 0) {
            _mintTo(noundersDAO, _currentNounId++);
        }
        return _mintTo(minter, _currentNounId++);
    }

    /**
     * @notice 烧一个名词
     */
    function burn(uint256 nounId) public override onlyMinter {
        _burn(nounId);
        emit NounBurned(nounId);
    }

    /**
     * @notice 给定资产的不同统一资源标识符 (URI)。 
     * @dev 请参阅 {IERC721Metadata-tokenURI}。
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'NounsToken: URI query for nonexistent token');
        return descriptor.tokenURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice 类似于 `tokenURI`，但始终提供 base64 编码的数据 URI 直接内联 JSON 内容。
     */
    function dataURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'NounsToken: URI query for nonexistent token');
        return descriptor.dataURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice 设置 Nouns DAO。 
     * @dev 只有在未锁定时才可由名词 DAO 调用。
     */
    function setNoundersDAO(address _noundersDAO) external override onlyNoundersDAO {
        noundersDAO = _noundersDAO;

        emit NoundersDAOUpdated(_noundersDAO);
    }

    /**
     * @notice 设置代币生成器。 
     * @dev 只有在未被锁定时才可由所有者调用。
     */
    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    /**
     * @notice 锁定铸币厂。 
     * @dev 这不能逆转，只有在未锁定时才能由所有者调用。
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit MinterLocked();
    }

    /**
     * @notice 设置令牌 URI 描述符。 
     * @dev 只有在未被锁定时才可由所有者调用。
     */
    function setDescriptor(INounsDescriptor _descriptor) external override onlyOwner whenDescriptorNotLocked {
        descriptor = _descriptor;

        emit DescriptorUpdated(_descriptor);
    }

    /**
     * @notice 锁定描述符
     * @dev 这不能逆转， 只有在未锁定时才能由所有者调用
     */
    function lockDescriptor() external override onlyOwner whenDescriptorNotLocked {
        isDescriptorLocked = true;

        emit DescriptorLocked();
    }

    /**
     * @notice 设置 token 播种者
     * @dev 只有在 未被锁定时 才可由所有者调用
     */
    function setSeeder(INounsSeeder _seeder) external override onlyOwner whenSeederNotLocked {
        seeder = _seeder;

        emit SeederUpdated(_seeder);
    }

    /**
     * @notice 锁定播种机 
     * @dev 这不能逆转，只有在未锁定时才能由所有者调用
     */
    function lockSeeder() external override onlyOwner whenSeederNotLocked {
        isSeederLocked = true;

        emit SeederLocked();
    }

    /**
     * @notice 将带有 `nounId` 的 nft 添加到提供的 `to` 地址
     */
    function _mintTo(address to, uint256 nounId) internal returns (uint256) {
        
        INounsSeeder.Seed memory seed = seeds[nounId] = seeder.generateSeed(nounId, descriptor);

        _mint(owner(), to, nounId);
        emit NounCreated(nounId, seed);

        return nounId;
    }
}
