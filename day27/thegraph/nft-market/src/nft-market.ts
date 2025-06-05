import { Bytes } from "@graphprotocol/graph-ts"
import {
  Bought as BoughtEvent,
  Listed as ListedEvent,
  TokensReceived as TokensReceivedEvent,
  WhitelistPurchase as WhitelistPurchaseEvent
} from "../generated/NFTMarket/NFTMarket"
import {
  Bought,
  Listed,
  TokensReceived,
  WhitelistPurchase
} from "../generated/schema"

// 我们需要维护一个映射来跟踪 tokenId 到 Listed 实体的关系
// 为了简化，我们将使用一个基于 tokenId 的策略来建立关联

export function handleBought(event: BoughtEvent): void {
  let entity = new Bought(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenId = event.params.tokenId
  entity.buyer = event.params.buyer
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  // 查找对应的 Listed 实体
  // 使用基于 tokenId 的固定 ID 模式来找到对应的 Listed 实体
  let listedId = Bytes.fromUTF8("listed-" + event.params.tokenId.toString())
  let listedEntity = Listed.load(listedId)
  
  if (listedEntity) {
    entity.list = listedEntity.id
  } else {
    // 如果没有找到对应的 Listed 实体，创建一个占位符
    // 注意：这种情况在正常流程中不应该发生，因为应该先有 Listed 事件再有 Bought 事件
    // 但为了确保 schema 的完整性，我们创建一个占位符
    let placeholderListed = new Listed(listedId)
    placeholderListed.tokenId = event.params.tokenId
    placeholderListed.seller = Bytes.fromHexString("0x0000000000000000000000000000000000000000") // 占位符地址
    placeholderListed.price = event.params.price
    placeholderListed.blockNumber = event.block.number
    placeholderListed.blockTimestamp = event.block.timestamp
    placeholderListed.transactionHash = event.transaction.hash
    placeholderListed.save()
    
    entity.list = placeholderListed.id
  }

  entity.save()
}

export function handleListed(event: ListedEvent): void {
  // 使用基于 tokenId 的固定 ID 模式，这样 Bought 事件可以找到它
  let listedId = Bytes.fromUTF8("listed-" + event.params.tokenId.toString())
  let entity = new Listed(listedId)
  
  entity.tokenId = event.params.tokenId
  entity.seller = event.params.seller
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokensReceived(event: TokensReceivedEvent): void {
  let entity = new TokensReceived(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenId = event.params.tokenId
  entity.buyer = event.params.buyer
  entity.price = event.params.price
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleWhitelistPurchase(event: WhitelistPurchaseEvent): void {
  let entity = new WhitelistPurchase(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenId = event.params.tokenId
  entity.buyer = event.params.buyer
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
