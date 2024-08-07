import "@rainbow-me/rainbowkit/styles.css";
import "@/styles/globals.css";

import React from 'react'; 
import { getDefaultWallets, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { configureChains, createConfig, WagmiConfig, createContext } from "wagmi";
import { sepolia } from "wagmi/chains";
import { publicProvider } from "wagmi/providers/public";
import { WalletConnectId } from "@/constants";


const { chains, publicClient } = configureChains([sepolia], [publicProvider()]);

const { connectors } = getDefaultWallets({
  appName: "Towerbank",
  projectId: WalletConnectId,
  chains,
});


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

