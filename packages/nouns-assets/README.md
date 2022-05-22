# @nouns/assets

## Development

### Install dependencies

```sh
yarn
```

## Usage

**Access Noun RLE Image Data**

```ts
import { ImageData } from '@nouns/assets';

const { bgcolors, palette, images } = ImageData;
const { bodies, accessories, heads, glasses } = images;
```

**Get Noun Part & Background Data**

```ts
import { getNounData } from '@nouns/assets';

const seed = {
  background: 0,
  body: 17,
  accessory: 41,
  head: 71,
  glasses: 2,
};
const { parts, background } = getNounData(seed);
```

**Emulate `NounSeeder.sol` Pseudorandom seed generation**

```ts
import { getNounSeedFromBlockHash } from '@nouns/assets';

const blockHash = '0x5014101691e81d79a2eba711e698118e1a90c9be7acb2f40d7f200134ee53e01';
const nounId = 116;

/**
 {
    background: 1,
    body: 28,
    accessory: 120,
    head: 95,
    glasses: 15
  }
*/
const seed = getNounSeedFromBlockHash(nounId, blockHash);
```

## Examples

**Almost off-chain Noun Crystal Ball**
仅使用块哈希生成名词， 从而节省对 “NounSeeder” 和 “NounDescriptor” 合约的调用。 这可以用于更快的水晶球。

```ts
/** 
 * 供您实现： 
  - 使用 ether/web3.js 连接提供者 
  - 从 NounsAuctionHouse 合约中获取当前拍卖的名词 ID 
  - 将当前名词 ID 加 1 以获取下一个名词 ID（在下面命名为 `nextNounId`） 
  - 从你的提供者那里获取最新的区块哈希（下面命名为`latestBlockHash`）
*/


import { ImageData, getNounSeedFromBlockHash, getNounData } from '@nouns/assets';
import { buildSVG } from '@nouns/sdk';
const { palette } = ImageData; // Used with `buildSVG``

/**
 * OUTPUT:
   {
      background: 1,
      body: 28,
      accessory: 120,
      head: 95,
      glasses: 15
    }
*/
const seed = getNounSeedFromBlockHash(nextNounId, latestBlockHash);

/** 
 * OUTPUT:
   {
     parts: [
       {
         filename: 'body-teal',
         data: '...'
       },
       {
         filename: 'accessory-txt-noun-multicolor',
         data: '...'
       },
       {
         filename: 'head-goat',
         data: '...'
       },
       {
         filename: 'glasses-square-red',
         data: '...'
       }
     ],
     background: 'e1d7d5'
   }
*/
const { parts, background } = getNounData(seed);

const svgBinary = buildSVG(parts, palette, background);
const svgBase64 = btoa(svgBinary);
```

The Noun SVG can then be displayed. Here's a dummy example using React

```ts
function SVG({ svgBase64 }) {
  return <img src={`data:image/svg+xml;base64,${svgBase64}`} />;
}
```
