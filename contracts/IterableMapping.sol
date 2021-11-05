pragma solidity ^0.5.13;

// mapping 遍历库
library IterableMapping {

    // 增、删、改、查
    struct itmap {
        uint size;
        mapping(address => IndexValue) data;
        KeyFlag [] keys;
        // value
    }

    // key值的列表
    struct KeyFlag {
        address key;
        bool deleted;
    }

    // value
    struct IndexValue {
        uint KeyIndex;
        bool value;
    }


    // 插入数据
    function insert(itmap storage self, address key, bool value) external returns (bool replaced) {
        uint keyIdx = self.data[key].KeyIndex;
        self.data[key].value = value;
        if (keyIdx > 0) {
            return true;
        } else {
            keyIdx = self.keys.length++;
            self.data[key].KeyIndex = keyIdx + 1;
            self.keys[keyIdx].key = key;
            self.size++;
            return false;
        }
    }

    // 删除数据(逻辑删除)
    function remove(itmap storage self, address key) external returns (bool) {
        uint keyIdx = self.data[key].KeyIndex;
        if (keyIdx == 0) {
            return false;
        } else {
            delete self.data[key];
            //逻辑删除
            self.keys[keyIdx - 1].deleted = true;
            self.size --;
            return true;
        }
    }

    // 获取数据
    function iterate_get(itmap storage self, uint KeyIdx)external returns (address key, bool value) {
        key = self.keys[KeyIdx].key;
        value = self.data[key].value;
    }

    // 包含
    function iterate_contains(itmap storage self, address key)external returns (bool) {
        return self.data[key].KeyIndex > 0;
    }

    // 获取下一个索引
    function iterate_next(itmap storage self, uint _keyIndex) public  returns (uint r_keyIndex) {
        _keyIndex++;
        while (_keyIndex < self.keys.length && self.keys[_keyIndex].deleted) {
            _keyIndex++;
        }
        return _keyIndex;
    }

    // 开始遍历
    function iterate_start(itmap storage self)external returns (uint keyIndex) {
        return iterate_next(self, uint(- 1));
    }

    // 循环退出条件
    function iterate_valid(itmap storage self, uint keyIndex) external returns (bool) {
        return keyIndex < self.keys.length;
    }
}
