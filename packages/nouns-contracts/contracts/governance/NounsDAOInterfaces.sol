// SPDX-License-Identifier: BSD-3-Clause

/// @title Nouns DAO Logic interfaces and events

// LICENSE
// NounsDAOInterfaces.sol 是 Compound Lab 的 GovernorBravoInterfaces.sol 的修改版本：
// https://github.com/compound-finance/compound-protocol/blob/b9b14038612d846b83f8a009a82c38974ff2dcfe/contracts/Governance/GovernorBravoInterfaces.sol
//
// GovernorBravoInterfaces.sol 源代码 版权所有 2020 Compound Labs, Inc.，根据 BSD-3-Clause 许可进行许可。 
// 由 Nounders DAO 修改。 
// 
// BSD-3-Clause 的附加条件可以在这里找到： https://opensource.org/licenses/BSD-3-Clause 
// 
// 修改 
// NounsDAOEvents、 NounsDAOProxyStorage、 NounsDAOStorageV1 添加了对 由名词 DAO 到 GovernorBravo.sol 
// 有关更多详细信息，请参见 NounsDAOLogicV1.sol。

pragma solidity ^0.8.6;

contract NounsDAOEvents {
    /// @notice 创建新提案时发出的事件
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    event ProposalCreatedWithRequirements(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        uint256 proposalThreshold,
        uint256 quorumVotes,
        string description
    );

    /// @notice 对提案进行投票时发出的事件 
    /// @param voter 投票的地址 
    /// @param proposalId 被投票的提案 ID 
    /// @param support 支持值投票。 0=反对, 1=赞成, 2=弃权 
    /// @param votes 投票者投票数 
    /// @param reason 投票者给出的投票理由
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

    /// @notice 取消提案时发出的事件
    event ProposalCanceled(uint256 id);

    /// @notice 当提案在 NounsDAOExecutor 中排队时发出的事件
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice 在 NounsDAOExecutor 中执行 提案时 发出的事件
    event ProposalExecuted(uint256 id);

    /// @notice An event emitted when a proposal has been vetoed by vetoAddress
    event ProposalVetoed(uint256 id);

    /// @notice 设置投票延迟时发出的事件
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// @notice 设置投票周期时发出的事件
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /// @notice 当实现改变时发出
    event NewImplementation(address oldImplementation, address newImplementation);

    /// @notice Emitted when proposal threshold basis points is set
    event ProposalThresholdBPSSet(uint256 oldProposalThresholdBPS, uint256 newProposalThresholdBPS);

    /// @notice Emitted when quorum votes basis points is set
    event QuorumVotesBPSSet(uint256 oldQuorumVotesBPS, uint256 newQuorumVotesBPS);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Emitted when vetoer is changed
    event NewVetoer(address oldVetoer, address newVetoer);
}

contract NounsDAOProxyStorage {
    /// @notice 本合同的管理员
    address public admin;

    /// @notice 此合同的待定管理员
    address public pendingAdmin;

    /// @notice Active brains of Governor
    address public implementation;
}

/**
 * @title 州长 Bravo 代表的存储 
 * @notice 对于未来的升级，不要更改 NounsDAOStorageV1。 创建一个实现 NounsDAOStorageV1 并遵循命名约定 NounsDAOStorageVX 的新合约。
 */
contract NounsDAOStorageV1 is NounsDAOProxyStorage {
    /// @notice 有权否决任何提案的否决者
    address public vetoer;

    /// @notice 对提案进行投票前的延迟，一旦提出，可能会分批进行
    uint256 public votingDelay;

    /// @notice 对提案进行投票的持续时间，以区块为单位
    uint256 public votingPeriod;

    /// @notice 投票人成为提议人所需的 投票数。  *与 GovernerBravo 不同
    uint256 public proposalThresholdBPS;

    /// @notice 为了达到 法定人数 并 投票成功 所需的支持提案的 票数。 * 与 GovernerBravo 不同
    uint256 public quorumVotesBPS;

    /// @notice 提案总数
    uint256 public proposalCount;

    /// @notice Nouns DAO Executor 的地址 NounsDAOExecutor
    INounsDAOExecutor public timelock;

    /// @notice Nouns tokens 的地址
    NounsTokenLike public nouns;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice 每个提案人的最新提案
    mapping(address => uint256) public latestProposalIds;

    struct Proposal {
        /// @notice 用于查找提案的唯一 ID
        uint256 id;
        /// @notice 提案的创建者
        address proposer;
        /// @notice 创建提案时创建提案所需的票数。 *与GovernerBravo 不同
        uint256 proposalThreshold;
        /// @notice 为了达到法定人数并在提案创建时投票成功所需的支持提案的票数。 *与GovernerBravo 不同
        uint256 quorumVotes;
        /// @notice 提案可用于执行的时间戳，在投票成功后设置
        uint256 eta;
        /// @notice 要进行调用的目标地址的有序列表
        address[] targets;
        /// @notice 要传递给要进行的调用的有序值列表（即 msg.value）
        uint256[] values;
        /// @notice 要调用的函数签名的有序列表
        string[] signatures;
        /// @notice 要传递给每个调用的调用数据的有序列表
        bytes[] calldatas;
        /// @notice 投票开始的区块：持有人必须在该区块之前委托他们的投票
        uint256 startBlock;
        /// @notice 投票结束的区块： 必须在该区块之前投票
        uint256 endBlock;
        /// @notice 目前赞成该提案的票数
        uint256 forVotes;
        /// @notice 目前反对该提案的票数
        uint256 againstVotes;
        /// @notice 目前对该提案弃权的票数
        uint256 abstainVotes;
        /// @notice 标记提案是否已被取消的标志
        bool canceled;
        /// @notice 标记提案是否被否决的标志
        bool vetoed;
        /// @notice 标记提案是否已执行的标志
        bool executed;
        /// @notice 全体选民的选票收据
        mapping(address => Receipt) receipts;
    }

    /// @notice 选民的选票收据记录
    struct Receipt {
        /// @notice 是否已投票
        bool hasVoted;
        /// @notice 选民是否支持或弃权
        uint8 support;
        /// @notice 选民的票数，已投
        uint96 votes;
    }

    /// @notice 提案可能处于的可能状态
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed
    }
}

interface INounsDAOExecutor {
    function delay() external view returns (uint256);

    function GRACE_PERIOD() external view returns (uint256);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}

interface NounsTokenLike {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function totalSupply() external view returns (uint96);
}
