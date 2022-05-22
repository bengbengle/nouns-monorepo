import { keccak256 as solidityKeccak256 } from '@ethersproject/solidity';
import { BigNumber, BigNumberish } from '@ethersproject/bignumber';
import { NounSeed, NounData } from './types';
import { images, bgcolors } from './image-data.json';

const { bodies, accessories, heads, glasses } = images;

/**
 * 使用名词种子获取编码部分和背景信息 
 * @param seed 名词种子
 */
export const getNounData = (seed: NounSeed): NounData => {
  return {
    parts: [
      bodies[seed.body],
      accessories[seed.accessory],
      heads[seed.head],
      glasses[seed.glasses],
    ],
    background: bgcolors[seed.background],
  };
};

/**
 * 生成随机名词种子 
 * @param seed 名词种子
 */
export const getRandomNounSeed = (): NounSeed => {
  return {
    background: Math.floor(Math.random() * bgcolors.length),
    body: Math.floor(Math.random() * bodies.length),
    accessory: Math.floor(Math.random() * accessories.length),
    head: Math.floor(Math.random() * heads.length),
    glasses: Math.floor(Math.random() * glasses.length),
  };
};

/**
 * 模拟按位 权限 和 uint cast 
 * @param value A Big Number 
 * @param shiftAmount 右移量 
 * @param uintSize 要转换的 uint 位大小
 */
export const shiftRightAndCast = (
  value: BigNumberish,
  shiftAmount: number,
  uintSize: number,
): string => {
  const shifted = BigNumber.from(value).shr(shiftAmount).toHexString();
  return `0x${shifted.substring(shifted.length - uintSize / 4)}`;
};

/**
 * 模拟 NounsSeeder.sol 伪随机选择部件的方法 
 * @param pseudorandomness 数字的十六进制表示 
 * @param partCount 伪随机选择的部件数量 
 * @param shiftAmount 右移量 
 * @param uintSize 的大小无符号整数
 */
export const getPseudorandomPart = (
  pseudorandomness: string,
  partCount: number,
  shiftAmount: number,
  uintSize: number = 48,
): number => {
  const hex = shiftRightAndCast(pseudorandomness, shiftAmount, uintSize);
  return BigNumber.from(hex).mod(partCount).toNumber();
};

/**
 * 模拟用于生成名词种子的 NounsSeeder.sol 方法 
 * @param nounId 用于创建伪随机性的名词 tokenId 
 * @param blockHash 用于创建伪随机性的块哈希
 */
export const getNounSeedFromBlockHash = (nounId: BigNumberish, blockHash: string): NounSeed => {
  const pseudorandomness = solidityKeccak256(['bytes32', 'uint256'], [blockHash, nounId]);
  return {
    background: getPseudorandomPart(pseudorandomness, bgcolors.length, 0),
    body: getPseudorandomPart(pseudorandomness, bodies.length, 48),
    accessory: getPseudorandomPart(pseudorandomness, accessories.length, 96),
    head: getPseudorandomPart(pseudorandomness, heads.length, 144),
    glasses: getPseudorandomPart(pseudorandomness, glasses.length, 192),
  };
};
