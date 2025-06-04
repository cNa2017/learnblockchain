import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  Bought,
  Listed,
  TokensReceived,
  WhitelistPurchase
} from "../generated/NFTMarket/NFTMarket"

export function createBoughtEvent(
  tokenId: BigInt,
  buyer: Address,
  price: BigInt
): Bought {
  let boughtEvent = changetype<Bought>(newMockEvent())

  boughtEvent.parameters = new Array()

  boughtEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  boughtEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  boughtEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return boughtEvent
}

export function createListedEvent(
  tokenId: BigInt,
  seller: Address,
  price: BigInt
): Listed {
  let listedEvent = changetype<Listed>(newMockEvent())

  listedEvent.parameters = new Array()

  listedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  listedEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )
  listedEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return listedEvent
}

export function createTokensReceivedEvent(
  tokenId: BigInt,
  buyer: Address,
  price: BigInt,
  amount: BigInt
): TokensReceived {
  let tokensReceivedEvent = changetype<TokensReceived>(newMockEvent())

  tokensReceivedEvent.parameters = new Array()

  tokensReceivedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  tokensReceivedEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  tokensReceivedEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )
  tokensReceivedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return tokensReceivedEvent
}

export function createWhitelistPurchaseEvent(
  tokenId: BigInt,
  buyer: Address,
  price: BigInt
): WhitelistPurchase {
  let whitelistPurchaseEvent = changetype<WhitelistPurchase>(newMockEvent())

  whitelistPurchaseEvent.parameters = new Array()

  whitelistPurchaseEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  whitelistPurchaseEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  whitelistPurchaseEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return whitelistPurchaseEvent
}
