import React from 'react';

// function ModalResumen({ onCloseModal, cripto, amount, price, payment_mode }){
  function ModalResumen({ datosModal, crearAnuncio, onCloseModal }) {
  return (
    <div className="modal">
      <p>{ datosModal.usdtSeleccionado? "USDT" : "TRX"}</p>
      <p>Cantidad disponible: { datosModal.amount}</p>
      <p>Precio por unidad: { datosModal.price}</p>
      <p>Límite máximo de venta: { datosModal.maximo}</p>
      <p>Límite mínimo de venta: { datosModal.minimo}</p>
      <p>Modo de pago: { datosModal.payment_mode}</p>
      <p>Ubicación: { datosModal.location}</p>
      <p>Condiciones de venta: { datosModal.conditions}</p>
      <button onClick={onCloseModal}>Cancelar</button>
      {/* <button onClick={crearOferta}>Aceptar</button> */}
      {/* <button onClick={crearAnuncio(datosModal)}>Aceptar</button> */}
      <button onClick={() => crearAnuncio(datosModal)}>Aceptar</button>
    </div>
  );
}

export default ModalResumen;