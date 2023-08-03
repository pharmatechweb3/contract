import '@nomiclabs/hardhat-waffle';
import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

task('deploy', 'Deploy artwork contract').setAction(
  async (_, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const Artwork = await hre.ethers.getContractFactory('Greeter');
    const artwork = await Artwork.deploy('Greeter');

    await artwork.deployed();

    console.log('artwork deployed to:', artwork.address);
  }
);
