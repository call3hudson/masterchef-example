import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SushiLP, SushiLP__factory } from '../typechain-types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { parseUnits } from 'ethers/lib/utils';

describe('SushiLP', function () {
  let sushilp: SushiLP;

  let owner: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    const SushiLP: SushiLP__factory = (await ethers.getContractFactory(
      'SushiLP',
      owner
    )) as SushiLP__factory;
    sushilp = await SushiLP.connect(owner).deploy(parseUnits('100000', 18), 'Test Sushi LP', 'TSL');
    await sushilp.deployed();
  });

  describe('constructor', async () => {
    it('Should check the initial supply', async () => {
      // Check the initial supply
      expect(await sushilp.balanceOf(owner.address)).to.equal(parseUnits('100000', 18));
    });
  });
});
