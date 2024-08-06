import {
  USDTAddress,
  USDTABI,
  TronPayAddress,
  TronPayABI,
} from "@/constants";
import { ethers } from 'ethers';
import { ConnectButton } from "@rainbow-me/rainbowkit";
import Head from "next/head";
import { useEffect, useState } from "react";
import { formatEther, parseUnits } from "viem/utils";
import { useAccount, useBalance, useContractRead, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { readContract, waitForTransaction, writeContract } from "wagmi/actions";
import styles from "../styles/Home.module.css";
import { Inter } from "next/font/google";
import ModalResumen from './modalResumen'; 
// import FormularioAnuncio from './formularioAnuncio'; 
import TronWeb from 'tronweb';

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
});
TronWeb 
export default function Home() {
 
  // Check if the user's wallet is connected, and it's address using Wagmi's hooks.
  const { address, isConnected } = useAccount();

  // State variable to know if the component has been mounted yet or not
  const [isMounted, setIsMounted] = useState(false);

  // State variable to show loading state when waiting for a transaction to go through
  const [loading, setLoading] = useState(false);

  // Fake NFT Token ID to purchase. Used when creating a proposal.
  const [fakeNftTokenId, setFakeNftTokenId] = useState("");
  // State variable to store all proposals in the DAO
  const [proposals, setProposals] = useState([]);
  // State variable to switch between the 'Create Proposal' and 'View Proposals' tabs
  const [selectedTab, setSelectedTab] = useState("");
  // const [version, setVersion] = useState('');
  const [stableAddress, setStableAddress] = useState('');
  const [approveValue, setApproveValue] = useState(0);
  const [seller, setSeller] = useState("");
  const [value, setValue] = useState("");
  // const [releaseNum, setReleaseNum] = useState(0);
  const [refundNumber, setRefundNumber] = useState(0);
  const [refundNumberNativeC, setRefundNumberNativeC] = useState(0);
  const [releaseNumber, setReleaseNumber] = useState(0);
  const [releaseNumberNativeC, setReleaseNumberNativeC] = useState(0);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [datosModal, setDatosModal] = useState({
    // cripto: "",
    // usdtAmount: "",
    amount: 0,
    price: 0,
    maximo: 0,
    minimo: 0,
    payment_mode: "",
    usdtSeleccionado: false,
    trxSeleccionado: false,
    location: "",
    conditions: ""
  });
  const [balanceOf, setBalanceOf] = useState("");
  
   async function createEscrow() {
    // console.log("VALOR value el CREAR Escrow: ", ethers.parseEther(value.toString()));
    // console.log("Address SELLER al CREAR el Escrow: ", seller);
    setLoading(true);
    try {
      const tx = await writeContract({
      // const tx = await useContractWrite({
        address: TronPayAddress,
        abi: TronPayABI,
        functionName: "createEscrow",
        // args: [0, seller, BigInt(value), USDTAddress],
        args: [seller, ethers.parseEther(value.toString()), USDTAddress],
      });
      const receipt = await waitForTransaction(tx);
      console.log("Receipt: ", receipt);
      console.log("Hash: ", receipt.hashBlock);
      window.alert("Se ha creado el Escrow")
      console.log('Transacción confirmada:', tx.hash);
    } catch (error) {
      console.error(error);
      window.alert(error);
    }
    setLoading(false);
  } 

    /// ================== Release Escrow  ==================
    async function releaseEscrow() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: 'releaseEscrow',
          args: [releaseNumber],      
      });
    
        // Espera a que la transacción se confirme
        await waitForTransaction(tx);
        window.alert("Se ha ejecutado el Escrow")
      } catch (error) {
        console.error('Error en la ejecución del escrow:', error);
        window.alert(error);
      }
      setLoading(false);
    }

    /// ================== Release Escrow Owner  ==================
    async function releaseEscrowOwner() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: 'releaseEscrowOwner',
          args: [releaseNumber],      
      });
    
        // Espera a que la transacción se confirme
        await waitForTransaction(tx);
        window.alert("Se ha ejecutado el Escrow")
      } catch (error) {
        console.error('Error en la ejecución del escrow:', error);
        window.alert(error);
      }
      setLoading(false);
    }

    /// ================== Devolver Escrow   ==================
    async function refundEscrow() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: 'refundBuyer',
          args: [refundNumber],      
      });
    
        // Espera a que la transacción se confirme
        const receipt = await waitForTransaction(tx);
        window.alert("Se ha devuelto el Escrow")
        console.log('Transacción confirmada:', receipt);
      } catch (error) {
        console.error('Error en la devolución del escrow:', error);
        window.alert(error);
      }
      setLoading(false);
    }

    

    // let _amountFeeSeller = ((_value *
    //         (400 * 10 ** 6)) /
    //         (100 * 10 ** 6)) / 1000;
/// ================== Create Escrow Native Coin ==================
  //  const seller = '0xC7873b6EE9D6EF0ac02d5d1Cef98ABEea01E29e2';
  //  const value = 100000000;
    // Function  to create  Escrows
    async function createEscrowNativeCoin() {
      // console.log("FEE y VALUE: ", (parseInt(fee) + 33) *2, value);
      setLoading(true);
      // let amountFeeBuyer = ((value * (feeBuyer * 10 ** 6)) DECIMALES, 6 USDT
      let amountFeeBuyer = ((parseFloat(value) * (fee * 10 ** 18)) /
            // (100 * 10 ** 6)) / 1000; DECIMALES, 6 USDT
            (100 * 10 ** 18)) / 1000;
      try {
        const tx = await writeContract({
        // const tx = await useContractWrite({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: "createEscrowNativeCoin",
          // args: [0, seller, BigInt(value), USDTAddress],
          args: [seller, ethers.parseEther(value.toString())],
          value: ethers.parseEther((value + amountFeeBuyer).toString()),
        });
        await waitForTransaction(tx);
        window.alert("Se ha creado el Escrow")
        console.log("Hash", tx.hash);
        console.log('Transacción confirmada:', tx);
      } catch (error) {
        console.error(error);
        window.alert(error);
      }
      setLoading(false);
    } 

    
    /// ================== Release Escrow Native Coin  ==================
    async function releaseEscrowNativeCoin() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: 'releaseEscrowNativeCoin',
          args: [releaseNumberNativeC],      
      });
    
        // Espera a que la transacción se confirme
        await waitForTransaction(tx);
        // const receipt = await waitForTransaction(tx);
        window.alert(`Se ha ejecutado el Escrow con este hash: ${tx.hash}`);
        console.log('Ejecución confirmada:', tx.hash);
      } catch (error) {
        console.error('Error en la ejecución del escrow:', error);
        window.alert(error);
      }
      setLoading(false);
    }


    /// ================== Release Escrow Native Coin  Owner ==================
    async function releaseEscrowNativeCoinOwner() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: TronPayAddress,
          abi: TronPayABI,
          functionName: 'releaseEscrowOwnerNativeCoin',
          args: [releaseNumberNativeC],      
      });
    
        // Espera a que la transacción se confirme
        await waitForTransaction(tx);
        // const receipt = await waitForTransaction(tx);
        window.alert(`Se ha ejecutado el Escrow con este hash: ${tx.hash}`);
        console.log('Ejecución confirmada:', tx.hash);
      } catch (error) {
        console.error('Error en la ejecución del escrow:', error);
        window.alert(error);
      }
      setLoading(false);
    }
    
        /// ================== Devolver Escrow Native Coin  ==================
        async function refundEscrowNativeCoin() {
          setLoading(true);
          try {
            const tx = await writeContract({
              address: TronPayAddress,
              abi: TronPayABI,
              functionName: 'refundBuyerNativeCoin',
              args: [refundNumberNativeC],      
          });
        
            // Espera a que la transacción se confirme
            await waitForTransaction(tx);
            window.alert(`Se ha devuelto el Escrow con este hash: ${tx.hash}`);
            console.log('Devolución confirmada:', tx.hash);
          } catch (error) {
            console.error('Error en la devolución del escrow:', error);
            window.alert(error);
          }
          setLoading(false);
        }
        /// ================== Withdraw fees ==================
        async function withdrawFees() {
          setLoading(true);
          try {
            const tx = await writeContract({
              address: TronPayAddress,
              abi: TronPayABI,
              functionName: 'withdrawFees',
              args: [USDTAddress], //Recoge las Fees guardadas correpondientes a USDT 
          });
        
            // Espera a que la transacción se confirme
            await waitForTransaction(tx);
            window.alert(`Se ha devuelto el Escrow con este hash: ${tx.hash}`);
            console.log('Devolución confirmada:', tx.hash);
          } catch (error) {
            console.error('Error en la devolución del escrow:', error);
            window.alert(error);
          }
          setLoading(false);
        }
        /// ================== Withdraw fees Native Coin ==================
        async function withdrawFeesNativeCoin() {
          setLoading(true);
          try {
            const tx = await writeContract({
              address: TronPayAddress,
              abi: TronPayABI,
              functionName: 'withdrawFeesNativeCoin',    
          });
        
            // Espera a que la transacción se confirme
            await waitForTransaction(tx);
            window.alert(`Se ha devuelto el Escrow con este hash: ${tx.hash}`);
            console.log('Devolución confirmada:', tx.hash);
          } catch (error) {
            console.error('Error en la devolución del escrow:', error);
            window.alert(error);
          }
          setLoading(false);
        }
    /// ================== Fee Buyer ==================
    const feeBuyer = useContractRead({
      abi: TronPayABI,
      address: TronPayAddress,
  functionName: "feeBuyer",
});
let fee = parseFloat(feeBuyer.data);
// setVersion(versionTronPay.data);
// console.log("FEE BUYER: ", parseInt(fee));
// console.log("FeeBuyer:", parseInt(feeBuyer.data));

    /// ================== Version Escrow ==================
const versionTronPay = useContractRead({
  abi: TronPayABI,
  address: TronPayAddress,
  functionName: "version",
});
// setVersion(versionTronPay.data);
// console.log("Version:", versionTronPay.data);


  /// ================== Añadir Stable Coin ==================
   async function addStableAddress(stableAddress) {
    setLoading(true);
    try {
      const tx = await writeContract({
        address: TronPayAddress,
        abi: TronPayABI,
        functionName: "addStablesAddresses",
        args: [USDTAddress],
      });

      await waitForTransaction(tx);
      window.alert("Se ha añadido correctamente a la lista de addresses")

    } catch (error) {
      console.error(error);
      window.alert(error);
    }
    setLoading(false);
  } 
 
  
 
  // Fetch the balance of the DAO
  // const daoBalance = useBalance({
  //   address: CryptoDevsDAOAddress,
  // });

/// ================== User Balance ==================
  const userBalance = useContractRead({
    abi: USDTABI,
    address: USDTAddress,
    functionName: "balanceOf",
    args: [address]
  });
 
// console.log("UserBalance: ", userBalance.data);
if (userBalance.data != null){
  // console.log("UserBalance: ", ethers.formatEther(userBalance.data));
}

/// ================== Escrow 0 Value  ==================
  const escrowValue = useContractRead({
    abi: TronPayABI,
    address: TronPayAddress,
    functionName: "getValue",
    args: [0],
  });
  // console.log("EscrowValue",escrowValue);

  /// ================== Escrow 0 State  ==================
  // Fetch the state of Escrow
  const escrowState = useContractRead({
    abi: TronPayABI,
    address: TronPayAddress,
    functionName: "getState",
    args: [0],
  });
  // console.log("EscrowState",escrowState);

  /// ================== Get OrderID  ==================
  // Fetch the state of Escrow
  const orderId = useContractRead({
    abi: TronPayABI,
    address: TronPayAddress,
    functionName: "orderId",
  });
  let newEscrow= parseInt(orderId.data);
  // orderId?console.log("ORDERID", orderId) && console.log("ORDERID", parseInt(orderId.data)): console.log("ORDERID", "NO HAY");
  // newEscrow? console.log("NewEscrow", newEscrow): console.log("NewEscrow", "NO HAY");
  

  /// ================== Get scrow 0E  ==================
  // Fetch the state of Escrow
  const lastEscrow = useContractRead({
    abi: TronPayABI,
    address: TronPayAddress,
    functionName: "getEscrow",
    args: [newEscrow - 1],
  });
  if(lastEscrow.data){
    // console.log("lastEscrowData",lastEscrow.data.buyer);
    // console.log("lastEscrowBuyer",lastEscrow.data.buyer);
  }
  
  /// ================== Owner del protocolo  ==================
  const owner = useContractRead({
    
    abi: TronPayABI,
    address: TronPayAddress,
    functionName: "owner",
  });
  // console.log("OWNER",owner.data);

/// ================== Allowance en USDT  ==================
  const allowance = useContractRead({
    abi: USDTABI,
    address: USDTAddress,
    functionName: "allowance",
    args: [address, TronPayAddress]//esta es la address del protocolo
  })
  if(allowance && allowance.data){
    // console.log("ALLOWANCE: ", formatEther(allowance.data));

  }

  /// ================== Approve el user a Tronpay  ==================
    // Approve Necesita introducir numero con 6 decimales
    async function approve() {
      setLoading(true);
      try {
        const tx = await writeContract({
          address: USDTAddress,
          abi: USDTABI,
          functionName: 'approve',
          args: [TronPayAddress, ethers.parseEther(approveValue.toString())],     
      });
        // Espera a que la transacción se confirme
        const receipt = await waitForTransaction(tx);//funciona bien, no lo uso ahora
        await waitForTransaction(tx);
        window.alert("Se ha realizado el approve")
        console.log('Transacción confirmada:', tx.hash);
        // console.log('Receipt :', receipt);
      } catch (error) {
        console.error('Error en el approve:', error);
        window.alert(error);
      }
      setLoading(false);
    }


  const handleChange = (e) => {
    const { name, value, type } = e.target;
  
    if (type === "radio" && name === "cripto") {
      setDatosModal(prevState => ({
        ...prevState,
        cripto: value,
        amount: "", // Opcional: limpia la cantidad disponible si cambias de cripto
        price: "", // Opcional: limpia el precio por unidad si cambias de cripto
        payment_mode: "", // Opcional: limpia el modo de pago si cambias de cripto
      }));
    } else {
      setDatosModal(prevState => ({
        ...prevState,
        [name]: value
      }));
    }
  };
  
  
  
  const handleSubmitModal = (e) => {
    e.preventDefault();
    console.log("DatosModal, linea 541", datosModal);
    abrirModal(datosModal);
  };
  
  const abrirModal = (datos) => {
    console.log(datos); // Ahora deberías ver los datos actualizados
    // setDatosModal(datos);
    setIsModalOpen(true);
  };

  const cerrarModal = () => {
    setIsModalOpen(false);
  };

  {isModalOpen && (
    <ModalResumen
      onCloseModal={() => setIsModalOpen(false)}
      // cripto={datosModal.usdtSeleccionado? "USDT" : "TRX"}
      cripto={datosModal.usdtSeleccionado? "USDT" : "ETH"}
      amount={datosModal.amount}
      price={datosModal.price}
      payment_mode={datosModal.payment_mode}
    />
  )}
  
  // Function to fetch a proposal by it's ID
  async function fetchProposalById(id) {
    try {
      const proposal = await readContract({
        address: CryptoDevsDAOAddress,
        abi: CryptoDevsDAOABI,
        functionName: "proposals",
        args: [id],
      });

      const [nftTokenId, deadline, yayVotes, nayVotes, executed] = proposal;

      const parsedProposal = {
        proposalId: id,
        nftTokenId: nftTokenId.toString(),
        deadline: new Date(parseInt(deadline.toString()) * 1000),
        yayVotes: yayVotes.toString(),
        nayVotes: nayVotes.toString(),
        executed: Boolean(executed),
      };

      return parsedProposal;
    } catch (error) {
      console.error(error);
      window.alert(error);
    }
  }

  // Function to fetch all proposals in the DAO
  async function fetchAllProposals() {
    try {
      const proposals = [];

      for (let i = 0; i < numOfProposalsInDAO.data; i++) {
        const proposal = await fetchProposalById(i);
        proposals.push(proposal);
      }

      setProposals(proposals);
      return proposals;
    } catch (error) {
      console.error(error);
      window.alert(error);
    }
  }


  const crearAnuncio = (datosModal) => {
    // Aquí va la lógica para crear la oferta
    console.log("Creando oferta con datos:", datosModal);
    // cerrarModal(); 
    // Ejemplo: enviar los datos a una API o realizar otra acción
  };
  // Render the contents of the appropriate tab based on `selectedTab`
  function renderTabs() {
    if (selectedTab === "Anuncio USDT") {
      return renderCreateUsdtOffer();
    // } else if (selectedTab === "Anuncio TRX") {
    } else if (selectedTab === "Anuncio ETH") {
      // return renderCreateTrxOffer();
      return renderCreateEthOffer();
    }
    return null;
  }

  // Renders the 'Create Proposal' tab content
  function renderCreateUsdtOffer(){
    if (loading) {
      return (
        <div className={styles.description}>
          Loading... Waiting for transaction...
        </div>
      );
    } else if (!address) {

      return (
        <div className={styles.description}>
          You do not own any CryptoDevs NFTs. <br />
          <b>You cannot create or vote on proposals</b>
        </div>
      );
    } else {
        return (
            <div className={styles.description}>
            <form  onSubmit={handleSubmitModal}>
            <div className={styles.container}>
                <input type="radio" id="usdt" name="crypto" value="usdt" checked={datosModal.usdt} onChange={handleChange}></input>
                <label for="usdt">USDT</label><br></br>
        {/*         <input type="radio" id="trx" name="crypto" value="trx" checked={datosModal.trx} onChange={handleChange}></input> */}
                <input type="radio" id="eth" name="crypto" value="eth" checked={datosModal.eth} onChange={handleChange}></input>
        {/*         <label for="trx">TRX</label> */}
                <label for="eth">ETH</label>
            </div>
            <div>
                <label for="amount">Cantidad</label><br></br>
                <input type="number" id="amount" name="amount" min="0.001"placeholder="Cantidad" value={datosModal.amount}
                  onChange={handleChange}></input>

                <label for="price">Precio por unidad</label><br></br>
                <input type="number" id="price" name="price" min="0.001" placeholder="Precio unidad en USD" value={datosModal.price}
                  onChange={handleChange}></input>

                <label for="minimo">Límite máximo de venta</label><br></br>
                <input type="number" id="maximo" name="maximo" min="0" placeholder="Límite máximo de venta" value={datosModal.maximo}
                  onChange={handleChange}></input>

                <label for="minimo">Límite mínimo de venta</label><br></br>
                <input type="number" id="minimo" name="minimo" min="0" placeholder="Límite mínimo de venta" value={datosModal.minimo}
                  onChange={handleChange}></input>

                <label for="payment_mode">Modo de pago</label><br></br>
                <div>
                <select name="payment_mode" value={datosModal.payment_mode}
                onChange={handleChange}>
                  <option value="">Seleccione un modo de pago</option>
                  <option value="efectivo">Efectivo</option>
                  <option value="tarjeta">Tarjeta</option>
                  <option value="transferencia_bancaria">Transferencia</option>
               </select>
               </div>
                <label for="location">Ubicación</label><br></br>
                <input type="text" id="location" name="location" placeholder="Ubicación" 
                value={datosModal.location} onChange={handleChange}></input>
                <label for="conditions">Condiciones de la venta</label><br></br>
                <textarea id="conditions" name="conditions" placeholder="Condiciones de la venta" rows="6" cols="50"
                value={datosModal.conditions} onChange={handleChange}></textarea> 
            </div>
            {/* <input
                placeholder="0"
                type="number"
                onChange={(e) => setFakeNftTokenId(e.target.value)}
            /> */}
              {/* <button className={styles.button2} onClick={renderCreateUsdtOffer}>
                 Create
                </button>  */}
            <button type="submit">Crear Oferta USDT</button>
             {/* necesario agregar esto al final de la funcion que que crea la Oferta
            console.log("Creando oferta con:", formularioDatos);
          cerrarModal();  */}
          </form>
          {/* <FormularioAnuncio handleSubmitModal = {handleSubmitModal}/> */}
          <div style={{ position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000 }}>
          {isModalOpen && (
        <ModalResumen
          onCloseModal={() => setIsModalOpen(false)}
          datosModal={datosModal}
          crearAnuncio={crearAnuncio}
        />
      )}
      </div>
        </div>
      );
    }
  }

  // Renders the 'View Proposals' tab content
  // function renderCreateTrxOffer() {
  function renderCreateEthOffer() {
    if (loading) {
      return (
        <div className={styles.description}>
          Loading... Esperando por la transacción...
        </div>
      );
    } else if (proposals.length === 0) {
      return (
        <div className={styles.description}>No se han generados</div>
      );
    } else {
      return (
        <div>
          {/* {proposals.map((p, index) => (
            <div key={index} className={styles.card}>
              <p>Deadline: {p.deadline.toLocaleString()}</p>
          
              <p>Executed?: {p.executed.toString()}</p>
              {p.deadline.getTime() > Date.now() && !p.executed ? (
                <div className={styles.flex}>
                  
                
                </div>
              ) : p.deadline.getTime() < Date.now() && !p.executed ? (
                <div className={styles.flex}>
                 
                  
                </div>
              ) : (
                <div className={styles.description}>Anuncio terminado</div>
              )}
            </div>
          ))} */}
        </div>
      );
    }
  }

  



  // Piece of code that runs everytime the value of `selectedTab` changes
  // Used to re-fetch all proposals in the DAO when user switches
  // to the 'View Proposals' tab
  useEffect(() => {
    if (selectedTab === "View Proposals") {
      fetchAllProposals();
    }
  }, [selectedTab]);

  useEffect(() => {
    setIsMounted(true);
    setBalanceOf(userBalance?.data);
  }, []);

  if (!isMounted) return null;

  if (!isConnected)
    return (
      <div>
        <ConnectButton className={styles.connectButton} />
        <div className={styles.mainContainer}>
        <h1>TRON PAY</h1>
        <p>El intercambio de USDT - USD entre particulares</p>
        <p>De onchain a offchain a través de Tron</p>
        <div className={styles.textContainer}>
          <p>RÁPIDO</p>
          <p>EFICIENTE</p>
          <p>SEGURO</p>
        </div>
        </div>
      </div>
    );
    
    const handleSubmit = (e) => {
      e.preventDefault();
      addStableAddress(stableAddress);
    }; 
    const handleSubmitApprove = (e) => {
      e.preventDefault();
      approve();
    }; 

  return (
    <div className={inter.className}>
      <Head>
        <title>Tron Pay</title>
        <meta name="description" content="Tron Pay" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      {/* Your CryptoDevs NFT Balance: {nftBalanceOfUser.data.toString()} */}
      {/* {formatEther(daoBalance.data.value).toString()} ETH */}
      <div className={styles.main}>
        <div>
          <div className={styles.containerTitle}>
            <h1 className={styles.title}>Tron Pay</h1>
            <img className={styles.logo} src="/tron_pay_logo.png" alt="Logo de TronPay, intercambio p2p de criptomonedas" />

              <p id="textVersion">Version: {versionTronPay.data}</p>
            <p className={styles.description}>Peer to Peer USDT Exchange!</p>
            <p className={styles.description}>Intercambio de USDT peer to peer </p>
          </div>

          <div className={styles.containerCrear}>
            {/* <div> */}

              {/* <div className={styles.inputs}>
                <div>
                  <label className="block text-purple-500 text-sm font-bold mb-2" htmlFor="price">Valor del Scrow(en ETH)</label>
                  <input className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight 
                  focus:outline-none focus:shadow-outline" type="number" placeholder="Min 0.01 ETH" step="0.001"
                  value={value} onChange={(e) => setValue((e.target.value))}></input>
                </div>
                <div>
                  <label className="block text-purple-500 text-sm font-bold mb-2" htmlFor="price">Address del seller</label>
                  <input className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight 
                  focus:outline-none focus:shadow-outline" type="text" placeholder="Address del seller" 
                  value={seller} onChange={(e) => setSeller((e.target.value))}></input>
                </div>
              <button onClick={createEscrow}>Crear Escrow</button>
              </div> */}
              <div className={styles.inputs}>
                <div className={styles.containerEscrow}>
                  {/* <label  htmlFor="price">Valor del Scrow(6 decimales)</label> */}
                  <label  htmlFor="price">Valor del Scrow(18 decimales)</label>
                  <input  type="number" placeholder="Min 0.01 ETH" step="0.001" min="0"
                  value={value} onChange={(e) => setValue((e.target.value))}></input>
                </div>
                <div className={styles.containerEscrow}>
                  <label  htmlFor="price">Address del seller</label>
                  <input  type="text" placeholder="Address" 
                  value={seller} onChange={(e) => setSeller((e.target.value))}></input>
                </div>
                <div className={styles.buttons}>
                <button onClick={createEscrow}>Crear Scrow USDT</button> 
                {/* <button onClick={createEscrowNativeCoin}>Crear Escrow TRX</button> */}
                <button onClick={createEscrowNativeCoin}>Crear Scrow ETH</button>
                </div>
              </div>
              {/* <div className={styles.containerCompletar}> */}
              <div className={styles.inputs}>
                {/* {hash && <div>Transaction Hash: {hash}</div>} */}
                {/* {isConfirming && <div>Waiting for confirmation...</div>}  */}
                {/* {isConfirmed && <div>Transaction confirmed.</div>}  */}
                <div className={styles.containerEscrow}>
                  <label  htmlFor="price">Número de Escrow USDT a completar</label>
                  <input  type="number" placeholder="USDT a completar" min="0"
                  value={releaseNumber} onChange={(e) => setReleaseNumber((e.target.value))}></input>
                </div>
                  <div className={styles.containerEscrow}>
                    {/* <label htmlFor="price">Número de Escrow TRX a completar</label> */}
                    <label htmlFor="price">Número de Escrow ETH a completar</label>
                    {/* <input  type="number" placeholder="TRX a devolver" min="0" */}
                    <input  type="number" placeholder="ETH a devolver" min="0"
                    value={releaseNumberNativeC} onChange={(e) => setReleaseNumberNativeC((e.target.value))}></input>
                  </div>
                  <div className={styles.buttons}>
                    <button onClick={releaseEscrow}>Release Escrow USDT</button>
                    {/* <button onClick={releaseEscrowNativeCoin}>Release Escrow TRX</button> */}
                    <button onClick={releaseEscrowNativeCoin}>Release Escrow ETH</button>
                  </div>
              </div>
              <div>
              {/* {orderId && <p>Order: {parseInt(orderId.data)}</p>} */}
              </div>
            {/* </div>  */}
          </div>
          
                      <div className={styles.containerApprove}>
                    <form className={styles.approve_addStable} onSubmit={handleSubmitApprove}>
                      <input type="number" placeholder="Valor a aprobar" 
                      value={approveValue} min={0} step="0.001" onChange={(e) => setApproveValue(e.target.value)} />
                      <button type="submit">Approve</button>
                    </form> 
                    <div>
                    {userBalance.data && <p id="userBalance">USDT user balance: {formatEther(userBalance.data)}</p>}
                      </div>  
              </div>
          <div className={styles.containerData}>
                    
            {/* <h1 className={styles.title}>Tron Pay</h1> */}
            
              <div className={styles.containerLastEscrow}>
                  <div className={styles.lastEscrowTitle}>
                    <h3>Ultimo Escrow listado</h3>
                  </div>
                  <div className={styles.lastEscrowData}>
                    {lastEscrow && lastEscrow.data && <p>Dueño del Escrow (Comprador): {lastEscrow.data.buyer}</p>}
                    {lastEscrow && lastEscrow.data && <p>Dirección del Vendedor: {lastEscrow.data.seller}</p>}
                    {lastEscrow && lastEscrow.data && <p>Valor: {formatEther(lastEscrow.data.value)}</p>}
                    {lastEscrow && lastEscrow.data && <p>Estado: {parseInt(lastEscrow.data.status)}</p>}
                    {orderId && orderId.data && <p>Numero de Escrow: {parseInt(orderId.data) - 1}</p>}
                  </div>
              </div>

              <div className={styles.description}>
                {/*<p>Valor del Escrow: {parseInt(escrowValue.data)}</p>*/}
                {/*<p>//Estado del Escrow: {parseInt(escrowState.data)}*/}
                {allowance && allowance.data && <p>Allowance: {formatEther((allowance.data))}</p>}
                {/*{lastEscrow && lastEscrow.data && <p>EscrowBuy: {lastEscrow.data.buyer}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowSel: {lastEscrow.data.seller}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowVal: {formatEther(lastEscrow.data.value)}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowSfee: {formatEther(lastEscrow.data.sellerfee)}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowBfee: {formatEther(lastEscrow.data.buyerfee)}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowSta: {lastEscrow.data.status}</p>}
                {lastEscrow && lastEscrow.data && <p>EscrowCurr: {lastEscrow.data.currency}</p>} /*}
                  {/* {owner.data && <p>Owner: {owner.data}</p>} */}
                  </div>  
              {renderTabs()}
              {/* Display additional withdraw button if connected wallet is owner */}
              {address && address.toLowerCase() === owner?.data?.toLowerCase() ? (
              <div>
                {loading ? (
                  <button className={styles.button}>Loading...</button>
                ) : (<div>
                <div> 
                  <div className={styles.containerRefunds}>
                    <p>Devolver escrow al dueño (Solo Owner)</p> 
                  <div className={styles.containerEscrowOwner}>
                      <label htmlFor="price">Número de Escrow USDT a devolver</label>
                      <input type="number" placeholder="Número Escrow USDT" min="0"
                      value={refundNumber} onChange={(e) => setRefundNumber((e.target.value))}></input>
                      <div className={styles.divRelease}>
                      <button onClick={refundEscrow}>Devolver USDT</button>
                      </div>
                  </div>
                  <div className={styles.containerEscrowOwner}>
                    {/* <label htmlFor="price">Número de Escrow TRX a devolver</label> */}
                    <label htmlFor="price">Número de Escrow ETH a devolver</label>
                    {/* <input type="number" placeholder="Número Escrow TRX" min="0" */}
                    <input type="number" placeholder="Número Escrow ETH" min="0"
                    value={refundNumberNativeC} onChange={(e) => setRefundNumberNativeC((e.target.value))}></input>
                    <div className={styles.divRelease}>
                    {/* <button onClick={refundEscrowNativeCoin}>Devolver TRX</button> */}
                    <button onClick={refundEscrowNativeCoin}>Devolver ETH</button>
                    </div>
                  </div>
                </div>
                <div className={styles.containerReleases}>
                    <p>Liberar escrow al vendedor (Solo Owner)</p>
                  <div className={styles.containerEscrowOwner}>
                    <label htmlFor="price">Número de Escrow USDT a liberar</label>
                    {/* <input type="number" placeholder="Número Escrow TRX" min="0"  */}
                    <input type="number" placeholder="Número Escrow ETH" min="0" 
                    value={releaseNumber} onChange={(e) => setReleaseNumber((e.target.value))}></input>
                    <div className={styles.divRelease}>
                    <button onClick={releaseEscrowOwner}>Liberar USDT</button>
                    </div>
                  </div>
                  <div className={styles.containerEscrowOwner}>
                    {/* <label htmlFor="price">Número de Escrow TRX a liberar</label> */}
                    <label htmlFor="price">Número de Escrow ETH a liberar</label>
                    {/* <input type="number" placeholder="Número Escrow TRX" min="0" */}
                    <input type="number" placeholder="Número Escrow ETH" min="0"
                    value={releaseNumberNativeC} onChange={(e) => setReleaseNumberNativeC((e.target.value))}></input>
                    <div className={styles.divRelease}>
                    {/* <button onClick={releaseEscrowNativeCoinOwner}>Liberar TRX</button> */}
                    <button onClick={releaseEscrowNativeCoinOwner}>Liberar ETH</button>
                    </div>
                  </div>
                </div>
                </div>
                <div className={styles.containerWithdraw}>
                <form className={styles.approve_addStable} onSubmit={handleSubmit}>
                      <input type="text" placeholder="Direccion EstableCoin"
                      value={stableAddress} onChange={(e) => setStableAddress(e.target.value)} />
                      <button type="submit">Añadir StableCoin</button>
                    </form>
                  <button className={styles.withdrawButton} onClick={withdrawFees}>
                    Retirar Fees USDT
                  </button>
                  <button className={styles.withdrawButton} onClick={withdrawFeesNativeCoin}>
                    {/* Retirar Fees TRX */}
                    Retirar Fees ETH
                  </button>
                </div>
                  
                  <div className={styles.flex}>
                    <button
                      className={styles.button}
                      onClick={() => setSelectedTab("Anuncio USDT")}
                    >
                      Crear anuncio USDT
                    </button>
                    <button
                      className={styles.button}
                      // onClick={() => setSelectedTab("Anuncio TRX")}
                      onClick={() => setSelectedTab("Anuncio ETH")}
                    >
                      {/* Crear anuncio TRX */}
                      Crear anuncio ETH
                    </button>
                  </div>
                  {renderTabs()}
                  </div>
                )}
              </div>
              ) : (
                ""
              )}
            </div>  
        </div>
        <div>
          {/* <img className={styles.image} src="" /> */}
        </div>
      </div>
    </div>
  );
}