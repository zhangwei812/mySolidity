pragma solidity ^0.5.13;

interface IAccounts {
  function isAccount(address) external view returns (bool);
  function setAccountDataEncryptionKey(bytes calldata) external;
  function setName(string calldata) external;
  function setWalletAddress(address, uint8, bytes32, bytes32) external;
  function setAccount(string calldata, bytes calldata, address, uint8, bytes32, bytes32) external;
  function getDataEncryptionKey(address) external view returns (bytes memory);
  function getWalletAddress(address) external view returns (address);
  function getName(address) external view returns (string memory);
  function createAccount() external returns (bool);
  function validatorSignerToAccount(address) external view returns (address);
}
