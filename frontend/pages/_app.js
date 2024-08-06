import "@rainbow-me/rainbowkit/styles.css";
import "@/styles/globals.css";

import React from 'react'; 
import { getDefaultWallets, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { configureChains, createConfig, WagmiConfig, createContext } from "wagmi";
import { sepolia } from "wagmi/chains";
import { publicProvider } from "wagmi/providers/public";
import { WalletConnectId } from "@/constants";
import TronWeb from 'tronweb'

const { chains, publicClient } = configureChains([sepolia], [publicProvider()]);

const { connectors } = getDefaultWallets({
  appName: "Tron Pay",
  projectId: WalletConnectId,
  chains,
});

 const PRIVATE_KEY = process.env.TRON_PRIVATE_KEY;
 const API_KEY = process.env.TRON_API_KEY;
// Se crea una instancia de TronWeb
const tronWeb = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  headers: { "TRON-PRO-API-KEY": API_KEY },
  privateKey: PRIVATE_KEY
})

// Se crea el contexto de React
const TronWebContext = React.createContext(null)

const wagmiConfig = createConfig({
  autoConnect: true,
  connectors,
  publicClient,
});


export default function App({ Component, pageProps }) {
  return (
    <WagmiConfig config={wagmiConfig}>
      <RainbowKitProvider chains={chains}>
        <Component {...pageProps} />      
      </RainbowKitProvider>
    </WagmiConfig>
  );
}

// Se crea el proveedor
// export const TronWebProvider = ({ children }) => {
//   return (
//     <TronWebContext.Provider value={tronWeb}>
//       {children}
//     </TronWebContext.Provider>
//   )
// }

// // Función App que envuelve la aplicación con TronWebProvider
// export default function App({ Component, pageProps }) {
//   return (
//     <TronWebProvider>
//       <Component {...pageProps} />
//     </TronWebProvider>
//   );
// }