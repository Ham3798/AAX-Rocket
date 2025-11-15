# 배포된 컨트랙트 주소

## Monad Testnet
- **IntentGateway**: `0xE7fa3Ef3674a5097240641C9968976E9985c9dDf`

## Ethereum Sepolia
- **IntentExecutionHelper**: `0x2fa8846aFDb0AE2E1A63548B20a82af087BC136d`

---

# 배포 가이드

## 환경 변수 설정

```bash
export CHAIN_NAME=monad-testnet
export HELPER_NAME=ethereum-sepolia
export ETHEREUM_SEPOLIA_RPC_URL=<your_sepolia_rpc_url>
export MONAD_TESTNET_RPC_URL=<your_monad_rpc_url>
export INTENT_HELPER_PRIVATE_KEY=<your_helper_private_key>
export INTENT_GATEWAY_PRIVATE_KEY=<your_gateway_private_key>
```

## 배포 순서

### 1. IntentExecutionHelper 배포 (Ethereum Sepolia)

```bash
forge script script/DeployIntentHelper.s.sol:DeployIntentHelper \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $INTENT_HELPER_PRIVATE_KEY
```

배포 후 출력된 주소를 `configs/chains/helpers/ethereum-sepolia.json`의 `contracts.intentHelper`에 업데이트하세요.

### 2. IntentGateway 배포 (Monad Testnet)

```bash
forge script script/DeployIntentGateway.s.sol:DeployIntentGateway \
  --rpc-url $MONAD_TESTNET_RPC_URL \
  --broadcast \
  --private-key $INTENT_GATEWAY_PRIVATE_KEY
```

배포 후 출력된 주소를 `configs/chains/monad-testnet.json`의 `contracts.intentGateway`에 업데이트하세요.

### 3. IntentGateway에 Uniswap Router 설정 (Monad Testnet)

```bash
CHAIN_NAME=monad-testnet \
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $MONAD_TESTNET_RPC_URL \
  --broadcast \
  --private-key $INTENT_GATEWAY_PRIVATE_KEY
```

### 4. IntentGateway에 Helper 연결

```bash
CHAIN_NAME=monad-testnet HELPER_NAME=ethereum-sepolia \
forge script script/ConfigureIntent.s.sol:ConfigureIntentGateway \
  --rpc-url $MONAD_TESTNET_RPC_URL \
  --broadcast \
  --private-key $INTENT_GATEWAY_PRIVATE_KEY
```

### 5. IntentExecutionHelper에 Gateway 연결 및 Uniswap Router 설정

```bash
CHAIN_NAME=monad-testnet HELPER_NAME=ethereum-sepolia \
forge script script/ConfigureIntent.s.sol:ConfigureIntentHelper \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $INTENT_HELPER_PRIVATE_KEY
```

## 테스트

Intent 제출 예시:

```bash
export INTENT_GATEWAY=0xE7fa3Ef3674a5097240641C9968976E9985c9dDf
export SEPOLIA_SELECTOR=16015286601757825753

cast send $INTENT_GATEWAY \
    "submitIntent((uint64,address,uint256,uint256,uint256,uint64,uint256,bytes32))" \
    "(2183018362218727504,0xd00ae08403B9bbb9124bB305C09058E32C39A48c,1000000000000000000,100000000000000000,200,16015286601757825753,$(($(date +%s)+600)),0x000000000000000000000000000000000000000000000000000000000000abcd)" \
    --rpc-url $MONAD_TESTNET_RPC_URL \
    --private-key $INTENT_GATEWAY_PRIVATE_KEY \
    --value 1000000000000000000
```