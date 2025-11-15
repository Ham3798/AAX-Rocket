# 4337 Meme Buyer

CCIP를 활용한 크로스체인 Intent 기반 Meme 토큰 구매 시스템

## 배포된 컨트랙트 주소

### Monad Testnet
- **IntentGateway**: `0xE7fa3Ef3674a5097240641C9968976E9985c9dDf`
  - Chain ID: 10143
  - CCIP Router: `0x5f16e51e3Dcb255480F090157DD01bA962a53E54`
  - Uniswap Router: `0xfB8e1C3b833f9E67a71C859a132cf783b645e436`

### Ethereum Sepolia
- **IntentExecutionHelper**: `0x2fa8846aFDb0AE2E1A63548B20a82af087BC136d`
  - Chain ID: 11155111
  - CCIP Router: `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59`
  - Uniswap Router: `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3`

## 아키텍처

이 프로젝트는 Chainlink CCIP를 사용하여 Monad Testnet과 Ethereum Sepolia 간의 크로스체인 Intent 기반 거래를 구현합니다.

- **IntentGateway**: Monad Testnet에 배포되어 사용자의 BuyIntent를 수신하고 CCIP를 통해 Helper로 전달
- **IntentExecutionHelper**: Ethereum Sepolia에 배포되어 Intent를 실행하고 결과를 Gateway로 반환

## 배포 방법

자세한 배포 방법은 [DEPLOYMENT.md](./DEPLOYMENT.md)를 참조하세요.

## 설정 파일

- `configs/chains/monad-testnet.json`: Monad Testnet 설정
- `configs/chains/helpers/ethereum-sepolia.json`: Ethereum Sepolia Helper 설정

