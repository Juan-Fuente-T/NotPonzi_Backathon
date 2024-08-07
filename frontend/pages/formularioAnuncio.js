import React from 'react';
import styles from '../styles/FormularioAnuncio.module.css';


// function ModalResumen({ onCloseModal, cripto, amount, price, payment_mode }){
  function FormularioAnuncio({handleSubmitModal, datosModal, handleChange}) {
  return (
    <div className="form">
            <form  onSubmit={handleSubmitModal}>

            {/* <div className={styles.container}> */}
            <div>
                      <label htmlFor="usdt">
    <input type="radio" id="usdt" name="cripto" value="usdt" checked={datosModal.cripto === "usdt"} onChange={handleChange} />
    USDT
  </label>
  <label htmlFor="eth">
    <input type="radio" id="eth" name="cripto" value="eth" checked={datosModal.cripto === "eth"} onChange={handleChange} />
    ETH
  </label>
            </div>
            <div>
                <label for="amount">Cantidad</label><br></br>
                <input type="number" id="amount" name="amount" min="0.001"placeholder="Cantidad" value={datosModal.amount}
                  onChange={handleChange}></input><br></br>
                <label for="price">Precio por unidad</label><br></br>
                <input type="number" id="price" name="price" min="0.001" placeholder="Precio unidad en USD" value={datosModal.price}
                  onChange={handleChange}></input><br></br>
                <label for="payment_mode">Modo de pago</label><br></br>
                {/* <div className={styles.container}>
                        <input type="radio" id="usdt" name="crypto" value="usdt" checked={datosModal.usdt} onChange={handleChange}></input>
                  <label for="usdt">USDT</label><br></br>
                           <input type="radio" id="eth" name="crypto" value="eth" checked={datosModal.eth} onChange={handleChange}></input> 
                  <input type="radio" id="eth" name="crypto" value="eth" checked={datosModal.eth} onChange={handleChange}></input>
                           <label for="eth">ETH</label> 
                  <label for="eth">ETH</label>
                </div>
                <div> */}
                {/* <div>
                    <select name="payment_mode" value={datosModal.payment_mode}
                    onChange={handleChange}>
                        <option value="">Seleccione un modo de pago</option>
                        <option value="efectivo">Efectivo</option>
                        <option value="tarjeta">Tarjeta</option>
                        <option value="transferencia_bancaria">Transferencia</option>
                    </select>
                </div> */}
                {/* <label for="maximo">Límite máximo de venta</label><br></br>
                <input type="number" id="maximo" name="maximo" min="0" step="0.001" placeholder="Límite máximo de venta" value={datosModal.maximo}
                  onChange={handleChange}></input>

                <label for="minimo">Límite mínimo de venta</label><br></br>
                <input type="number" id="minimo" name="minimo" min="0" step="0.001" placeholder="Límite mínimo de venta" value={datosModal.minimo}
                  onChange={handleChange}></input> */}

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
    </div>
  );
}

export default FormularioAnuncio;