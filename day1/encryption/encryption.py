import rsa
import hashlib

def generate_rsa_keys():
    # 1. 生成RSA公私钥对
    return rsa.newkeys(2048)

def perform_pow(target, required_leading_zeros='0000'):
    nonce = 0
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
    return message, hash_hex, nonce

def sign_message(message, private_key):
    # 3. 使用私钥对消息进行签名
    return rsa.sign(message.encode(), private_key, 'SHA-256')

def verify_signature(message, signature, public_key):
    # 4. 使用公钥验证签名
    try:
        rsa.verify(message.encode(), signature, public_key)
        return True
    except rsa.VerificationError:
        return False

if __name__ == "__main__":
    target = 'cna7_7'
    
    # 生成RSA密钥对
    pubkey, privkey = generate_rsa_keys()
    
    # 执行工作量证明
    message, hash_hex, nonce = perform_pow(target)
    
    # 签名
    signature = sign_message(message, privkey)
    print("\n签名结果:", signature.hex())
    
    # 验证
    is_valid = verify_signature(message, signature, pubkey)
    print("\n验证结果: 签名有效" if is_valid else "\n验证结果: 签名无效")