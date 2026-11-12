'use strict';

const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// Un disparador de Firestore tiene que vivir en la región de la base.
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 5 });

const DEVICES = 'dispositivos';
const DEFAULT_TITLE = 'ReHomeIt';
const MULTICAST_LIMIT = 500;

const TITLES = {
  nuevo_mensaje: 'Nuevo mensaje',
  propuesta_intercambio: 'Propuesta de intercambio',
  propuesta_aceptada: 'Propuesta aceptada',
  propuesta_rechazada: 'Propuesta rechazada',
  intercambio_confirmado: 'Intercambio confirmado',
  recojo_asumido: 'Alguien recogerá tu donación',
  compromiso_liberado: 'Compromiso cancelado',
  entrega_a_voluntario: 'Entrega confirmada',
  entrega_destinatario: 'Entrega registrada',
  cierre_confirmado: 'Donación completada',
};

// Claves de `notificaciones` que la app puede usar para abrir la pantalla
// correcta. FCM solo admite texto en `data`.
const DATA_KEYS = [
  'type',
  'publicationId',
  'proposalId',
  'conversationId',
  'campaignId',
  'contributionId',
];

// Códigos con los que FCM indica que el token ya no existe. Otros errores
// (cuota, red, carga inválida) no dicen nada del token y no lo borran.
const STALE_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

function dataPayload(source) {
  const data = {};
  for (const key of DATA_KEYS) {
    if (typeof source[key] === 'string' && source[key] !== '') {
      data[key] = source[key];
    }
  }
  return data;
}

async function sendToDevices(deviceDocs, { title, body, data }) {
  for (let start = 0; start < deviceDocs.length; start += MULTICAST_LIMIT) {
    const batch = deviceDocs.slice(start, start + MULTICAST_LIMIT);
    const response = await getMessaging().sendEachForMulticast({
      tokens: batch.map((device) => device.id),
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });
    const stale = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code;
      if (STALE_TOKEN_CODES.includes(code)) {
        stale.push(batch[index].ref.delete());
      } else {
        logger.warn('No se pudo enviar el aviso', { code });
      }
    });
    await Promise.all(stale);
  }
}

exports.pushOnNotification = onDocumentCreated(
  'notificaciones/{notificationId}',
  async (event) => {
    const notification = event.data?.data();
    if (!notification?.recipientId || !notification.message) return;
    const devices = await getFirestore()
      .collection(DEVICES)
      .where('uid', '==', notification.recipientId)
      .get();
    if (devices.empty) return;
    await sendToDevices(devices.docs, {
      title: TITLES[notification.type] ?? DEFAULT_TITLE,
      body: notification.message,
      data: dataPayload(notification),
    });
  },
);

exports.pushOnPublication = onDocumentCreated(
  'publicaciones/{publicationId}',
  async (event) => {
    const publication = event.data?.data();
    if (!publication?.title || publication.status !== 'publicada') return;
    const devices = await getFirestore().collection(DEVICES).get();
    const others = devices.docs.filter(
      (device) => device.get('uid') !== publication.authorId,
    );
    if (others.length === 0) return;
    const verb = publication.mode === 'intercambio' ? 'intercambio' : 'donación';
    await sendToDevices(others, {
      title: 'Nuevo bien publicado',
      body: `${publication.title}, en ${verb}.`,
      data: {
        type: 'nueva_publicacion',
        publicationId: event.params.publicationId,
      },
    });
  },
);
