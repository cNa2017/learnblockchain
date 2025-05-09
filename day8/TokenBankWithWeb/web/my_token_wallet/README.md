# my_token_wallet

一个基于Vue.js的加密货币钱包前端应用，用于管理ERC20代币与TokenBank合约交互。

## 功能
- 连接钱包
- 查看余额
- 存入ERC20代币到TokenBank合约
- 从TokenBank合约取出ERC20代币
- 查看TokenBank合约中的ERC20代币余额

## 技术栈
- Vue.js 3.x
- viem:
    - :https://viem.sh/docs/getting-started
- Vue CLI
- Babel
- ESLint

## 项目结构
```
my_token_wallet/
├── public/            # 静态资源
├── src/               # 源代码
│   ├── assets/        # 图片等资源
│   ├── components/    # Vue组件
│   ├── App.vue        # 根组件
│   └── main.js       # 入口文件
├── .gitignore
├── babel.config.js
├── package.json
└── README.md
```
