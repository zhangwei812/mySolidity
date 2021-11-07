pragma solidity ^0.5.13;

import "./openzeppelin-solidity/contracts/math/Math.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Initializable.sol";
import "./IAccounts.sol";
import "./IRegistry.sol";
import "./IElection.sol";
import "./ILockedGold.sol";
import "./IValidators.sol";
import "./IValidators2.sol";
import "./Console.sol";


library BytesLib {
    function concat(
        bytes memory _preBytes,
        bytes memory _postBytes
    )
    internal
    pure
    returns (bytes memory)
    {
        bytes memory tempBytes;

        assembly {
        // Get a location of some free memory and store it in tempBytes as
        // Solidity does for memory variables.
            tempBytes := mload(0x40)

        // Store the length of the first bytes array at the beginning of
        // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

        // Maintain a memory counter for the current write location in the
        // temp bytes array by adding the 32 bytes for the array length to
        // the starting location.
            let mc := add(tempBytes, 0x20)
        // Stop copying when the memory counter reaches the length of the
        // first bytes array.
            let end := add(mc, length)

            for {
            // Initialize a copy counter to the start of the _preBytes data,
            // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
            // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
            // Write the _preBytes data into the tempBytes memory 32 bytes
            // at a time.
                mstore(mc, mload(cc))
            }

        // Add the length of _postBytes to the current length of tempBytes
        // and store it as the new length in the first 32 bytes of the
        // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

        // Move the memory counter back from a multiple of 0x20 to the
        // actual end of the _preBytes data.
            mc := end
        // Stop copying when the memory counter reaches the new combined
        // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

        // Update the free-memory pointer by padding our last write location
        // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
        // next 32 byte block, then round down to the nearest multiple of
        // 32. If the sum of the length of the two arrays is zero then add
        // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
            add(add(end, iszero(add(length, mload(_preBytes)))), 31),
            not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {

    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
    internal
    pure
    returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
                tempBytes := mload(0x40)

            // The first word of the slice result is potentially a partial
            // word read from the original array. To read it, we calculate
            // the length of that partial word and start copying that many
            // bytes into the array. The first word we copy will start with
            // data we don't care about, but the last `lengthmod` bytes will
            // land at the beginning of the contents of the new array. When
            // we're done copying, we overwrite the full first word with
            // the actual length of the slice.
                let lengthmod := and(_length, 31)

            // The multiplication in the next line is necessary
            // because when slicing multiples of 32 bytes (lengthmod == 0)
            // the following copy loop was copying the origin's length
            // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                // The multiplication in the next line has the same exact purpose
                // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
            //zero out the 32 bytes slice we are about to return
            //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_bytes.length >= _start + 1, "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64(bytes memory _bytes, uint256 _start) internal pure returns (uint64) {
        require(_bytes.length >= _start + 8, "toUint64_outOfBounds");
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96(bytes memory _bytes, uint256 _start) internal pure returns (uint96) {
        require(_bytes.length >= _start + 12, "toUint96_outOfBounds");
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128(bytes memory _bytes, uint256 _start) internal pure returns (uint128) {
        require(_bytes.length >= _start + 16, "toUint128_outOfBounds");
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32) {
        require(_bytes.length >= _start + 32, "toBytes32_outOfBounds");
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

        // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
            // cb is a circuit breaker in the for loop since there's
            //  no said feature for inline assembly loops
            // cb = 1 - don't breaker
            // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint256(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                    // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
            // unsuccess:
                success := 0
            }
        }

        return success;
    }


}

library FixidityLib {
    struct Fraction {
        uint256 value;
    }

    /**
     * @notice Number of positions that the comma is shifted to the right.
     */
    function digits() internal pure returns (uint8) {
        return 24;
    }

    uint256 private constant FIXED1_UINT = 1000000000000000000000000;

    /**
     * @notice This is 1 in the fixed point units used in this library.
     * @dev Test fixed1() equals 10^digits()
     * Hardcoded to 24 digits.
     */
    function fixed1() internal pure returns (Fraction memory) {
        return Fraction(FIXED1_UINT);
    }

    /**
     * @notice Wrap a uint256 that represents a 24-decimal fraction in a Fraction
     * struct.
     * @param x Number that already represents a 24-decimal fraction.
     * @return A Fraction struct with contents x.
     */
    function wrap(uint256 x) internal pure returns (Fraction memory) {
        return Fraction(x);
    }

    /**
     * @notice Unwraps the uint256 inside of a Fraction struct.
     */
    function unwrap(Fraction memory x) internal pure returns (uint256) {
        return x.value;
    }

    /**
     * @notice The amount of decimals lost on each multiplication operand.
     * @dev Test mulPrecision() equals sqrt(fixed1)
     */
    function mulPrecision() internal pure returns (uint256) {
        return 1000000000000;
    }

    /**
     * @notice Maximum value that can be converted to fixed point. Optimize for deployment.
     * @dev
     * Test maxNewFixed() equals maxUint256() / fixed1()
     */
    function maxNewFixed() internal pure returns (uint256) {
        return 115792089237316195423570985008687907853269984665640564;
    }

    /**
     * @notice Converts a uint256 to fixed point Fraction
     * @dev Test newFixed(0) returns 0
     * Test newFixed(1) returns fixed1()
     * Test newFixed(maxNewFixed()) returns maxNewFixed() * fixed1()
     * Test newFixed(maxNewFixed()+1) fails
     */
    function newFixed(uint256 x) internal pure returns (Fraction memory) {
        require(x <= maxNewFixed(), "can't create fixidity number larger than maxNewFixed()");
        return Fraction(x * FIXED1_UINT);
    }

    /**
     * @notice Converts a uint256 in the fixed point representation of this
     * library to a non decimal. All decimal digits will be truncated.
     */
    function fromFixed(Fraction memory x) internal pure returns (uint256) {
        return x.value / FIXED1_UINT;
    }

    /**
     * @notice Converts two uint256 representing a fraction to fixed point units,
     * equivalent to multiplying dividend and divisor by 10^digits().
     * @param numerator numerator must be <= maxNewFixed()
     * @param denominator denominator must be <= maxNewFixed() and denominator can't be 0
     * @dev
     * Test newFixedFraction(1,0) fails
     * Test newFixedFraction(0,1) returns 0
     * Test newFixedFraction(1,1) returns fixed1()
     * Test newFixedFraction(1,fixed1()) returns 1
     */
    function newFixedFraction(uint256 numerator, uint256 denominator)
    internal
    pure
    returns (Fraction memory)
    {
        Fraction memory convertedNumerator = newFixed(numerator);
        Fraction memory convertedDenominator = newFixed(denominator);
        return divide(convertedNumerator, convertedDenominator);
    }

    /**
     * @notice Returns the integer part of a fixed point number.
     * @dev
     * Test integer(0) returns 0
     * Test integer(fixed1()) returns fixed1()
     * Test integer(newFixed(maxNewFixed())) returns maxNewFixed()*fixed1()
     */
    function integer(Fraction memory x) internal pure returns (Fraction memory) {
        return Fraction((x.value / FIXED1_UINT) * FIXED1_UINT);
        // Can't overflow
    }

    /**
     * @notice Returns the fractional part of a fixed point number.
     * In the case of a negative number the fractional is also negative.
     * @dev
     * Test fractional(0) returns 0
     * Test fractional(fixed1()) returns 0
     * Test fractional(fixed1()-1) returns 10^24-1
     */
    function fractional(Fraction memory x) internal pure returns (Fraction memory) {
        return Fraction(x.value - (x.value / FIXED1_UINT) * FIXED1_UINT);
        // Can't overflow
    }

    /**
     * @notice x+y.
     * @dev The maximum value that can be safely used as an addition operator is defined as
     * maxFixedAdd = maxUint256()-1 / 2, or
     * 57896044618658097711785492504343953926634992332820282019728792003956564819967.
     * Test add(maxFixedAdd,maxFixedAdd) equals maxFixedAdd + maxFixedAdd
     * Test add(maxFixedAdd+1,maxFixedAdd+1) throws
     */
    function add(Fraction memory x, Fraction memory y) internal pure returns (Fraction memory) {
        uint256 z = x.value + y.value;
        require(z >= x.value, "add overflow detected");
        return Fraction(z);
    }

    /**
     * @notice x-y.
     * @dev
     * Test subtract(6, 10) fails
     */
    function subtract(Fraction memory x, Fraction memory y) internal pure returns (Fraction memory) {
        require(x.value >= y.value, "substraction underflow detected");
        return Fraction(x.value - y.value);
    }

    /**
     * @notice x*y. If any of the operators is higher than the max multiplier value it
     * might overflow.
     * @dev The maximum value that can be safely used as a multiplication operator
     * (maxFixedMul) is calculated as sqrt(maxUint256()*fixed1()),
     * or 340282366920938463463374607431768211455999999999999
     * Test multiply(0,0) returns 0
     * Test multiply(maxFixedMul,0) returns 0
     * Test multiply(0,maxFixedMul) returns 0
     * Test multiply(fixed1()/mulPrecision(),fixed1()*mulPrecision()) returns fixed1()
     * Test multiply(maxFixedMul,maxFixedMul) is around maxUint256()
     * Test multiply(maxFixedMul+1,maxFixedMul+1) fails
     */
    function multiply(Fraction memory x, Fraction memory y) internal pure returns (Fraction memory) {
        if (x.value == 0 || y.value == 0) return Fraction(0);
        if (y.value == FIXED1_UINT) return x;
        if (x.value == FIXED1_UINT) return y;

        // Separate into integer and fractional parts
        // x = x1 + x2, y = y1 + y2
        uint256 x1 = integer(x).value / FIXED1_UINT;
        uint256 x2 = fractional(x).value;
        uint256 y1 = integer(y).value / FIXED1_UINT;
        uint256 y2 = fractional(y).value;

        // (x1 + x2) * (y1 + y2) = (x1 * y1) + (x1 * y2) + (x2 * y1) + (x2 * y2)
        uint256 x1y1 = x1 * y1;
        if (x1 != 0) require(x1y1 / x1 == y1, "overflow x1y1 detected");

        // x1y1 needs to be multiplied back by fixed1
        // solium-disable-next-line mixedcase
        uint256 fixed_x1y1 = x1y1 * FIXED1_UINT;
        if (x1y1 != 0) require(fixed_x1y1 / x1y1 == FIXED1_UINT, "overflow x1y1 * fixed1 detected");
        x1y1 = fixed_x1y1;

        uint256 x2y1 = x2 * y1;
        if (x2 != 0) require(x2y1 / x2 == y1, "overflow x2y1 detected");

        uint256 x1y2 = x1 * y2;
        if (x1 != 0) require(x1y2 / x1 == y2, "overflow x1y2 detected");

        x2 = x2 / mulPrecision();
        y2 = y2 / mulPrecision();
        uint256 x2y2 = x2 * y2;
        if (x2 != 0) require(x2y2 / x2 == y2, "overflow x2y2 detected");

        // result = fixed1() * x1 * y1 + x1 * y2 + x2 * y1 + x2 * y2 / fixed1();
        Fraction memory result = Fraction(x1y1);
        result = add(result, Fraction(x2y1));
        // Add checks for overflow
        result = add(result, Fraction(x1y2));
        // Add checks for overflow
        result = add(result, Fraction(x2y2));
        // Add checks for overflow
        return result;
    }

    /**
     * @notice 1/x
     * @dev
     * Test reciprocal(0) fails
     * Test reciprocal(fixed1()) returns fixed1()
     * Test reciprocal(fixed1()*fixed1()) returns 1 // Testing how the fractional is truncated
     * Test reciprocal(1+fixed1()*fixed1()) returns 0 // Testing how the fractional is truncated
     * Test reciprocal(newFixedFraction(1, 1e24)) returns newFixed(1e24)
     */
    function reciprocal(Fraction memory x) internal pure returns (Fraction memory) {
        require(x.value != 0, "can't call reciprocal(0)");
        return Fraction((FIXED1_UINT * FIXED1_UINT) / x.value);
        // Can't overflow
    }

    /**
     * @notice x/y. If the dividend is higher than the max dividend value, it
     * might overflow. You can use multiply(x,reciprocal(y)) instead.
     * @dev The maximum value that can be safely used as a dividend (maxNewFixed) is defined as
     * divide(maxNewFixed,newFixedFraction(1,fixed1())) is around maxUint256().
     * This yields the value 115792089237316195423570985008687907853269984665640564.
     * Test maxNewFixed equals maxUint256()/fixed1()
     * Test divide(maxNewFixed,1) equals maxNewFixed*(fixed1)
     * Test divide(maxNewFixed+1,multiply(mulPrecision(),mulPrecision())) throws
     * Test divide(fixed1(),0) fails
     * Test divide(maxNewFixed,1) = maxNewFixed*(10^digits())
     * Test divide(maxNewFixed+1,1) throws
     */
    function divide(Fraction memory x, Fraction memory y) internal pure returns (Fraction memory) {
        require(y.value != 0, "can't divide by 0");
        uint256 X = x.value * FIXED1_UINT;
        require(X / FIXED1_UINT == x.value, "overflow at divide");
        return Fraction(X / y.value);
    }

    /**
     * @notice x > y
     */
    function gt(Fraction memory x, Fraction memory y) internal pure returns (bool) {
        return x.value > y.value;
    }

    /**
     * @notice x >= y
     */
    function gte(Fraction memory x, Fraction memory y) internal pure returns (bool) {
        return x.value >= y.value;
    }

    /**
     * @notice x < y
     */
    function lt(Fraction memory x, Fraction memory y) internal pure returns (bool) {
        return x.value < y.value;
    }

    /**
     * @notice x <= y
     */
    function lte(Fraction memory x, Fraction memory y) internal pure returns (bool) {
        return x.value <= y.value;
    }

    /**
     * @notice x == y
     */
    function equals(Fraction memory x, Fraction memory y) internal pure returns (bool) {
        return x.value == y.value;
    }

    /**
     * @notice x <= 1
     */
    function isProperFraction(Fraction memory x) internal pure returns (bool) {
        return lte(x, fixed1());
    }
}

contract UsingRegistry is Ownable {
    event RegistrySet(address indexed registryAddress);
    // solhint-disable state-visibility
    bytes32 constant ACCOUNTS_REGISTRY_ID = keccak256(abi.encodePacked("Accounts"));
    bytes32 constant VALIDATORS_REGISTRY_ID = keccak256(abi.encodePacked("Validators"));
    bytes32 constant LOCKED_GOLD_REGISTRY_ID = keccak256(abi.encodePacked("LockedGold"));
    bytes32 constant ELECTION_REGISTRY_ID = keccak256(abi.encodePacked("Election"));
    // solhint-enable state-visibility
    IRegistry public registry;

    function setRegistry(address registryAddress) public onlyOwner {
        require(registryAddress != address(0), "Cannot register the null address");
        registry = IRegistry(registryAddress);
        emit RegistrySet(registryAddress);
    }

    function getAccounts() internal view returns (IAccounts) {
        return IAccounts(registry.getAddressForOrDie(ACCOUNTS_REGISTRY_ID));
        // 需要添加Accounts合約
    }

    function getLockedGold() internal view returns (ILockedGold) {
        return ILockedGold(registry.getAddressForOrDie(LOCKED_GOLD_REGISTRY_ID));
    }
}

contract UsingPrecompiles {
    using SafeMath for uint256;
    address constant EPOCH_SIZE = address(0xff - 7);
    address constant PROOF_OF_POSSESSION = address(0xff - 4);

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

    function getEpochNumberOfBlock(uint256 blockNumber) public view returns (uint256) {
        return epochNumberOfBlock(blockNumber, getEpochSize());
    }

    function getEpochNumber() public view returns (uint256) {
        return getEpochNumberOfBlock(block.number);
    }

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

    function checkProofOfPossession(address sender, bytes memory blsKey, bytes memory blsPop)
    public
    view
    returns (bool)
    {
        bool success;
        (success,) = PROOF_OF_POSSESSION.staticcall(abi.encodePacked(sender, blsKey, blsPop));
        return success;
    }

}

contract Validators is
Ownable,
Initializable,
UsingPrecompiles,
UsingRegistry,
Console,
IValidators2
{
    using FixidityLib for FixidityLib.Fraction;
    using SafeMath for uint256;
    using BytesLib for bytes;

    struct LockedGoldRequirements {
        uint256 value;
        uint256 duration;
    }


    struct membersinfo {
        address[] list;
        mapping(address => uint256) member;//address  index
        uint256 numElements;
    }

    struct ValidatorGroup {
        bool exists;
        membersinfo members;
        FixidityLib.Fraction commission;
        FixidityLib.Fraction nextCommission;
        uint256 nextCommissionBlock;
        uint256[] sizeHistory;
        SlashingInfo slashInfo;
    }

    struct MembershipHistoryEntry {
        uint256 epochNumber;
        address group;
    }


    struct MembershipHistory {
        uint256 tail;
        uint256 numEntries;
        mapping(uint256 => MembershipHistoryEntry) entries;
        uint256 lastRemovedFromGroupTimestamp;
    }

    struct SlashingInfo {
        FixidityLib.Fraction multiplier;
        uint256 lastSlashed;
    }

    struct PublicKeys {
        bytes ecdsa;
        bytes bls;
    }

    struct Validator {
        bool exists;
        PublicKeys publicKeys;
        address affiliation;
        FixidityLib.Fraction score;
        MembershipHistory membershipHistory;
    }

    struct ValidatorScoreParameters {
        uint256 exponent;
        FixidityLib.Fraction adjustmentSpeed;
    }

    mapping(address => ValidatorGroup) private groups;
    mapping(address => Validator) private validators;
    address[] private registeredGroups;
    address[] private registeredValidators;
    LockedGoldRequirements public validatorLockedGoldRequirements;
    LockedGoldRequirements public groupLockedGoldRequirements;
    ValidatorScoreParameters private validatorScoreParameters;
    uint256 public membershipHistoryLength;
    uint256 public maxGroupSize;
    uint256 public commissionUpdateDelay;
    uint256 public slashingMultiplierResetPeriod;
    uint256 public downtimeGracePeriod;
    constructor(bool test) public Initializable(test) {}

    function initialize(
        address registryAddress
    ) external initializer {
        _transferOwnership(msg.sender);
        setRegistry(registryAddress);
    }

    function registerValidator(
    ) external returns (bool) {
        //        address account = getAccounts().validatorSignerToAccount(msg.sender);zhangwei
        //        require(!isValidator(account) && !isValidatorGroup(account), "Already registered");
        address account = msg.sender;
        Validator storage validator = validators[account];
        //        uint256 lockedGoldBalance = getLockedGold().getAccountTotalLockedGold(account);

        //        require(lockedGoldBalance >= validatorLockedGoldRequirements.value, "Deposit too small");
        validator.exists = true;
        registeredValidators.push(account);
        //        updateMembershipHistory(account, address(0));
        return true;
    }

    function deregisterValidator(uint256 index) external returns (bool) {
        address account = getAccounts().validatorSignerToAccount(msg.sender);
        require(isValidator(account), "Not a validator");

        // Require that the validator has not been a member of a validator group for
        // `validatorLockedGoldRequirements.duration` seconds.
        Validator storage validator = validators[account];
        if (validator.affiliation != address(0)) {
            // 1.是组成员不能注销
            require(
                !(groups[validator.affiliation].members.member[account] > 0),
                "Has been group member recently"
            );
        }
        uint256 requirementEndTime = validator.membershipHistory.lastRemovedFromGroupTimestamp.add(
            validatorLockedGoldRequirements.duration
        );
        //2.未到注销时间不能删除
        require(requirementEndTime < now, "Not yet requirement end time");

        // Remove the validator.
        deleteElement(registeredValidators, account, index);
        delete validators[account];

        return true;
    }

    function affiliate(address group) external returns (bool) {
        //        address account = getAccounts().validatorSignerToAccount(msg.sender); zhangwei
        address account = msg.sender;
        //        require(isValidator(account), "Not a validator");
        //        require(isValidatorGroup(group), "Not a validator group");
        //        //1.验证器不符合要求
        //        require(meetsAccountLockedGoldRequirements(account), "Validator doesn't meet requirements");
        //        //2.组不符合要求
        //        require(meetsAccountLockedGoldRequirements(group), "Group doesn't meet requirements");
        Validator storage validator = validators[account];
        if (validator.affiliation != address(0)) {
            //3.取消其它组的关联
            _deaffiliate(validator, account);
        }
        //3.关联
        validator.affiliation = group;

        return true;
    }

    function deaffiliate() external returns (bool) {
        address account = getAccounts().validatorSignerToAccount(msg.sender);
        require(isValidator(account), "Not a validator");
        Validator storage validator = validators[account];
        require(validator.affiliation != address(0), "deaffiliate: not affiliated");
        _deaffiliate(validator, account);
        return true;
    }

    function registerValidatorGroup(uint256 commission) external returns (bool) {
        require(commission <= FixidityLib.fixed1().unwrap(), "Commission can't be greater than 100%");
        address account = msg.sender;
        // 2.不能是验证者
        //         require(!isValidator(account), "Already registered as validator");
        // 3.已经成为验证者组
        require(!isValidatorGroup(account), "Already registered as group");
        //        uint256 lockedGoldBalance = getLockedGold().getAccountTotalLockedGold(account);
        //        //        //4.符合验证者组要求金额
        //        require(lockedGoldBalance >= groupLockedGoldRequirements.value, "Not enough locked gold");
        ValidatorGroup storage group = groups[account];
        group.exists = true;
        group.commission = FixidityLib.wrap(commission);
        group.slashInfo = SlashingInfo(FixidityLib.fixed1(), 0);
        registeredGroups.push(account);

        return true;
    }

    function deregisterValidatorGroup(uint256 index) external returns (bool) {
        address account = getAccounts().validatorSignerToAccount(msg.sender);
        // Only Validator Groups that have never had members or have been empty for at least
        // `groupLockedGoldRequirements.duration` seconds can be deregistered.
        require(isValidatorGroup(account), "Not a validator group");
        require(groups[account].members.numElements == 0, "Validator group not empty");
        uint256[] storage sizeHistory = groups[account].sizeHistory;
        if (sizeHistory.length > 1) {
            require(
                sizeHistory[1].add(groupLockedGoldRequirements.duration) < now,
                "Hasn't been empty for long enough"
            );
        }
        delete groups[account];
        deleteElement(registeredGroups, account, index);

        return true;
    }

    function addMember(address validator) external returns (bool) {
        address account = msg.sender;
        ValidatorGroup storage _group = groups[account];
        _group.members.list.push(validator);
        _group.members.member[validator] = _group.members.list.length - 1;
        _group.members.numElements.add(1);

        log("addMember", _group.members.list.length);
        log("addMember", validator);
        return true;
    }


    function removeMember(address validator) external returns (bool) {
        address account = getAccounts().validatorSignerToAccount(msg.sender);
        require(isValidatorGroup(account) && isValidator(validator), "is not group and validator");
        return _removeMember(account, validator);
    }

    function getAccountLockedGoldRequirement(address account) public view returns (uint256) {
        if (isValidator(account)) {
            return validatorLockedGoldRequirements.value;
        } else if (isValidatorGroup(account)) {
            uint256 multiplier = Math.max(1, groups[account].members.numElements);
            uint256[] storage sizeHistory = groups[account].sizeHistory;
            if (sizeHistory.length > 0) {
                for (uint256 i = sizeHistory.length.sub(1); i > 0; i = i.sub(1)) {
                    if (sizeHistory[i].add(groupLockedGoldRequirements.duration) >= now) {
                        multiplier = Math.max(i, multiplier);
                        break;
                    }
                }
            }
            return groupLockedGoldRequirements.value.mul(multiplier);
        }
        return 0;
    }

    function meetsAccountLockedGoldRequirements(address account) public view returns (bool) {
        uint256 balance = getLockedGold().getAccountTotalLockedGold(account);
        // Add a bit of "wiggle room" to accommodate the fact that vote activation can result in ~1
        // wei rounding errors. Using 10 as an additional margin of safety.
        return balance.add(10) >= getAccountLockedGoldRequirement(account);
    }

    function isValidatorGroup(address account) public view returns (bool) {
        return groups[account].exists;
    }

    function isValidator(address account) public view returns (bool) {
        return validators[account].exists;
    }

    function deleteElement(address[] storage list, address element, uint256 index) private {
        require(index < list.length && list[index] == element, "deleteElement: index out of range");
        uint256 lastIndex = list.length.sub(1);
        list[index] = list[lastIndex];
        delete list[lastIndex];
        list.length = lastIndex;
    }

    function _removeMember(address group, address validator) private returns (bool) {
        ValidatorGroup storage _group = groups[group];
        require(validators[validator].affiliation == group, "Not affiliated to group");
        deleteElement(_group.members.list, validator, _group.members.member[validator]);
        delete (_group.members.member[validator]);
        uint256 numMembers = _group.members.numElements;
        // Empty validator groups are not electable.
        if (numMembers == 0) {
            getElection().markGroupIneligible(group);
        }
        _group.members.list[_group.members.numElements] == address(0);
        _group.members.numElements.sub(1);

        return true;
    }

    function updateMembershipHistory(address account, address group) private returns (bool) {
        MembershipHistory storage history = validators[account].membershipHistory;
        uint256 epochNumber = getEpochNumber();
        uint256 head = history.numEntries == 0 ? 0 : history.tail.add(history.numEntries.sub(1));

        if (history.numEntries > 0 && group == address(0)) {
            history.lastRemovedFromGroupTimestamp = now;
        }

        if (history.numEntries > 0 && history.entries[head].epochNumber == epochNumber) {
            // There have been no elections since the validator last changed membership, overwrite the
            // previous entry.
            history.entries[head] = MembershipHistoryEntry(epochNumber, group);
            return true;
        }

        // There have been elections since the validator last changed membership, create a new entry.
        uint256 index = history.numEntries == 0 ? 0 : head.add(1);
        history.entries[index] = MembershipHistoryEntry(epochNumber, group);
        if (history.numEntries < membershipHistoryLength) {
            // Not enough entries, don't remove any.
            history.numEntries = history.numEntries.add(1);
        } else if (history.numEntries == membershipHistoryLength) {
            // Exactly enough entries, delete the oldest one to account for the one we added.
            delete history.entries[history.tail];
            history.tail = history.tail.add(1);
        } else {
            // Too many entries, delete the oldest two to account for the one we added.
            delete history.entries[history.tail];
            delete history.entries[history.tail.add(1)];
            history.numEntries = history.numEntries.sub(1);
            history.tail = history.tail.add(2);
        }
        return true;
    }

    function updateSizeHistory(address group, uint256 size) private {
        uint256[] storage sizeHistory = groups[group].sizeHistory;
        if (size == sizeHistory.length) {
            sizeHistory.push(now);
        } else if (size < sizeHistory.length) {
            sizeHistory[size] = now;
        } else {
            require(false, "Unable to update size history");
        }
    }

    function _deaffiliate(Validator storage validator, address validatorAccount) private
    returns (bool)
    {
        address affiliation = validator.affiliation;
        ValidatorGroup storage group = groups[affiliation];
        deleteElement(group.members.list, validatorAccount, group.members.member[validatorAccount]);
        delete (group.members.member[validatorAccount]);
        validator.affiliation = address(0);
        return true;
    }


    function getElection() internal view returns (IElection) {
        return IElection(registry.getAddressForOrDie(ELECTION_REGISTRY_ID));
    }

    // 得到某一組成員
    function getGroupValidators(address account, uint256 n) external view
    returns (address[] memory)
    {
        return groups[account].members.list;
    }
    // 得到第一組成員 （选举）
    function getSelectValidators(uint256 maxElectableValidators) external view
    returns (address[] memory)
    {
        address[] memory originList = groups[registeredGroups[0]].members.list;
        address[] memory selectList = new address[](maxElectableValidators);
        uint256 j = maxElectableValidators;
        for (uint256 i = 0; i < maxElectableValidators; i++) {
            j--;
            selectList[i] = originList[j];
        }
        return selectList;
    }
}
