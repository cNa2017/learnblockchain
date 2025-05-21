```
  == Logs == ##升级前
  Deployer address: 0xc19973532a44DA4FB06FCF53CA5be909fde6788f
  Starting deployment of upgradeable NFT marketplace contracts...
  ERC20 token contract deployed: 0x5a1F096d568366ef5A9aDc86e4A2a761FcEe409E
  NFT implementation contract deployed: 0x720805a6BF48889bfD166Fc1A829df2b18eA88b7
  NFT proxy contract deployed: 0x3Cd01838509EAEf9E01DE6159A916dAfb6639367
  Market implementation contract deployed: 0x500287dFE1f82e6b91a15492E5966748D032C3C1
  Market proxy contract deployed: 0xab61b7a093125919f31Fd5de6438622f7E32f320
  Sample NFT minted, tokenId: 0
  Sample NFT listed, price: 0.1 ether
  =======================
  Deployment Summary:
  - ERC20 Token Contract: 0x5a1F096d568366ef5A9aDc86e4A2a761FcEe409E
  - NFT Implementation Contract: 0x720805a6BF48889bfD166Fc1A829df2b18eA88b7
  - NFT Proxy Contract: 0x3Cd01838509EAEf9E01DE6159A916dAfb6639367
  - Market Implementation Contract: 0x500287dFE1f82e6b91a15492E5966748D032C3C1
  - Market Proxy Contract: 0xab61b7a093125919f31Fd5de6438622f7E32f320
  =======================
  Next steps for upgrade:
  1. Deploy V2 implementation contracts
  2. Call upgradeToAndCall method on the proxy contracts
  3. Use signature features after upgrade
  =======================


  == Logs == ##升级后
  Upgrader address: 0xc19973532a44DA4FB06FCF53CA5be909fde6788f
  Starting NFT marketplace contract upgrade...
  NFT proxy address: 0x3Cd01838509EAEf9E01DE6159A916dAfb6639367
  Market proxy address: 0xab61b7a093125919f31Fd5de6438622f7E32f320
  NFT V2 implementation contract deployed: 0x2B45B3FF32AB8D0df21175601c44C88B7603cDF8
  Market V2 implementation contract deployed: 0x7535AF0D7a1D86efBe20BbF90DD63919A270961c
  NFT contract upgraded successfully
  Market contract upgraded successfully
  =======================
  Upgrade Summary:
  - NFT Proxy Address: 0x3Cd01838509EAEf9E01DE6159A916dAfb6639367
  - NFT V2 Implementation Contract: 0x2B45B3FF32AB8D0df21175601c44C88B7603cDF8
  - Market Proxy Address: 0xab61b7a093125919f31Fd5de6438622f7E32f320
  - Market V2 Implementation Contract: 0x7535AF0D7a1D86efBe20BbF90DD63919A270961c
  =======================
  Upgrade completed successfully!
  You can now use the new V2 features:
  1. Use permit for NFT authorization
  2. Use signature for NFT listing
  3. Use batch listing functionality


  == Logs == ##签名list
  User Address: 0xc19973532a44DA4FB06FCF53CA5be909fde6788f
  NFT minted successfully, TokenID: 1
  Starting demonstration of offline NFT authorization signature...
  NFT authorization successful, caller: 0xc19973532a44DA4FB06FCF53CA5be909fde6788f
  Authorization recipient: 0xab61b7a093125919f31Fd5de6438622f7E32f320
  NFT ID: 1
  Starting demonstration of offline NFT listing signature...
  Market contract authorized to operate all NFTs
  NFT signature listing successful!
  Seller: 0xc19973532a44DA4FB06FCF53CA5be909fde6788f
  NFT ID: 1
  Price: 100000000000000000
```

