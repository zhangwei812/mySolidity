pragma solidity ^0.5.13;

interface IValidators2 {

  function getGroupValidators(address, uint256) external view returns (address[] memory);


}
