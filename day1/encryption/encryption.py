import rsa
import hashlib

# 1. 生成RSA公私钥对
(pubkey, privkey) = rsa.newkeys(2048)

# 2. 工作量证明（POW），寻找符合条件的nonce
target = 'cna7_7'
nonce = 0
# 调整难度：此处检查哈希值的前4位十六进制是否为0（即前2个字节）
required_leading_zeros = '0000'
found = False
print("开始POW计算...")
while True:
    message = target + str(nonce)
    hash_hex = hashlib.sha256(message.encode()).hexdigest()
    if hash_hex.startswith(required_leading_zeros):
        found = True
        break
    nonce += 1
    # 防止无限循环，可设置退出条件（此处示例仅做演示）
    if nonce % 100000 == 0:
        print(f"已尝试 {nonce} 次...")
print(f"找到符合条件的nonce: {nonce}")
print(f"消息: {message}")
print(f"哈希值: {hash_hex}")

# 3. 使用私钥对消息进行签名
signature = rsa.sign(message.encode(), privkey, 'SHA-256')
print("\n签名结果:", signature.hex())

# 4. 使用公钥验证签名
try:
    rsa.verify(message.encode(), signature, pubkey)
    print("\n验证结果: 签名有效")
except rsa.VerificationError:
    print("\n验证结果: 签名无效")