pragma solidity ^0.5.13;

import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "./IAccounts.sol";

import "./Initializable.sol";
import "./Signatures.sol";
import "./UsingRegistry.sol";

contract Accounts is
IAccounts,
Ownable,
Initializable,
UsingRegistry
{
    using SafeMath for uint256;

    struct Signers {
        // The address that is authorized to vote in governance and validator elections on behalf of the
        // account. The account can vote as well, whether or not a vote signing key has been specified.
        address vote;
        // The address that is authorized to manage a validator or validator group and sign consensus
        // messages on behalf of the account. The account can manage the validator, whether or not a
        // validator signing key has been specified. However, if a validator signing key has been
        // specified, only that key may actually participate in consensus.
        address validator;
        // The address of the key with which this account wants to sign attestations on the Attestations
        // contract
        //此帐户要用于在认证上签署认证的密钥的地址
        //合同
        address attestation;
    }

    struct SignerAuthorization {
        bool started;
        bool completed;
    }

    struct Account {
        bool exists;
        // [Deprecated] Each account may authorize signing keys to use for voting,
        // validating or attestation. These keys may not be keys of other accounts,
        // and may not be authorized by any other account for any purpose.
        Signers signers;
        // The address at which the account expects to receive transfers. If it's empty/0x0, the
        // account indicates that an address exchange should be initiated with the dataEncryptionKey
        address walletAddress;
        // An optional human readable identifier for the account
        string name;
        // The ECDSA public key used to encrypt and decrypt data for this account
        bytes dataEncryptionKey;
        // The URL under which an account adds metadata and claims
        string metadataURL;
    }

    mapping(address => Account) internal accounts;
    // Maps authorized signers to the account that provided the authorization.
    mapping(address => address) public authorizedBy;
    // Default signers by account (replaces the legacy Signers struct on Account)
    mapping(address => mapping(bytes32 => address)) defaultSigners;
    // All signers and their roles for a given account
    // solhint-disable-next-line max-line-length
    mapping(address => mapping(bytes32 => mapping(address => SignerAuthorization))) signerAuthorizations;

    bytes32 public constant EIP712_AUTHORIZE_SIGNER_TYPEHASH = keccak256(
        "AuthorizeSigner(address account,address signer,bytes32 role)"
    );
    bytes32 public eip712DomainSeparator;

    bytes32 constant ValidatorSigner = keccak256(abi.encodePacked("celo.org/core/validator"));
    bytes32 constant AttestationSigner = keccak256(abi.encodePacked("celo.org/core/attestation"));
    bytes32 constant VoteSigner = keccak256(abi.encodePacked("celo.org/core/vote"));



    /**
     * @notice Sets initialized == true on implementation contracts
     * @param test Set to true to skip implementation initialization
     */
    constructor(bool test) public Initializable(test) {}

    /**
     * @notice Returns the storage, major, minor, and patch version of the contract.
     * @return The storage, major, minor, and patch version of the contract.
     */
    function getVersionNumber() external pure returns (uint256, uint256, uint256, uint256) {
        return (1, 1, 2, 1);
    }

    /**
     * @notice Used in place of the constructor to allow the contract to be upgradable via proxy.
     * @param registryAddress The address of the registry core smart contract.
     */
    function initialize(address registryAddress) external initializer {
        _transferOwnership(msg.sender);
        setRegistry(registryAddress);
        setEip712DomainSeparator();
    }

    /**
     * @notice Sets the EIP712 domain separator for the Celo Accounts abstraction.
     */
    function setEip712DomainSeparator() public {
        uint256 chainId;
        chainId = 211;
        eip712DomainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Celo Core Contracts")),
                keccak256("1.0"),
                chainId,
                address(this)
            )
        );
    }


    //-----------------------
    function setAccount(
        string calldata name,
        bytes calldata dataEncryptionKey,
        address walletAddress,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (!isAccount(msg.sender)) {
            createAccount();
        }
        setName(name);
        setAccountDataEncryptionKey(dataEncryptionKey);
        setWalletAddress(walletAddress, v, r, s);
    }

    /**
     * @notice Creates an account.
     * @return True if account creation succeeded.
     */
    //-------------------------------
    function createAccount() public returns (bool) {
//        require(isNotAccount(msg.sender), "Account exists");
        Account storage account = accounts[msg.sender];
        account.exists = true;
        return true;
    }

    /**
     * @notice Setter for the name of an account.
     * @param name The name to set.
     */
    //-----------------------------------
    function setName(string memory name) public {
        require(isAccount(msg.sender), "Unknown account");
        Account storage account = accounts[msg.sender];
        account.name = name;
    }


    //----------------
    function setWalletAddress(address walletAddress, uint8 v, bytes32 r, bytes32 s) public {
        require(isAccount(msg.sender), "Unknown account");
        if (!(walletAddress == msg.sender || walletAddress == address(0x0))) {
            address signer = Signatures.getSignerOfAddress(msg.sender, v, r, s);
            require(signer == walletAddress, "Invalid signature");
        }
        Account storage account = accounts[msg.sender];
        account.walletAddress = walletAddress;
    }


    //---------------------
    function setAccountDataEncryptionKey(bytes memory dataEncryptionKey) public {
        require(dataEncryptionKey.length >= 33, "data encryption key length <= 32");
        Account storage account = accounts[msg.sender];
        account.dataEncryptionKey = dataEncryptionKey;
    }


    function getName(address account) external view returns (string memory) {
        return accounts[account].name;
    }

    function getDataEncryptionKey(address account) external view returns (bytes memory) {
        return accounts[account].dataEncryptionKey;
    }


    function getWalletAddress(address account) external view returns (address) {
        return accounts[account].walletAddress;
    }


    //---------------------------
    function isAccount(address account) public view returns (bool) {
        return (accounts[account].exists);
    }


    // ----------------------
    function isNotAccount(address account) internal view returns (bool) {
        return (!accounts[account].exists);
    }

    function validatorSignerToAccount(address signer) public view returns (address) {
        return signerToAccountWithRole(signer, ValidatorSigner);
    }

    function signerToAccountWithRole(address signer, bytes32 role) internal view returns (address) {
        return signer;
    }

    function isSigner(address account, address signer, bytes32 role) public view returns (bool) {
        return
        isLegacySigner(account, signer, role) ||
        (signerAuthorizations[account][role][signer].completed && authorizedBy[signer] == account);
    }
    //Legacy 遗产
    function isLegacySigner(address _account, address signer, bytes32 role)
    public
    view
    returns (bool)
    {
        return true;
    }
}
