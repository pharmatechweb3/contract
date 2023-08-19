import '@nomiclabs/hardhat-waffle';
import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

task('deploy', 'Deploy token contract').setAction(
  async (_, hre: HardhatRuntimeEnvironment): Promise<void> => {
    // const signer = new hre.ethers.Wallet(
    //   '89314a2e5210e420ca7bf88b9b5e65f23be69a201be95d8b44977dbef5310b2d'
    // );

    const Token = await hre.ethers.getContractFactory('Token');
    const token = await Token.deploy();

    await token.deployed();

    console.log('token deployed to:', token.address);
  }
);
