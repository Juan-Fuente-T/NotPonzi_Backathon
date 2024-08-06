import React from 'react';

// function ModalResumen({ onCloseModal, cripto, amount, price, payment_mode }){
  function FormularioAnuncio({handleSubmitModal}) {
  return (
    <div className="form">
            <form  onSubmit={handleSubmitModal}>

            {/* <div className={styles.container}> */}
            <div>
                <input type="radio" id="usdt" name="cripto" value="usdt" checked={datosModal.usdtSeleccionado} onChange={handleChange}></input>
                <label for="usdt">USDT</label><br></br>
                <input type="radio" id="trx" name="cripto" value="trx" checked={datosModal.trxSeleccionado} onChange={handleChange}></input>
                <label for="trx">TRX</label>
            </div>
            <div>
                <label for="amount">Cantidad</label><br></br>
       
                <input type="number" id="amount" name="amount" min="0.001"placeholder="Cantidad" value={datosModal.amount}
                  onChange={handleChange}></input>
                <label for="price">Precio por unidad</label><br></br>
                <input type="number" id="price" name="price" min="0.001" placeholder="Precio unidad en USD" value={datosModal.price}
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