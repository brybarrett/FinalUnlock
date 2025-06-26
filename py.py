from Crypto.Hash import MD5, keccak

def calc_md5(data: str) -> str:
    return MD5.new(data.encode()).hexdigest()

def calc_keccak384(data: str) -> str:
    return keccak.new(data=data.encode(), digest_bits=384).hexdigest()

def show_activation_codes(machine_id: str):
    print('FinalShell < 3.9.6')
    print('🟡 高级版:', calc_md5(f'61305{machine_id}8552')[8:24])
    print('🟢 专业版:', calc_md5(f'2356{machine_id}13593')[8:24])
    print('FinalShell ≥ 3.9.6')
    print('🟡 高级版:', calc_keccak384(f'{machine_id}hSf(78cvVlS5E')[12:28])
    print('🟢 专业版:', calc_keccak384(f'{machine_id}FF3Go(*Xvbb5s2')[12:28])
    print('FinalShell 4.5')
    print('🟡 高级版:', calc_keccak384(f'{machine_id}wcegS3gzA$')[12:28])
    print('🟢 专业版:', calc_keccak384(f'{machine_id}b(xxkHn%z);x')[12:28])
    print('FinalShell 4.6')
    print('🟡 高级版:', calc_keccak384(f'{machine_id}csSf5*xlkgYSX,y')[12:28])
    print('🟢 专业版:', calc_keccak384(f'{machine_id}Scfg*ZkvJZc,s,Y')[12:28])

if __name__ == '__main__':
    user_input = input('请输入机器码:').strip()
    show_activation_codes(user_input)