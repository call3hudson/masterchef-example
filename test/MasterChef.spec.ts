import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  Sushi,
  SushiLP,
  MasterChef,
  Sushi__factory,
  SushiLP__factory,
  MasterChef__factory,
} from '../typechain-types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { parseUnits } from 'ethers/lib/utils';

describe('Masterchef', function () {
  let sushi: Sushi;
  let lp0: SushiLP;
  let lp1: SushiLP;
  let mc: MasterChef;

  let owner: SignerWithAddress;
  let user0: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  const v100000 = parseUnits('100000', 18);
  const v10000 = parseUnits('10000', 18);
  const v1000 = parseUnits('1000', 18);
  const v500 = parseUnits('500', 18);
  const v250 = parseUnits('250', 18);
  const v125 = parseUnits('125', 18);
  const v100 = parseUnits('100', 18);
  const v50 = parseUnits('50', 18);
  const v25 = parseUnits('25', 18);
  const v10 = parseUnits('10', 18);

  beforeEach(async () => {
    [owner, user0, user1, user2] = await ethers.getSigners();

    const Sushi: Sushi__factory = (await ethers.getContractFactory(
      'Sushi',
      owner
    )) as Sushi__factory;
    sushi = await Sushi.connect(owner).deploy(v100000);
    await sushi.deployed();

    const SushiLP: SushiLP__factory = (await ethers.getContractFactory(
      'SushiLP',
      owner
    )) as SushiLP__factory;
    lp0 = await SushiLP.connect(owner).deploy(v100000, 'Sushi LP Token0', 'SL0');
    await lp0.deployed();
    lp1 = await SushiLP.connect(owner).deploy(v100000, 'Sushi LP Token1', 'SL1');
    await lp1.deployed();

    const MasterChef: MasterChef__factory = (await ethers.getContractFactory(
      'MasterChef',
      owner
    )) as MasterChef__factory;

    // We initially set the allocation rates between two groups as 1:3
    mc = await MasterChef.connect(owner).deploy(sushi.address, 64);
    await mc.deployed();

    await sushi.setMinter(mc.address);
    await sushi.transfer(user0.address, v10000);
    await sushi.transfer(user1.address, v10000);
    await sushi.transfer(user2.address, v10000);

    await lp0.transfer(user0.address, v10000);
    await lp0.transfer(user1.address, v10000);
    await lp0.transfer(user2.address, v10000);

    await lp1.transfer(user0.address, v10000);
    await lp1.transfer(user1.address, v10000);
    await lp1.transfer(user2.address, v10000);
  });

  describe('constructor', () => {
    it('Should check the initial values', async () => {
      expect(await mc.sushi()).to.equal(sushi.address);
      expect(await mc.alloc2sushi()).to.equal(64);
    });
  });

  describe('#deposit', () => {
    it('Should check the input value', async () => {
      await expect(mc.deposit(0)).to.revertedWith('Params: Input value must be greater than zero');
    });

    it('Should check single deposit', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).deposit(v1000))
        .to.emit(mc, 'Deposited')
        .withArgs(user0.address, v1000, v1000);
      expect(await mc.totalDeposited()).to.equal(v1000);
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.sub(v1000));
    });

    it('Should check double deposits', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).deposit(v1000))
        .to.emit(mc, 'Deposited')
        .withArgs(user0.address, v1000, v1000);
      expect(await mc.totalDeposited()).to.equal(v1000);

      await sushi.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).deposit(v1000))
        .to.emit(mc, 'Deposited')
        .withArgs(user0.address, v1000, v1000.mul(2));
      expect(await mc.totalDeposited()).to.equal(v1000.mul(2));
      expect(await sushi.balanceOf(user0.address)).to.equal(
        v10000.sub(v1000.mul(2)).add(v10.mul(2))
      );
    });
  });

  describe('#depositLP', () => {
    it('Should check the input value', async () => {
      await expect(mc.depositLP(lp0.address, 0)).to.revertedWith(
        'Params: Input value must be greater than zero'
      );
    });

    it('Should check single deposit', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).depositLP(lp0.address, v1000))
        .to.emit(mc, 'LPDeposited')
        .withArgs(user0.address, lp0.address, v1000, v1000);
      expect(await mc.totalLPDeposited()).to.equal(v1000);
      expect(await lp0.balanceOf(user0.address)).to.equal(v10000.sub(v1000));
    });

    it('Should check double deposits', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).depositLP(lp0.address, v1000))
        .to.emit(mc, 'LPDeposited')
        .withArgs(user0.address, lp0.address, v1000, v1000);
      expect(await mc.totalLPDeposited()).to.equal(v1000);

      await lp0.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).depositLP(lp0.address, v1000))
        .to.emit(mc, 'LPDeposited')
        .withArgs(user0.address, lp0.address, v1000, v1000.mul(2));
      expect(await mc.totalLPDeposited()).to.equal(v1000.mul(2));

      expect(await lp0.balanceOf(user0.address)).to.equal(v10000.sub(v1000.mul(2)));
    });

    it('Should check double deposits with two users', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await expect(mc.connect(user0).depositLP(lp0.address, v1000))
        .to.emit(mc, 'LPDeposited')
        .withArgs(user0.address, lp0.address, v1000, v1000);
      expect(await mc.totalLPDeposited()).to.equal(v1000);

      await lp0.connect(user1).approve(mc.address, v1000);
      await expect(mc.connect(user1).depositLP(lp0.address, v1000))
        .to.emit(mc, 'LPDeposited')
        .withArgs(user1.address, lp0.address, v1000, v1000);
      expect(await mc.totalLPDeposited()).to.equal(v1000.mul(2));

      expect(await lp0.balanceOf(user0.address)).to.equal(v10000.sub(v1000));
      expect(await lp0.balanceOf(user1.address)).to.equal(v10000.sub(v1000));
    });
  });

  describe('#withdraw', () => {
    it('Should check the input value', async () => {
      await expect(mc.withdraw(0)).to.revertedWith('Params: Input value must be greater than zero');
      await expect(mc.withdraw(v1000)).to.revertedWith('Withdraw: Not enough Sushi');
    });

    it('Should check single withdraw', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).deposit(v1000);

      await expect(mc.connect(user0).withdraw(v1000))
        .to.emit(mc, 'Withdrawn')
        .withArgs(user0.address, v1000, 0);

      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.add(v10));
    });

    it('Should check double withdraws', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).deposit(v1000);

      await expect(mc.connect(user0).withdraw(v500))
        .to.emit(mc, 'Withdrawn')
        .withArgs(user0.address, v500, v500);

      await expect(mc.connect(user0).withdraw(v500))
        .to.emit(mc, 'Withdrawn')
        .withArgs(user0.address, v500, 0);

      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.add(v10.mul(2)));
    });
  });

  describe('#withdrawLP', () => {
    it('Should check the input value', async () => {
      await expect(mc.withdrawLP(lp0.address, 0)).to.revertedWith(
        'Params: Input value must be greater than zero'
      );
      await expect(mc.withdrawLP(lp0.address, v1000)).to.revertedWith(
        'WithdrawLP: Not enough SushiLP'
      );
    });

    it('Should check single withdraw', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).depositLP(lp0.address, v1000);

      await expect(mc.connect(user0).withdrawLP(lp0.address, v1000))
        .to.emit(mc, 'LPWithdrawn')
        .withArgs(user0.address, lp0.address, v1000, 0);
    });

    it('Should check double deposits', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await lp1.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).depositLP(lp0.address, v1000);
      await mc.connect(user0).depositLP(lp1.address, v1000);

      await expect(mc.connect(user0).withdrawLP(lp0.address, v1000))
        .to.emit(mc, 'LPWithdrawn')
        .withArgs(user0.address, lp0.address, v1000, 0);

      await expect(mc.connect(user0).withdrawLP(lp1.address, v1000))
        .to.emit(mc, 'LPWithdrawn')
        .withArgs(user0.address, lp1.address, v1000, 0);

      expect(await lp0.balanceOf(user0.address)).to.equal(v10000);
      expect(await lp1.balanceOf(user0.address)).to.equal(v10000);
    });
  });

  describe('#claim', () => {
    it('Should return no reward if nothing was deposited', async () => {
      await mc.connect(user0).claim();
    });

    it('Should check simple claim for sushi stakers', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).deposit(v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      // After 5 blocks...
      await expect(mc.connect(user0).claim()).to.emit(mc, 'Claimed').withArgs(user0.address, v50);
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.sub(v1000).add(v50));
    });

    it('Should check complex claim for sushi stakers', async () => {
      await sushi.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).deposit(v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await sushi.connect(user1).approve(mc.address, v1000);
      await mc.connect(user1).deposit(v1000); // After 5 blocks...

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      // After 5 blocks...
      await expect(mc.connect(user0).claim())
        .to.emit(mc, 'Claimed')
        .withArgs(user0.address, v50.add(v25));
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.sub(v1000).add(v50.add(v25)));

      await expect(mc.connect(user1).claim())
        .to.emit(mc, 'Claimed')
        .withArgs(user1.address, v10.mul(3)); // Notice that another one passed.
      expect(await sushi.balanceOf(user1.address)).to.equal(v10000.sub(v1000).add(v10.mul(3)));
    });

    it('Should check complex claim for both sushi stakers and lp stakers', async () => {
      await lp0.connect(user1).approve(mc.address, v1000);
      await mc.connect(user1).depositLP(lp0.address, v1000);

      await sushi.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).deposit(v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await sushi.connect(user1).approve(mc.address, v1000);
      await mc.connect(user1).deposit(v1000); // After 5 blocks...

      // After 5 blocks...
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await expect(mc.connect(user0).claim())
        .to.emit(mc, 'Claimed')
        .withArgs(user0.address, v50.add(v25).div(4));
      expect(await sushi.balanceOf(user0.address)).to.equal(
        v10000.sub(v1000).add(v50.add(v25).div(4))
      );

      await expect(mc.connect(user1).claim())
        .to.emit(mc, 'Claimed')
        .withArgs(user1.address, v10.mul(3).div(4)); // Notice that another one passed.
      expect(await sushi.balanceOf(user1.address)).to.equal(
        v10000.sub(v1000).add(v10.mul(3).div(4))
      );
    });
  });

  describe('#claimLP', () => {
    it('Should return no reward if nothing was deposited', async () => {
      await mc.connect(user0).claimLP(lp0.address);
    });

    it('Should check simple claim for lp stakers', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).depositLP(lp0.address, v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      // After 5 blocks...
      await expect(mc.connect(user0).claimLP(lp0.address))
        .to.emit(mc, 'LPClaimed')
        .withArgs(user0.address, lp0.address, v50);
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.add(v50));
    });

    it('Should check complex claim for lp stakers', async () => {
      await lp0.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).depositLP(lp0.address, v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await lp1.connect(user1).approve(mc.address, v1000);
      await mc.connect(user1).depositLP(lp1.address, v1000); // After 5 blocks...

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      // After 5 blocks...
      await expect(mc.connect(user0).claimLP(lp0.address))
        .to.emit(mc, 'LPClaimed')
        .withArgs(user0.address, lp0.address, v50.add(v25));
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.add(v50).add(v25));

      await expect(mc.connect(user1).claimLP(lp1.address))
        .to.emit(mc, 'LPClaimed')
        .withArgs(user1.address, lp1.address, v10.mul(3)); // Notice that another one passed.
      expect(await sushi.balanceOf(user1.address)).to.equal(v10000.add(v10.mul(3)));
    });

    it('Should check complex claim for both sushi stakers and lp stakers', async () => {
      await sushi.connect(user2).approve(mc.address, v1000);
      await mc.connect(user2).deposit(v1000);

      await lp0.connect(user0).approve(mc.address, v1000);
      await mc.connect(user0).depositLP(lp0.address, v1000);

      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await lp1.connect(user1).approve(mc.address, v1000);
      await mc.connect(user1).depositLP(lp1.address, v1000); // After 5 blocks...

      // After 5 blocks...
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);
      await ethers.provider.send('evm_mine', []);

      await expect(mc.connect(user0).claimLP(lp0.address))
        .to.emit(mc, 'LPClaimed')
        .withArgs(user0.address, lp0.address, v50.add(v25).mul(3).div(4));
      expect(await sushi.balanceOf(user0.address)).to.equal(v10000.add(v50.add(v25).mul(3).div(4)));

      await expect(mc.connect(user1).claimLP(lp1.address))
        .to.emit(mc, 'LPClaimed')
        .withArgs(user1.address, lp1.address, v10.mul(9).div(4)); // Notice that another one passed.
      expect(await sushi.balanceOf(user1.address)).to.equal(v10000.add(v10.mul(9).div(4)));
    });
  });

  describe('#setAllocationPoint', () => {
    it('Should revert if non-owner tries to modify the rate', async () => {
      await expect(mc.connect(user0).setAllocationPoint(128)).to.revertedWith(
        'Ownable: caller is not the owner'
      );
    });
    it('Should check the allocation rate has applied', async () => {
      await expect(mc.connect(owner).setAllocationPoint(128))
        .to.emit(mc, 'AllocPointModified')
        .withArgs(64, 128);
      expect(await mc.alloc2sushi()).to.equal(128);
    });
  });
});
