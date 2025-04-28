import hashlib
import time

def find_hash(prefix_zeros):
    prefix_str = '0' * prefix_zeros
    nonce = 0
    start_time = time.time()
    text = "cna7_7"
    
    while True:
        input_data = text + str(nonce)
        hash_result = hashlib.sha256(input_data.encode()).hexdigest()
        
        if hash_result.startswith(prefix_str):
            end_time = time.time()
            execution_time = end_time - start_time
            return {
                'nonce': nonce,
                'hash_input': input_data,
                'hash_value': hash_result,
                'time': execution_time
            }
        nonce += 1

def main():
    # 寻找4个0开头的哈希值
    print("\n寻找4个0开头的哈希值...")
    result_4_zeros = find_hash(4)
    print(f"找到满足条件的哈希值！")
    print(f"花费时间: {result_4_zeros['time']:.2f} 秒")
    print(f"Hash内容: {result_4_zeros['hash_input']}")
    print(f"Hash值: {result_4_zeros['hash_value']}")
    
    # 寻找5个0开头的哈希值
    print("\n寻找5个0开头的哈希值...")
    result_5_zeros = find_hash(5)
    print(f"找到满足条件的哈希值！")
    print(f"花费时间: {result_5_zeros['time']:.2f} 秒")
    print(f"Hash内容: {result_5_zeros['hash_input']}")
    print(f"Hash值: {result_5_zeros['hash_value']}")

if __name__ == "__main__":
    main()