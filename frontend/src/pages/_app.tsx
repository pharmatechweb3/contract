import { AppProps } from 'next/app';

import '@/styles/globals.css';
// !STARTERCONF This is for demo purposes, remove @/styles/colors.css import immediately
import '@/styles/colors.css';

import Header from '@/components/layout/Header';
import UnderlineLink from '@/components/links/UnderlineLink';

/**
 * !STARTERCONF info
 * ? `Layout` component is called in every page using `np` snippets. If you have consistent layout across all page, you can add it here too
 */

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <>
      <Header />
      <div className='container !h-full !w-full'>
        <Component {...pageProps} />
      </div>
      <footer className='bottom-2 text-gray-700'>
        © {new Date().getFullYear()} By{' '}
        <UnderlineLink href='https://github.com/ponny-io'>
          Ponny NextJS Template
        </UnderlineLink>
      </footer>
    </>
  );
}

export default MyApp;
