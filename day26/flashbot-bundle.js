const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
require('dotenv').config();

// 合约地址和 ABI
const CONTRACT_ADDRESS = '0x82b7ecbd2fa5f5a931D76d5BE6Fe90CE2Ee243EB';
const CONTRACT_ABI = require('./OpenspaceNFT.json');

// 网络配置
const SEPOLIA_CHAIN_ID = 11155111;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161';
const FLASHBOTS_URL = process.env.FLASHBOTS_URL || 'https://relay-sepolia.flashbots.net';

async function main() {
    console.log('🚀 开始 Flashbot 捆绑交易...');
    
    if (!process.env.PRIVATE_KEY) {
        throw new Error('请设置 PRIVATE_KEY 环境变量');
    }

    const provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    console.log('📍 钱包地址:', wallet.address);
    
    const balance = await provider.getBalance(wallet.address);
    console.log('💰 账户余额:', ethers.utils.formatEther(balance), 'ETH');

    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
    
    const isPresaleActive = await contract.isPresaleActive();
    const nextTokenId = await contract.nextTokenId();
    
    console.log('📊 合约状态:');
    console.log('  - 预售是否激活:', isPresaleActive);
    console.log('  - 下一个Token ID:', nextTokenId.toString());
    
    if (isPresaleActive) {
        console.log('ℹ️  预售已经激活，将跳过 enablePresale 交易');
    }

    const authSigner = ethers.Wallet.createRandom();
    const flashbotsProvider = await FlashbotsBundleProvider.create(
        provider,
        authSigner,
        FLASHBOTS_URL,
        'sepolia'  // 添加链标识符
    );

    const currentBlock = await provider.getBlockNumber();
    const targetBlockNumber = currentBlock + 2;
    
    console.log('🎯 目标区块:', targetBlockNumber);

    const transactions = [];
    const feeData = await provider.getFeeData();
    
    // 从当前网络获取费用数据，并提高2倍
    const networkMaxPriorityFeePerGas = feeData.maxPriorityFeePerGas || ethers.utils.parseUnits('2', 'gwei');
    const networkMaxFeePerGas = feeData.maxFeePerGas || ethers.utils.parseUnits('20', 'gwei');
    
    // 在网络费用基础上提高2倍  
    const maxPriorityFeePerGas = networkMaxPriorityFeePerGas.mul(2);
    const maxFeePerGas = networkMaxFeePerGas.mul(2);
    
    console.log('⛽ 网络 Gas 费用:');
    console.log('  - 网络 maxPriorityFeePerGas:', ethers.utils.formatUnits(networkMaxPriorityFeePerGas, 'gwei'), 'gwei');
    console.log('  - 网络 maxFeePerGas:', ethers.utils.formatUnits(networkMaxFeePerGas, 'gwei'), 'gwei');
    console.log('⛽ 使用的 Gas 费用 (2倍提升):');
    console.log('  - maxPriorityFeePerGas:', ethers.utils.formatUnits(maxPriorityFeePerGas, 'gwei'), 'gwei');
    console.log('  - maxFeePerGas:', ethers.utils.formatUnits(maxFeePerGas, 'gwei'), 'gwei');

    let nonce = await provider.getTransactionCount(wallet.address, 'pending');
    
    // 如果需要，添加 enablePresale 交易
    if (!isPresaleActive) {
        const enablePresaleTx = {
            to: CONTRACT_ADDRESS,
            data: contract.interface.encodeFunctionData('enablePresale'),
            maxFeePerGas,
            maxPriorityFeePerGas,
            gasLimit: 100000,
            nonce: nonce++,
            type: 2,
            chainId: SEPOLIA_CHAIN_ID
        };
        
        // 使用 {signer, transaction} 格式
        transactions.push({
            signer: wallet,
            transaction: enablePresaleTx
        });
        console.log('✅ 已准备 enablePresale 交易');
    }

    // 添加 presale 交易
    const presaleAmount = 1;
    const presaleValue = ethers.utils.parseEther('0.01');
    
    const presaleTx = {
        to: CONTRACT_ADDRESS,
        data: contract.interface.encodeFunctionData('presale', [presaleAmount]),
        value: presaleValue,
        maxFeePerGas,
        maxPriorityFeePerGas,
        gasLimit: 200000,
        nonce,
        type: 2,
        chainId: SEPOLIA_CHAIN_ID
    };
    
    // 使用 {signer, transaction} 格式
    transactions.push({
        signer: wallet,
        transaction: presaleTx
    });
    
    console.log('✅ 已准备 presale 交易');
    console.log('📦 准备发送', transactions.length, '个交易');

    // 模拟交易
    console.log('🧪 尝试模拟交易执行...');
    try {
        // 先签名 Bundle 然后模拟
        const signedTransactions = await flashbotsProvider.signBundle(transactions);
        const simulation = await flashbotsProvider.simulate(
            signedTransactions,
            targetBlockNumber,
            targetBlockNumber - 1
        );
        
        // 检查模拟是否有错误
        if (simulation.error) {
            console.log('❌ 模拟失败:', simulation.error);
            console.log('📤 跳过模拟检查，继续发送捆绑交易...');
        } else {
            console.log('✅ 模拟成功！');
            console.log('📊 模拟结果:');
            
            // 计算总 Gas 使用量
            let totalGasUsed = ethers.BigNumber.from(0);
            if (simulation.results && Array.isArray(simulation.results)) {
                simulation.results.forEach(result => {
                    if (result.gasUsed) {
                        totalGasUsed = totalGasUsed.add(result.gasUsed);
                    }
                });
            }
            
            console.log('  - 总 Gas 使用:', totalGasUsed.gt(0) ? totalGasUsed.toString() : (simulation.totalGasUsed || 'N/A'));
            console.log('  - Coinbase 差额:', simulation.coinbaseDiff ? ethers.utils.formatEther(simulation.coinbaseDiff) + ' ETH' : 'N/A');
            
            // 检查每个交易的模拟结果
            if (simulation.results && Array.isArray(simulation.results)) {
                simulation.results.forEach((result, index) => {
                    console.log(`  - 交易 ${index + 1}:`, {
                        gasUsed: result.gasUsed ? result.gasUsed.toString() : 'N/A',
                        gasPrice: result.gasPrice ? ethers.utils.formatUnits(result.gasPrice, 'gwei') + ' gwei' : 'N/A',
                        success: !result.error,
                        error: result.error || null
                    });
                    if (result.error) {
                        console.log(`    ❌ 错误: ${result.error}`);
                    }
                });
            } else {
                console.log('  - 交易结果: 详细信息不可用');
            }
        }
        
        // 调试：显示完整的模拟结果结构
        console.log('🔍 调试信息 - 模拟结果结构:');
        console.log('  - 可用字段:', Object.keys(simulation));
        if (simulation.error) {
            console.log('  - 错误详情:', simulation.error);
        }
    } catch (error) {
        console.warn('⚠️  模拟失败:', error.message);
        console.log('📤 跳过模拟，直接发送捆绑交易...');
    }

    // 发送捆绑交易
    const bundleResponse = await flashbotsProvider.sendBundle(
        transactions, 
        targetBlockNumber,
        {
            // 可选：设置最小和最大时间戳
            minTimestamp: Math.floor(Date.now() / 1000),
            maxTimestamp: Math.floor(Date.now() / 1000) + 300  // 5分钟内有效
        }
    );
    console.log('📤 Bundle Hash:', bundleResponse.bundleHash);

    // 等待目标区块
    let currentBlockNum = await provider.getBlockNumber();
    while (currentBlockNum < targetBlockNumber) {
        console.log(`⏳ 等待区块 ${targetBlockNumber}，当前: ${currentBlockNum}`);
        await new Promise(resolve => setTimeout(resolve, 12000));
        currentBlockNum = await provider.getBlockNumber();
    }

    // 检查捆绑状态
    console.log('🔍 检查捆绑状态...');
    try {
        const bundleStats = await flashbotsProvider.getBundleStats(bundleResponse.bundleHash, targetBlockNumber);
        
        console.log('📊 Bundle Stats:');
        console.log('🎯 高优先级:', bundleStats.isHighPriority);
        console.log('⛏️  发送给矿工:', bundleStats.isSentToMiners);
        console.log('🧪 已模拟:', bundleStats.isSimulated);
        
        // 如果没有发送给矿工，提供简要分析
        if (!bundleStats.isSentToMiners) {
            console.log('❌ 捆绑交易未发送给矿工，可能原因：');
            console.log('   - Gas 费用不足或网络竞争激烈');
            console.log('   - Sepolia 测试网 Flashbots 支持有限');
        }
        
        // 显示时间信息
        if (bundleStats.submittedAt && bundleStats.simulatedAt) {
            const submitTime = new Date(bundleStats.submittedAt);
            const simulateTime = new Date(bundleStats.simulatedAt);
            console.log('⏱️  处理延迟:', simulateTime - submitTime, 'ms');
        }
    } catch (error) {
        console.log('⚠️  获取状态失败:', error.message);
    }

    // 检查交易状态
    console.log('🔍 检查交易哈希状态...');
    try {
        // 使用等待方法检查bundle状态
        const resolution = await bundleResponse.wait();
        console.log('📋 Bundle 等待结果:', resolution);
        
        // 尝试获取收据
        const receipts = await bundleResponse.receipts();
        if (receipts && receipts.length > 0) {
            receipts.forEach((receipt, index) => {
                if (receipt) {
                    console.log(`✅ 交易 ${index + 1} 已确认:`, {
                        txHash: receipt.transactionHash,
                        blockNumber: receipt.blockNumber,
                        gasUsed: receipt.gasUsed.toString(),
                        status: receipt.status === 1 ? 'SUCCESS' : 'FAILED'
                    });
                } else {
                    console.log(`❌ 交易 ${index + 1} 未找到收据`);
                }
            });
        } else {
            console.log('❌ 无法获取交易收据');
        }
    } catch (error) {
        console.log('⚠️  检查交易状态失败:', error.message);
        
        // 备用方法：直接从签名交易获取哈希
        try {
            const signedTransactions = await flashbotsProvider.signBundle(transactions);
            for (let i = 0; i < signedTransactions.length; i++) {
                const tx = ethers.Transaction.from(signedTransactions[i]);
                console.log(`📋 交易 ${i + 1} 哈希:`, tx.hash);
                
                const receipt = await provider.getTransactionReceipt(tx.hash);
                if (receipt) {
                    console.log(`✅ 交易 ${i + 1} 已确认:`, {
                        blockNumber: receipt.blockNumber,
                        gasUsed: receipt.gasUsed.toString(),
                        status: receipt.status === 1 ? 'SUCCESS' : 'FAILED'
                    });
                } else {
                    console.log(`❌ 交易 ${i + 1} 未找到收据`);
                }
            }
        } catch (backupError) {
            console.log('⚠️  备用方法也失败:', backupError.message);
        }
    }

    // 最终状态检查
    const finalNextTokenId = await contract.nextTokenId();
    console.log('📊 最终 Token ID:', finalNextTokenId.toString());
    console.log('🎉 完成!');
}

main().catch(error => {
    console.error('❌ 执行失败:', error.message);
    process.exit(1);
}); 