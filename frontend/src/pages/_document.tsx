/* eslint-disable @next/next/next-script-for-ga */
import { Head, Html, Main, NextScript } from 'next/document';

export default function Document() {
  return (
    <Html lang='en'>
      <Head>
        <link
          rel='preload'
          href='/fonts/inter-var-latin.woff2'
          as='font'
          type='font/woff2'
          crossOrigin='anonymous'
        />
      </Head>
      <script
        async
        src='https://www.googletagmanager.com/gtag/js?id=G-9LHQF8WF12'
      ></script>
      <script
        // strategy='afterInteractive'
        dangerouslySetInnerHTML={{
          __html: `
          window.dataLayer = window.dataLayer || []; 
          function gtag(){dataLayer.push(arguments)}
          gtag('js', new Date()); 

          gtag('config', 'G-9LHQF8WF12');
      `,
        }}
      />
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
