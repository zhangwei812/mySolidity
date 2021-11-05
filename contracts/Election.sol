pragma solidity ^0.5.13;

import "./openzeppelin-solidity/contracts/math/Math.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./IValidators.sol";
import "./Initializable.sol";
import "./FixidityLib.sol";
import "./Heap.sol";
import "./ReentrancyGuard.sol";
import "./IAccounts.sol";
import "./IRegistry.sol";
import "./ILockedGold.sol";
import "./SortedLinkedList.sol";

import "./Console.sol";
import "./IValidators2.sol";

library AddressSortedLinkedList {
    using SafeMath for uint256;
    using SortedLinkedList for SortedLinkedList.List;

    function toBytes(address a) public pure returns (bytes32) {
        return bytes32(uint256(a) << 96);
    }

    function toAddress(bytes32 b) public pure returns (address) {
        return address(uint256(b) >> 96);
    }

    /**
     * @notice Inserts an element into a doubly linked list.
     * @param list A storage pointer to the underlying list.
     * @param key The key of the element to insert.
     * @param value The element value.
     * @param lesserKey The key of the element less than the element to insert.
     * @param greaterKey The key of the element greater than the element to insert.
     */
    function insert(
        SortedLinkedList.List storage list,
        address key,
        uint256 value,
        address lesserKey,
        address greaterKey
    ) public {
        list.insert(toBytes(key), value, toBytes(lesserKey), toBytes(greaterKey));
    }

    /**
     * @notice Removes an element from the doubly linked list.
     * @param list A storage pointer to the underlying list.
     * @param key The key of the element to remove.
     */
    function remove(SortedLinkedList.List storage list, address key) public {
        list.remove(toBytes(key));
    }

    /**
     * @notice Updates an element in the list.
     * @param list A storage pointer to the underlying list.
     * @param key The element key.
     * @param value The element value.
     * @param lesserKey The key of the element will be just left of `key` after the update.
     * @param greaterKey The key of the element will be just right of `key` after the update.
     * @dev Note that only one of "lesserKey" or "greaterKey" needs to be correct to reduce friction.
     */
    function update(
        SortedLinkedList.List storage list,
        address key,
        uint256 value,
        address lesserKey,
        address greaterKey
    ) public {
        list.update(toBytes(key), value, toBytes(lesserKey), toBytes(greaterKey));
    }

    /**
     * @notice Returns whether or not a particular key is present in the sorted list.
     * @param list A storage pointer to the underlying list.
     * @param key The element key.
     * @return Whether or not the key is in the sorted list.
     */
    function contains(SortedLinkedList.List storage list, address key) public view returns (bool) {
        return list.contains(toBytes(key));
    }

    /**
     * @notice Returns the value for a particular key in the sorted list.
     * @param list A storage pointer to the underlying list.
     * @param key The element key.
     * @return The element value.
     */
    function getValue(SortedLinkedList.List storage list, address key) public view returns (uint256) {
        return list.getValue(toBytes(key));
    }

    /**
     * @notice Gets all elements from the doubly linked list.
     * @return An unpacked list of elements from largest to smallest.
     */
    function getElements(SortedLinkedList.List storage list)
    public
    view
    returns (address[] memory, uint256[] memory)
    {
        bytes32[] memory byteKeys = list.getKeys();
        address[] memory keys = new address[](byteKeys.length);
        uint256[] memory values = new uint256[](byteKeys.length);
        for (uint256 i = 0; i < byteKeys.length; i = i.add(1)) {
            keys[i] = toAddress(byteKeys[i]);
            values[i] = list.values[byteKeys[i]];
        }
        return (keys, values);
    }

    /**
     * @notice Returns the minimum of `max` and the  number of elements in the list > threshold.
     * @param list A storage pointer to the underlying list.
     * @param threshold The number that the element must exceed to be included.
     * @param max The maximum number returned by this function.
     * @return The minimum of `max` and the  number of elements in the list > threshold.
     */
    function numElementsGreaterThan(
        SortedLinkedList.List storage list,
        uint256 threshold,
        uint256 max
    ) public view returns (uint256) {
        uint256 revisedMax = Math.min(max, list.list.numElements);
        bytes32 key = list.list.head;
        for (uint256 i = 0; i < revisedMax; i = i.add(1)) {
            if (list.getValue(key) < threshold) {
                return i;
            }
            key = list.list.elements[key].previousKey;
        }
        return revisedMax;
    }

    /**
     * @notice Returns the N greatest elements of the list.
     * @param list A storage pointer to the underlying list.
     * @param n The number of elements to return.
     * @return The keys of the greatest elements.
     */
    function headN(SortedLinkedList.List storage list, uint256 n)
    public
    view
    returns (address[] memory)
    {
        bytes32[] memory byteKeys = list.headN(n);
        address[] memory keys = new address[](n);
        for (uint256 i = 0; i < n; i = i.add(1)) {
            keys[i] = toAddress(byteKeys[i]);
        }
        return keys;
    }

    /**
     * @notice Gets all element keys from the doubly linked list.
     * @param list A storage pointer to the underlying list.
     * @return All element keys from head to tail.
     */
    function getKeys(SortedLinkedList.List storage list) public view returns (address[] memory) {
        return headN(list, list.list.numElements);
    }
}

contract UsingRegistry is Ownable {
    event RegistrySet(address indexed registryAddress);

    // solhint-disable state-visibility
    bytes32 constant ACCOUNTS_REGISTRY_ID = keccak256(abi.encodePacked("Accounts"));

    bytes32 constant VALIDATORS_REGISTRY_ID = keccak256(abi.encodePacked("Validators"));
    bytes32 constant LOCKED_GOLD_REGISTRY_ID = keccak256(abi.encodePacked("LockedGold"));
    // solhint-enable state-visibility

    IRegistry public registry;



    /**
     * @notice Updates the address pointing to a Registry contract.
     * @param registryAddress The address of a registry contract for routing to other contracts.
     */
    function setRegistry(address registryAddress) public onlyOwner {
        require(registryAddress != address(0), "Cannot register the null address");
        registry = IRegistry(registryAddress);
        emit RegistrySet(registryAddress);
    }

    //-------------------
    function getAccounts() internal view returns (IAccounts) {
        return IAccounts(registry.getAddressForOrDie(ACCOUNTS_REGISTRY_ID));
    }

    //-------------------
    function getLockedGold() internal view returns (ILockedGold) {
        return ILockedGold(registry.getAddressForOrDie(LOCKED_GOLD_REGISTRY_ID));
    }

    //--------------------------
    function getValidators() internal view returns (IValidators2) {
        return IValidators2(registry.getAddressForOrDie(VALIDATORS_REGISTRY_ID));
    }
}

contract UsingPrecompiles {
    using SafeMath for uint256;
    address constant EPOCH_SIZE = address(0xff - 7);

    /**
     * @notice Returns the current epoch size in blocks.
     * @return The current epoch size in blocks.
     */
    function getEpochSize() public view returns (uint256) {
        bytes memory out;
        bool success;
        (success, out) = EPOCH_SIZE.staticcall(abi.encodePacked());
        require(success, "error calling getEpochSize precompile");
        return getUint256FromBytes(out, 0);
    }

    function getUint256FromBytes(bytes memory bs, uint256 start) internal pure returns (uint256) {
        return uint256(getBytes32FromBytes(bs, start));
    }

    function getBytes32FromBytes(bytes memory bs, uint256 start) internal pure returns (bytes32) {
        require(bs.length >= start.add(32), "slicing out of range");
        bytes32 x;
        assembly {
            x := mload(add(bs, add(start, 32)))
        }
        return x;
    }

    //----------------
    function getEpochNumberOfBlock(uint256 blockNumber) public view returns (uint256) {
        return epochNumberOfBlock(blockNumber, getEpochSize());
    }

    //--------------
    function getEpochNumber() public view returns (uint256) {
        return getEpochNumberOfBlock(block.number);
    }

    //---------------------
    function epochNumberOfBlock(uint256 blockNumber, uint256 epochSize)
    internal
    pure
    returns (uint256)
    {
        // Follows GetEpochNumber from celo-blockchain/blob/master/consensus/istanbul/utils.go
        uint256 epochNumber = blockNumber / epochSize;
        if (blockNumber % epochSize == 0) {
            return epochNumber;
        } else {
            return epochNumber.add(1);
        }
    }
}

contract Election is
Ownable,
ReentrancyGuard,
Initializable,
UsingRegistry,
UsingPrecompiles,
Console
{
    using AddressSortedLinkedList for SortedLinkedList.List;
    using FixidityLib for FixidityLib.Fraction;
    using SafeMath for uint256;
    uint256 private constant UNIT_PRECISION_FACTOR = 100000000000000000000;
    IValidators2 public Validators2;


    struct PendingVote {
        uint256 value;
        uint256 epoch;
    }

    struct GroupPendingVotes {
        uint256 total;
        mapping(address => PendingVote) byAccount;
    }

    struct PendingVotes {
        uint256 total;
        mapping(address => GroupPendingVotes) forGroup;
    }

    struct GroupActiveVotes {
        uint256 total;
        uint256 totalUnits;
        mapping(address => uint256) unitsByAccount;
    }

    struct ActiveVotes {
        uint256 total;
        mapping(address => GroupActiveVotes) forGroup;
    }

    struct TotalVotes {
        SortedLinkedList.List eligible;
    }

    struct Votes {
        PendingVotes pending;
        ActiveVotes active;
        TotalVotes total;
        mapping(address => address[]) groupsVotedFor;
    }

    struct ElectableValidators {
        uint256 min;
        uint256 max;
    }

    Votes private votes;
    ElectableValidators public electableValidators;
    uint256 public maxNumGroupsVotedFor;
    FixidityLib.Fraction public electabilityThreshold;


    function initialize(
        address registryAddress
    ) external initializer {
        _transferOwnership(msg.sender);
        setRegistry(registryAddress);

    }

    /**
     * @notice Sets initialized == true on implementation contracts
     * @param test Set to true to skip implementation initialization
     */
    constructor(bool test) public Initializable(test) {}

    function vote(address group, uint256 value, address lesser, address greater)
    external
    returns (bool)
    {
        //        require(votes.total.eligible.contains(group), "Group not eligible");
        //        require(0 < value, "Vote value cannot be zero");
        //        //    address account = getAccounts().voteSignerToAccount(msg.sender);
        //        address account = msg.sender;
        //        // Add group to the groups voted for by the account.
        //        bool alreadyVotedForGroup = false;
        //        address[] storage groups = votes.groupsVotedFor[account];
        //        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
        //            alreadyVotedForGroup = alreadyVotedForGroup || groups[i] == group;
        //        }
        //        if (!alreadyVotedForGroup) {
        //            //      require(groups.length < maxNumGroupsVotedFor, "Voted for too many groups");
        //            groups.push(group);
        //        }

        //    incrementPendingVotes(group, account, value);
        //    incrementTotalVotes(group, value, lesser, greater);
        //    getLockedGold().decrementNonvotingAccountBalance(account, value);

        return true;
    }

    function incrementTotalVotes(address group, uint256 value, address lesser, address greater)
    private
    {
        uint256 newVoteTotal = votes.total.eligible.getValue(group).add(value);
        votes.total.eligible.update(group, newVoteTotal, lesser, greater);
    }

    function incrementPendingVotes(address group, address account, uint256 value) private {
        PendingVotes storage pending = votes.pending;
        pending.total = pending.total.add(value);

        GroupPendingVotes storage groupPending = pending.forGroup[group];
        groupPending.total = groupPending.total.add(value);

        PendingVote storage pendingVote = groupPending.byAccount[account];
        pendingVote.value = pendingVote.value.add(value);
        pendingVote.epoch = getEpochNumber();
    }


    function electValidatorSigners(address group) external  returns (address[] memory) {
        return getValidators().getGroupValidators(group, electableValidators.max);
    }

    function getTotalVotes() public view returns (uint256) {
        return votes.active.total.add(votes.pending.total);
    }

    function setValidators2(address validators2) public {
        Validators2 = IValidators2(validators2);
        log("setValidators2", validators2);
    }
}
