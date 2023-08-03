import * as React from 'react';

import Layout from '@/components/layout/Layout';

import Seo from '@/components/Seo';
import { Unity, useUnityContext } from 'react-unity-webgl';

export const Home = () => {
  const { unityProvider } = useUnityContext({
    loaderUrl: 'game/web.loader.js',
    dataUrl: 'game/web.data',
    frameworkUrl: 'game/web.framework.js',
    codeUrl: 'game/web.wasm',
  });

  return (
    <Layout>
      {/* <Seo templateTitle='Home' /> */}
      <Seo />

      <main>
        <section className='bg-white'>
          <Unity
            unityProvider={unityProvider}
            style={{ width: 800, height: 600, border: 'solid black 1px' }}
          />
        </section>
      </main>
    </Layout>
  );
};
