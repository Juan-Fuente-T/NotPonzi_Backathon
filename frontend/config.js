import { createPublicClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet, sepolia } from 'viem/chains'
 
// JSON-RPC Account
export const [account] = '0xe67F18c5064f12470Efc943798236edF45CF3Afb'
// Local Account
export const _account = privateKeyToAccount(...)
 
export const publicClient = createPublicClient({
  chain: sepolia,
  transport: http()
})