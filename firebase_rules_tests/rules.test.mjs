import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { deleteObject, ref, uploadBytes } from 'firebase/storage';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, '..');
const projectId = 'demo-rehomeit';
const requestedOwnerId = 'requested-owner';
const offeredOwnerId = 'offered-owner';
const requestedPublicationId = 'requested-publication';
const offeredPublicationId = 'offered-publication';

let testEnv;

before(async () => {
  const [firestoreRules, storageRules] = await Promise.all([
    readFile(path.join(projectRoot, 'firestore.rules'), 'utf8'),
    readFile(path.join(projectRoot, 'storage.rules'), 'utf8'),
  ]);
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

function firestoreFor(userId) {
  return testEnv.authenticatedContext(userId).firestore();
}

function storageFor(userId) {
  return testEnv.authenticatedContext(userId).storage();
}

function initialPublication({
  authorId,
  mode,
  deliveryType = null,
  title = 'Bien reutilizable',
}) {
  return {
    authorId,
    title,
    category: 'Hogar',
    condition: 'Usado',
    description: 'En buen estado y listo para una segunda vida.',
    details: [{ name: 'Material', value: 'Madera' }],
    district: 'Cajamarca',
    mode,
    deliveryType,
    status: 'publicada',
    images: ['https://example.test/foto_0.jpg'],
    publishedAt: serverTimestamp(),
    statusDates: { publicada: serverTimestamp() },
  };
}

function initialProposal(overrides = {}) {
  return {
    requestedPublicationId,
    requestedPublicationTitle: 'Mesa',
    requestedOwnerId,
    offeredPublicationId,
    offeredPublicationTitle: 'Silla',
    offeredOwnerId,
    participantIds: [requestedOwnerId, offeredOwnerId],
    requestedImageUrl: 'https://example.test/mesa.jpg',
    offeredImageUrl: 'https://example.test/silla.jpg',
    status: 'pendiente',
    proposedAt: serverTimestamp(),
    respondedAt: null,
    requestedOwnerConfirmedAt: null,
    offeredOwnerConfirmedAt: null,
    ...overrides,
  };
}

function notification({ recipientId, type, proposalId }) {
  return {
    recipientId,
    type,
    message: 'Notificación legítima de intercambio.',
    proposalId,
    publicationId: requestedPublicationId,
    createdAt: serverTimestamp(),
    read: false,
  };
}

async function createExchangePublications() {
  const requestedDb = firestoreFor(requestedOwnerId);
  const offeredDb = firestoreFor(offeredOwnerId);
  await assertSucceeds(
    setDoc(
      doc(requestedDb, 'publicaciones', requestedPublicationId),
      initialPublication({
        authorId: requestedOwnerId,
        mode: 'intercambio',
        title: 'Mesa',
      }),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(offeredDb, 'publicaciones', offeredPublicationId),
      initialPublication({
        authorId: offeredOwnerId,
        mode: 'intercambio',
        title: 'Silla',
      }),
    ),
  );
}

async function createProposal(proposalId) {
  await assertSucceeds(
    setDoc(
      doc(
        firestoreFor(offeredOwnerId),
        'propuestasIntercambio',
        proposalId,
      ),
      initialProposal(),
    ),
  );
}

async function acceptProposal(proposalId, withNotification = false) {
  const db = firestoreFor(requestedOwnerId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'propuestasIntercambio', proposalId), {
    status: 'aceptada',
    respondedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'publicaciones', requestedPublicationId), {
    status: 'comprometida',
    exchangeProposalId: proposalId,
    counterpartPublicationId: offeredPublicationId,
    counterpartUserId: offeredOwnerId,
    committedAt: serverTimestamp(),
    'statusDates.comprometida': serverTimestamp(),
  });
  batch.update(doc(db, 'publicaciones', offeredPublicationId), {
    status: 'comprometida',
    exchangeProposalId: proposalId,
    counterpartPublicationId: requestedPublicationId,
    counterpartUserId: requestedOwnerId,
    committedAt: serverTimestamp(),
    'statusDates.comprometida': serverTimestamp(),
  });
  if (withNotification) {
    batch.set(doc(db, 'notificaciones', `accepted-${proposalId}`),
      notification({
        recipientId: offeredOwnerId,
        type: 'propuesta_aceptada',
        proposalId,
      }),
    );
  }
  await assertSucceeds(batch.commit());
}

async function confirmReceipt({
  proposalId,
  userId,
  first,
}) {
  const db = firestoreFor(userId);
  const isRequestedOwner = userId === requestedOwnerId;
  const otherUserId = isRequestedOwner ? offeredOwnerId : requestedOwnerId;
  const status = first ? 'entregada' : 'confirmada';
  const type = first
    ? 'confirmacion_intercambio_pendiente'
    : 'intercambio_confirmado';
  const batch = writeBatch(db);
  batch.update(doc(db, 'propuestasIntercambio', proposalId), {
    [isRequestedOwner
      ? 'requestedOwnerConfirmedAt'
      : 'offeredOwnerConfirmedAt']: serverTimestamp(),
  });
  for (const publicationId of [
    requestedPublicationId,
    offeredPublicationId,
  ]) {
    batch.update(doc(db, 'publicaciones', publicationId), {
      status,
      [`statusDates.${status}`]: serverTimestamp(),
    });
  }
  batch.set(doc(db, 'notificaciones', `${status}-${proposalId}`),
    notification({ recipientId: otherUserId, type, proposalId }),
  );
  await assertSucceeds(batch.commit());
}

function reportIdFor(reporterId, publicationId) {
  return `${reporterId}_${publicationId}`;
}

function initialReport({ reporterId, publicationId, overrides = {} }) {
  return {
    publicationId,
    reporterId,
    reason: 'contenido_inapropiado',
    comment: null,
    status: 'pendiente',
    createdAt: serverTimestamp(),
    resolvedAt: null,
    resolvedBy: null,
    ...overrides,
  };
}

test('permite crear un usuario y perfil legítimos con el esquema real', async () => {
  const db = firestoreFor('legitimate-user');
  const batch = writeBatch(db);
  batch.set(doc(db, 'usuarios', 'legitimate-user'), {
    nombreCompleto: 'Ana Torres',
    correo: 'ana@example.test',
    rol: 'usuario',
  });
  batch.set(doc(db, 'perfiles', 'legitimate-user'), {
    nombreCorto: 'Ana T.',
    distrito: '',
    fechaIngreso: serverTimestamp(),
    contadores: { donaciones: 0, intercambios: 0, voluntariados: 0 },
  });
  await assertSucceeds(batch.commit());
});

test('conserva la reparación segura si existe perfil pero falta usuario', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'perfiles', 'repaired-user'), {
      nombreCorto: 'Perfil anterior',
      distrito: 'Cajamarca',
      fechaIngreso: new Date('2025-01-01T00:00:00Z'),
      contadores: { donaciones: 4, intercambios: 2, voluntariados: 1 },
    });
  });
  const db = firestoreFor('repaired-user');
  const batch = writeBatch(db);
  batch.set(doc(db, 'usuarios', 'repaired-user'), {
    nombreCompleto: 'Cuenta Reparada',
    correo: 'repair@example.test',
    rol: 'usuario',
  });
  batch.set(doc(db, 'perfiles', 'repaired-user'), {
    nombreCorto: 'Cuenta R.',
    distrito: '',
    fechaIngreso: serverTimestamp(),
    contadores: { donaciones: 0, intercambios: 0, voluntariados: 0 },
  });
  await assertSucceeds(batch.commit());
});

test('deniega crear un usuario administrador y cambiar el rol', async () => {
  const db = firestoreFor('regular-user');
  const userRef = doc(db, 'usuarios', 'regular-user');
  await assertFails(setDoc(userRef, {
    nombreCompleto: 'Usuario malicioso',
    correo: 'user@example.test',
    rol: 'administrador',
  }));
  await assertSucceeds(setDoc(userRef, {
    nombreCompleto: 'Usuario regular',
    correo: 'user@example.test',
    rol: 'usuario',
  }));
  await assertFails(updateDoc(userRef, { rol: 'administrador' }));
});

test('deniega leer el documento privado de otro usuario', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'usuarios', 'private-user'), {
      nombreCompleto: 'Persona Privada',
      correo: 'privada@example.test',
      rol: 'usuario',
    });
  });
  await assertSucceeds(getDoc(doc(firestoreFor('private-user'), 'usuarios', 'private-user')));
  await assertFails(getDoc(doc(firestoreFor('other-user'), 'usuarios', 'private-user')));
});

test('deniega falsificar contadores o fecha de ingreso del perfil', async () => {
  const db = firestoreFor('profile-owner');
  const profileRef = doc(db, 'perfiles', 'profile-owner');
  await assertSucceeds(setDoc(profileRef, {
    nombreCorto: 'Perfil P.',
    distrito: '',
    fechaIngreso: serverTimestamp(),
    contadores: { donaciones: 0, intercambios: 0, voluntariados: 0 },
  }));
  await assertFails(updateDoc(profileRef, {
    'contadores.donaciones': 999,
  }));
  await assertFails(updateDoc(profileRef, {
    fechaIngreso: serverTimestamp(),
  }));
});

test('permite crear una donación y un intercambio válidos', async () => {
  const db = firestoreFor('publisher');
  await assertSucceeds(setDoc(
    doc(db, 'publicaciones', 'donation'),
    initialPublication({
      authorId: 'publisher',
      mode: 'donacion',
      deliveryType: 'voluntario',
    }),
  ));
  await assertSucceeds(setDoc(
    doc(db, 'publicaciones', 'exchange'),
    initialPublication({ authorId: 'publisher', mode: 'intercambio' }),
  ));
});

test('protege identidad, modalidad y campos internos de publicaciones', async () => {
  const db = firestoreFor('publisher');
  const publicationRef = doc(db, 'publicaciones', 'protected-publication');
  await assertSucceeds(setDoc(
    publicationRef,
    initialPublication({ authorId: 'publisher', mode: 'intercambio' }),
  ));
  await assertFails(updateDoc(publicationRef, { authorId: 'attacker' }));
  await assertFails(updateDoc(publicationRef, { mode: 'donacion' }));
  await assertFails(updateDoc(publicationRef, {
    exchangeProposalId: 'manually-injected',
  }));
  await assertFails(updateDoc(publicationRef, { price: 100 }));
  await assertFails(updateDoc(publicationRef, { amount: 100 }));
});

test('deniega price y amount también durante la creación', async () => {
  const db = firestoreFor('publisher');
  await assertFails(setDoc(
    doc(db, 'publicaciones', 'with-price'),
    {
      ...initialPublication({ authorId: 'publisher', mode: 'intercambio' }),
      price: 100,
    },
  ));
  await assertFails(setDoc(
    doc(db, 'publicaciones', 'with-amount'),
    {
      ...initialPublication({ authorId: 'publisher', mode: 'intercambio' }),
      amount: 100,
    },
  ));
  await assertFails(setDoc(
    doc(db, 'publicaciones', 'with-exchange-id'),
    {
      ...initialPublication({ authorId: 'publisher', mode: 'intercambio' }),
      exchangeProposalId: 'manually-injected',
    },
  ));
});

test('permite crear una propuesta pendiente con confirmaciones nulas', async () => {
  await createExchangePublications();
  await createProposal('valid-proposal');
});

test('deniega propuestas con respuesta o confirmaciones iniciales', async () => {
  await createExchangePublications();
  const db = firestoreFor(offeredOwnerId);
  await assertFails(setDoc(
    doc(db, 'propuestasIntercambio', 'responded-proposal'),
    initialProposal({ respondedAt: serverTimestamp() }),
  ));
  await assertFails(setDoc(
    doc(db, 'propuestasIntercambio', 'confirmed-proposal'),
    initialProposal({ requestedOwnerConfirmedAt: serverTimestamp() }),
  ));
});

test('permite rechazar una propuesta y emitir su notificación', async () => {
  await createExchangePublications();
  const proposalId = 'rejected-proposal';
  await createProposal(proposalId);
  const db = firestoreFor(requestedOwnerId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'propuestasIntercambio', proposalId), {
    status: 'rechazada',
    respondedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'notificaciones', 'rejected-notification'),
    notification({
      recipientId: offeredOwnerId,
      type: 'propuesta_rechazada',
      proposalId,
    }),
  );
  await assertSucceeds(batch.commit());
  const requested = await getDoc(
    doc(db, 'publicaciones', requestedPublicationId),
  );
  assert.equal(requested.data().status, 'publicada');
});

test('permite aceptar y comprometer atómicamente ambas publicaciones', async () => {
  await createExchangePublications();
  const proposalId = 'accepted-proposal';
  await createProposal(proposalId);
  await acceptProposal(proposalId, true);
  const db = firestoreFor(requestedOwnerId);
  const requested = await getDoc(
    doc(db, 'publicaciones', requestedPublicationId),
  );
  const offered = await getDoc(
    doc(db, 'publicaciones', offeredPublicationId),
  );
  assert.equal(requested.data().status, 'comprometida');
  assert.equal(offered.data().status, 'comprometida');
});

test('permite las dos confirmaciones y sus transiciones atómicas', async () => {
  await createExchangePublications();
  const proposalId = 'confirmed-proposal';
  await createProposal(proposalId);
  await acceptProposal(proposalId);
  await confirmReceipt({ proposalId, userId: requestedOwnerId, first: true });
  await confirmReceipt({ proposalId, userId: offeredOwnerId, first: false });
  const db = firestoreFor(requestedOwnerId);
  const proposal = await getDoc(
    doc(db, 'propuestasIntercambio', proposalId),
  );
  assert.ok(proposal.data().requestedOwnerConfirmedAt);
  assert.ok(proposal.data().offeredOwnerConfirmedAt);
  const requested = await getDoc(
    doc(db, 'publicaciones', requestedPublicationId),
  );
  assert.equal(requested.data().status, 'confirmada');
});

test('permite una notificación legítima al crear la propuesta', async () => {
  await createExchangePublications();
  const proposalId = 'notified-proposal';
  const db = firestoreFor(offeredOwnerId);
  const batch = writeBatch(db);
  batch.set(doc(db, 'propuestasIntercambio', proposalId), initialProposal());
  batch.set(doc(db, 'notificaciones', 'proposal-notification'),
    notification({
      recipientId: requestedOwnerId,
      type: 'propuesta_intercambio',
      proposalId,
    }),
  );
  await assertSucceeds(batch.commit());
});

test('deniega notificaciones a uno mismo o fuera de una transición', async () => {
  await createExchangePublications();
  const proposalId = 'spam-proposal';
  await createProposal(proposalId);
  const db = firestoreFor(offeredOwnerId);
  await assertFails(setDoc(
    doc(db, 'notificaciones', 'self-notification'),
    notification({
      recipientId: offeredOwnerId,
      type: 'propuesta_intercambio',
      proposalId,
    }),
  ));
  await assertFails(setDoc(
    doc(db, 'notificaciones', 'replayed-notification'),
    notification({
      recipientId: requestedOwnerId,
      type: 'propuesta_intercambio',
      proposalId,
    }),
  ));
});

test('permite reportar una publicación ajena y deja el reporte pendiente', async () => {
  const authorId = 'publication-author';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', 'reported-publication'),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  const reportRef = doc(
    firestoreFor(reporterId),
    'reportes',
    reportIdFor(reporterId, 'reported-publication'),
  );
  await assertSucceeds(setDoc(
    reportRef,
    initialReport({ reporterId, publicationId: 'reported-publication' }),
  ));
  const report = await getDoc(reportRef);
  assert.equal(report.data().status, 'pendiente');
  assert.equal(report.data().resolvedAt, null);
  assert.equal(report.data().resolvedBy, null);
});

test('deniega el segundo reporte de la misma publicación', async () => {
  const authorId = 'publication-author';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', 'reported-twice'),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  const db = firestoreFor(reporterId);
  const reportRef = doc(db, 'reportes', reportIdFor(reporterId, 'reported-twice'));
  await assertSucceeds(setDoc(
    reportRef,
    initialReport({ reporterId, publicationId: 'reported-twice' }),
  ));
  // El id es determinista, así que el segundo `set` llega como `update` sobre
  // un documento existente y la regla lo deniega (HU19-04).
  await assertFails(setDoc(
    reportRef,
    initialReport({
      reporterId,
      publicationId: 'reported-twice',
      overrides: { reason: 'solicitud_de_dinero' },
    }),
  ));
  // Tampoco vale la pena cambiar de motivo ni de comentario después.
  await assertFails(updateDoc(reportRef, { comment: 'Otro motivo' }));
});

test('deniega reportar la propia publicación o una que no existe', async () => {
  const authorId = 'publication-author';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', 'own-publication'),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  await assertFails(setDoc(
    doc(firestoreFor(authorId), 'reportes', reportIdFor(authorId, 'own-publication')),
    initialReport({ reporterId: authorId, publicationId: 'own-publication' }),
  ));
  await assertFails(setDoc(
    doc(firestoreFor('reporter'), 'reportes', reportIdFor('reporter', 'fantasma')),
    initialReport({ reporterId: 'reporter', publicationId: 'fantasma' }),
  ));
});

test('el reporte solo puede escribirse con el esquema, el motivo y el estado reales', async () => {
  const authorId = 'publication-author';
  const publicationId = 'strict-publication';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', publicationId),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  const db = firestoreFor(reporterId);
  // Todos los intentos denegados apuntan al mismo documento a propósito: al
  // fallar no queda nada escrito, así que el caso válido del final puede
  // escribirse en el mismo id. Cada uno aísla un campo del esquema.
  const reportRef = doc(
    db,
    'reportes',
    reportIdFor(reporterId, publicationId),
  );
  const rejects = (overrides) => assertFails(setDoc(
    reportRef,
    initialReport({ reporterId, publicationId, overrides }),
  ));

  // Un id que no corresponde al par persona y publicación dejaría pasar el
  // segundo reporte de la misma publicación.
  await assertFails(setDoc(
    doc(db, 'reportes', 'id-arbitrario'),
    initialReport({ reporterId, publicationId }),
  ));
  // Solo los cinco motivos previstos.
  await rejects({ reason: 'inventado' });
  // Quien reporta no decide el resultado: el estado y la resolución los
  // escribe el equipo administrador.
  await rejects({ status: 'desestimado', resolvedAt: serverTimestamp(), resolvedBy: 'admin' });
  await rejects({ status: 'retirada' });
  // La fecha la pone el servidor y el autor del reporte es quien está
  // autenticado.
  await rejects({ createdAt: null });
  await rejects({ reporterId: 'otro' });
  // El comentario es opcional, pero acotado.
  await rejects({ comment: 'a'.repeat(501) });
  // Ni campos de más ni campos de menos: los tres de resolución tienen que
  // estar presentes aunque valgan `null`.
  await rejects({ retirado: true });
  await assertFails(setDoc(reportRef, {
    publicationId,
    reporterId,
    reason: 'otro',
    status: 'pendiente',
    createdAt: serverTimestamp(),
    resolvedAt: null,
  }));

  // Con 500 caracteres exactos sí se acepta: el tope es ese.
  await assertSucceeds(setDoc(
    reportRef,
    initialReport({
      reporterId,
      publicationId,
      overrides: { reason: 'otro', comment: 'a'.repeat(500) },
    }),
  ));
});

test('el reporte no se resuelve ni se borra desde la aplicación', async () => {
  const authorId = 'publication-author';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', 'unresolved-publication'),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  const db = firestoreFor(reporterId);
  const reportRef = doc(
    db,
    'reportes',
    reportIdFor(reporterId, 'unresolved-publication'),
  );
  await assertSucceeds(setDoc(
    reportRef,
    initialReport({ reporterId, publicationId: 'unresolved-publication' }),
  ));
  // Resolver es tarea de la consola de moderación (HU19-08 a HU19-12): ni la
  // aplicación ni el usuario que reportó tocan el resultado.
  await assertFails(updateDoc(reportRef, {
    status: 'desestimado',
    resolvedAt: serverTimestamp(),
    resolvedBy: reporterId,
  }));
  await assertFails(deleteDoc(reportRef));
  const report = await getDoc(reportRef);
  assert.equal(report.data().status, 'pendiente');
});

test('solo quien reportó lee su reporte y no el de los demás', async () => {
  const authorId = 'publication-author';
  await assertSucceeds(setDoc(
    doc(firestoreFor(authorId), 'publicaciones', 'private-report-publication'),
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  await assertSucceeds(setDoc(
    doc(firestoreFor(reporterId), 'reportes', reportIdFor(reporterId, 'private-report-publication')),
    initialReport({ reporterId, publicationId: 'private-report-publication' }),
  ));
  await assertSucceeds(getDoc(doc(
    firestoreFor(reporterId),
    'reportes',
    reportIdFor(reporterId, 'private-report-publication'),
  )));
  await assertFails(getDoc(doc(
    firestoreFor(authorId),
    'reportes',
    reportIdFor(reporterId, 'private-report-publication'),
  )));
});

test('el reporte no toca la publicación reportada', async () => {
  // La publicación sigue visible mientras su reporte no se resuelva
  // (HU19-07): reportarla no la anula ni le cambia el estado.
  const authorId = 'publication-author';
  const publicationRef = doc(
    firestoreFor(authorId),
    'publicaciones',
    'still-visible-publication',
  );
  await assertSucceeds(setDoc(
    publicationRef,
    initialPublication({ authorId, mode: 'donacion', deliveryType: 'donante' }),
  ));
  const reporterId = 'reporter';
  await assertSucceeds(setDoc(
    doc(firestoreFor(reporterId), 'reportes', reportIdFor(reporterId, 'still-visible-publication')),
    initialReport({ reporterId, publicationId: 'still-visible-publication' }),
  ));
  const publication = await getDoc(
    doc(firestoreFor(reporterId), 'publicaciones', 'still-visible-publication'),
  );
  assert.equal(publication.data().status, 'publicada');
});

test('Storage permite nombres válidos, limpieza y deniega nombre inválido y overwrite', async () => {
  const storage = storageFor('image-owner');
  const publicationId = 'AbCdEfGhIjKlMnOpQrSt';
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  const validRef = ref(
    storage,
    `publicaciones/image-owner/${publicationId}/foto_0.jpg`,
  );
  await assertSucceeds(uploadBytes(validRef, bytes, {
    contentType: 'image/jpeg',
  }));
  await assertFails(uploadBytes(validRef, bytes, {
    contentType: 'image/jpeg',
  }));
  await assertFails(uploadBytes(
    ref(storage, `publicaciones/image-owner/${publicationId}/foto_4.jpg`),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  const cleanupRef = ref(
    storage,
    `publicaciones/image-owner/${publicationId}/foto_1.jpg`,
  );
  await assertSucceeds(uploadBytes(cleanupRef, bytes, {
    contentType: 'image/jpeg',
  }));
  await assertSucceeds(deleteObject(cleanupRef));
});
