// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    struct Rank {
        address addr;
        uint256 amount;
    }

    mapping(address => uint256) public balances;
    Rank[] public topThree;
    address public immutable admin;

    constructor() {
        admin = msg.sender;
    }

    // 接收 ETH 存款并更新排名
    receive() external payable {
        balances[msg.sender] += msg.value;
        _updateTopThree(msg.sender, balances[msg.sender]);
    }

    // 更新前三名
    function _updateTopThree(address user, uint256 newAmount) private {
        // 检查是否已在排行榜中
        uint256 existingIndex = _findUserInTopThree(user);

        if (existingIndex != type(uint256).max) {
            // 更新现有记录
            topThree[existingIndex].amount = newAmount;
        } else if (topThree.length < 3 || newAmount > topThree[2].amount) {
            // 添加新记录（只有当新金额超过第三名或排行榜未满时）
            if (topThree.length >= 3) {
                topThree.pop(); // 移除当前第三名
            }
            topThree.push(Rank(user, newAmount));
        } else {
            return; // 无需更新
        }

        // 按金额降序排序
        _sortTopThree();
    }

    // 查找用户是否在排行榜中
    function _findUserInTopThree(address user) private view returns (uint256) {
        for (uint256 i = 0; i < topThree.length; i++) {
            if (topThree[i].addr == user) {
                return i;
            }
        }
        return type(uint256).max;
    }

    // 排序算法（仅处理最多3个元素）
    function _sortTopThree() private {
        uint256 n = topThree.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (topThree[i].amount < topThree[j].amount) {
                    Rank memory temp = topThree[i];
                    topThree[i] = topThree[j];
                    topThree[j] = temp;
                }
            }
        }
    }

    // 管理员提取资金（使用更安全的转账方式）
    function withdraw() external {
        require(msg.sender == admin, "Unauthorized");
        (bool success, ) = payable(admin).call{value: address(this).balance}("");
        require(success, "Transfer failed123");
    }

    // 获取当前前三名（辅助视图函数）
    function getTopThree() external view returns (Rank[3] memory) {
        Rank[3] memory result;
        uint256 length = topThree.length < 3 ? topThree.length : 3;
        for (uint256 i = 0; i < length; i++) {
            result[i] = topThree[i];
        }
        return result;
    }
}