pragma solidity ^0.5.13;

contract Initializable {
    bool public initialized;

    constructor(bool testingDeployment) public {
        if (!testingDeployment) {
            initialized = true;
        }
    }
    //定义变量
    modifier initializer() {
        require(!initialized, "contract already initialized");
        initialized = true;
        _;
    }
}
