import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Sushi, Sushi__factory } from '../typechain-types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { parseUnits } from 'ethers/lib/utils';

describe('Sushi', function () {
  let sushi: Sushi;

  let owner: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    const Sushi: Sushi__factory = (await ethers.getContractFactory(
      'Sushi',
      owner
    )) as Sushi__factory;
    sushi = await Sushi.connect(owner).deploy(parseUnits('100000', 18));
    await sushi.deployed();
  });

  describe('constructor', async () => {
    it('Should check the initial supply', async () => {
      expect(await sushi.balanceOf(owner.address)).to.equal(parseUnits('100000', 18));
    });
  });

  describe('#setMinter', async () => {
    it('Should prevent if non-owner tries to modify the minter', async () => {
      // Check the owner
      await expect(sushi.connect(user).setMinter(user.address)).to.revertedWith(
        'Ownable: caller is not the owner'
      );
    });
    it('Should check the minter has modified', async () => {
      await expect(sushi.connect(owner).setMinter(user.address))
        .to.emit(sushi, 'MinterChanged')
        .withArgs(user.address);
    });
  });

  describe('#mint', async () => {
    it('Should prevent if non-minter tries to mint', async () => {
      // Check the owner
      await expect(sushi.connect(user).mint(user.address, 0)).to.revertedWith(
        'Access: Only minter can call this'
      );
    });
  });
});
