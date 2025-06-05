import { Address, BigInt } from "@graphprotocol/graph-ts"
import {
  afterAll,
  assert,
  beforeAll,
  clearStore,
  describe,
  test
} from "matchstick-as/assembly/index"
import { handleBought, handleListed } from "../src/nft-market"
import { createBoughtEvent, createListedEvent } from "./nft-market-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#tests-structure

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let tokenId = BigInt.fromI32(234)
    let seller = Address.fromString("0x0000000000000000000000000000000000000002")
    let buyer = Address.fromString("0x0000000000000000000000000000000000000001")
    let price = BigInt.fromI32(234)
    
    // 先创建 Listed 事件
    let newListedEvent = createListedEvent(tokenId, seller, price)
    handleListed(newListedEvent)
    
    // 然后创建 Bought 事件
    let newBoughtEvent = createBoughtEvent(tokenId, buyer, price)
    handleBought(newBoughtEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#write-a-unit-test

  test("Bought created and stored", () => {
    assert.entityCount("Bought", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "Bought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "tokenId",
      "234"
    )
    assert.fieldEquals(
      "Bought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "buyer",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "Bought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "price",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#asserts
  })

  test("Listed created and stored", () => {
    assert.entityCount("Listed", 1)
    
    // 使用我们定义的 ID 格式
    assert.fieldEquals(
      "Listed",
      "listed-234",
      "tokenId",
      "234"
    )
    assert.fieldEquals(
      "Listed",
      "listed-234",
      "seller",
      "0x0000000000000000000000000000000000000002"
    )
    assert.fieldEquals(
      "Listed",
      "listed-234",
      "price",
      "234"
    )
  })

  test("Bought entity references Listed entity", () => {
    // 验证 Bought 实体正确引用了 Listed 实体
    assert.fieldEquals(
      "Bought",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "list",
      "listed-234"
    )
  })
})
