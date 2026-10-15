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
  collection,
  deleteDoc,
  doc,
  deleteField,
  getDoc,
  getDocs,
  increment,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
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
      ...(first ? { firstConfirmedBy: userId } : {}),
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
    nombres: 'Ana',
    apellidos: 'Torres',
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
    nombres: 'Cuenta',
    apellidos: 'Reparada',
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
    nombres: 'Usuario',
    apellidos: 'malicioso',
    correo: 'user@example.test',
    rol: 'administrador',
  }));
  await assertSucceeds(setDoc(userRef, {
    nombreCompleto: 'Usuario regular',
    nombres: 'Usuario',
    apellidos: 'regular',
    correo: 'user@example.test',
    rol: 'usuario',
  }));
  await assertFails(updateDoc(userRef, { rol: 'administrador' }));
});

test('permite al dueño editar su nombre y bloquea correo, rol y a terceros', async () => {
  const db = firestoreFor('editing-user');
  const userRef = doc(db, 'usuarios', 'editing-user');
  await assertSucceeds(setDoc(userRef, {
    nombreCompleto: 'Ana María Torres',
    nombres: 'Ana María',
    apellidos: 'Torres',
    correo: 'ana@example.test',
    rol: 'usuario',
  }));
  await assertSucceeds(updateDoc(userRef, {
    nombres: 'Ana',
    apellidos: 'Quispe',
    nombreCompleto: 'Ana Quispe',
  }));
  // El nombre completo debe derivar de los dos campos.
  await assertFails(updateDoc(userRef, {
    nombres: 'Ana',
    apellidos: 'Quispe',
    nombreCompleto: 'Otra Persona',
  }));
  await assertFails(updateDoc(userRef, { correo: 'otro@example.test' }));
  await assertFails(updateDoc(userRef, { rol: 'administrador' }));
  await assertFails(updateDoc(
    doc(firestoreFor('intruder'), 'usuarios', 'editing-user'),
    { nombres: 'Intruso', apellidos: 'X', nombreCompleto: 'Intruso X' },
  ));
});

test('permite al dueño editar nombre corto, distrito y foto del perfil', async () => {
  const db = firestoreFor('editing-profile');
  const profileRef = doc(db, 'perfiles', 'editing-profile');
  await assertSucceeds(setDoc(profileRef, {
    nombreCorto: 'Ana T.',
    distrito: '',
    fechaIngreso: serverTimestamp(),
    contadores: { donaciones: 0, intercambios: 0, voluntariados: 0 },
  }));
  await assertSucceeds(updateDoc(profileRef, {
    nombreCorto: 'Ana Q.',
    distrito: 'Los Baños del Inca',
    fotoUrl: 'https://example.test/avatar.jpg',
  }));
  await assertSucceeds(updateDoc(profileRef, { fotoUrl: null, distrito: '' }));
  await assertFails(updateDoc(profileRef, { distrito: 'Lima' }));
  await assertFails(updateDoc(profileRef, { nombreCorto: '' }));
  await assertFails(updateDoc(profileRef, {
    distrito: 'Cajamarca',
    'contadores.donaciones': 5,
  }));
  await assertFails(updateDoc(profileRef, {
    distrito: 'Cajamarca',
    fechaIngreso: serverTimestamp(),
  }));
  await assertFails(updateDoc(
    doc(firestoreFor('intruder'), 'perfiles', 'editing-profile'),
    { distrito: 'Cajamarca' },
  ));
});

test('Storage permite la foto de perfil solo a su dueño y con el nombre fijo', async () => {
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  const ownRef = ref(storageFor('avatar-owner'), 'perfiles/avatar-owner/avatar.jpg');
  await assertSucceeds(uploadBytes(ownRef, bytes, { contentType: 'image/jpeg' }));
  // Cambiar la foto sobrescribe el mismo archivo.
  await assertSucceeds(uploadBytes(ownRef, bytes, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ownRef, bytes, { contentType: 'image/png' }));
  await assertFails(uploadBytes(
    ref(storageFor('avatar-owner'), 'perfiles/avatar-owner/otra.jpg'),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(storageFor('intruder'), 'perfiles/avatar-owner/avatar.jpg'),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  await assertSucceeds(deleteObject(ownRef));
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

test('HU07-15: la primera confirmación registra quién la hizo', async () => {
  await createExchangePublications();
  const proposalId = 'signed-proposal';
  await createProposal(proposalId);
  await acceptProposal(proposalId);
  const db = firestoreFor(requestedOwnerId);
  // Firmar como la otra parte no vale.
  const forged = writeBatch(db);
  forged.update(doc(db, 'propuestasIntercambio', proposalId), {
    requestedOwnerConfirmedAt: serverTimestamp(),
  });
  for (const publicationId of [requestedPublicationId, offeredPublicationId]) {
    forged.update(doc(db, 'publicaciones', publicationId), {
      status: 'entregada',
      'statusDates.entregada': serverTimestamp(),
      firstConfirmedBy: offeredOwnerId,
    });
  }
  await assertFails(forged.commit());
  await confirmReceipt({ proposalId, userId: requestedOwnerId, first: true });
  const requested = await getDoc(doc(db, 'publicaciones', requestedPublicationId));
  assert.equal(requested.data().firstConfirmedBy, requestedOwnerId);
});

test('HU07-19: la segunda confirmación no procede pasadas las 120 h', async () => {
  await createExchangePublications();
  const proposalId = 'expired-proposal';
  await createProposal(proposalId);
  await acceptProposal(proposalId);
  await confirmReceipt({ proposalId, userId: requestedOwnerId, first: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    for (const publicationId of [requestedPublicationId, offeredPublicationId]) {
      await updateDoc(doc(context.firestore(), 'publicaciones', publicationId), {
        'statusDates.entregada': new Date('2026-01-01T00:00:00Z'),
      });
    }
  });
  const db = firestoreFor(offeredOwnerId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'propuestasIntercambio', proposalId), {
    offeredOwnerConfirmedAt: serverTimestamp(),
  });
  for (const publicationId of [requestedPublicationId, offeredPublicationId]) {
    batch.update(doc(db, 'publicaciones', publicationId), {
      status: 'confirmada',
      'statusDates.confirmada': serverTimestamp(),
    });
  }
  await assertFails(batch.commit());
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

const donorId = 'donor-user';
const volunteerId = 'volunteer-user';
const otherVolunteerId = 'other-volunteer';
const donationPublicationId = 'AbCdEfGhIjKlMnOpQrSt';

function conversationData(participants = [donorId, volunteerId]) {
  return {
    publicationId: donationPublicationId,
    publicationTitle: 'Mesa solidaria',
    publicationImageUrl: 'https://example.test/foto_0.jpg',
    publicationMode: 'donacion',
    participantIds: [...participants].sort(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    lastMessage: '',
    lastSenderId: null,
    lastMessageId: null,
  };
}

async function createVolunteerDonation(deliveryType = 'voluntario') {
  const db = firestoreFor(donorId);
  await assertSucceeds(setDoc(
    doc(db, 'publicaciones', donationPublicationId),
    initialPublication({
      authorId: donorId,
      mode: 'donacion',
      deliveryType,
      title: 'Mesa solidaria',
    }),
  ));
}

async function seedCommitted(volunteer = volunteerId) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'publicaciones', donationPublicationId), {
      ...initialPublication({
        authorId: donorId,
        mode: 'donacion',
        deliveryType: 'voluntario',
        title: 'Mesa solidaria',
      }),
      publishedAt: new Date('2026-01-01T00:00:00Z'),
      status: 'comprometida',
      volunteerId: volunteer,
      committedAt: new Date('2026-01-02T00:00:00Z'),
      statusDates: {
        publicada: new Date('2026-01-01T00:00:00Z'),
        comprometida: new Date('2026-01-02T00:00:00Z'),
      },
    });
  });
}

async function seedPickedUp() {
  await seedCommitted();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'publicaciones', donationPublicationId),
      {
        status: 'recogida',
        pickedUpAt: new Date('2026-01-03T00:00:00Z'),
        'statusDates.recogida': new Date('2026-01-03T00:00:00Z'),
      },
    );
  });
}

test('HU09: solo participantes leen la conversación', async () => {
  await seedCommitted();
  const conversationId = 'private-conversation';
  await assertSucceeds(setDoc(
    doc(firestoreFor(volunteerId), 'conversaciones', conversationId),
    conversationData(),
  ));
  await assertSucceeds(getDoc(
    doc(firestoreFor(donorId), 'conversaciones', conversationId),
  ));
  await assertFails(getDoc(
    doc(firestoreFor('third-user'), 'conversaciones', conversationId),
  ));
});

test('HU09-1: sin compromiso no se crea la conversación', async () => {
  // Donación publicada: el voluntario todavía no asumió el recojo.
  await createVolunteerDonation();
  await assertFails(setDoc(
    doc(firestoreFor(volunteerId), 'conversaciones', 'early-conversation'),
    conversationData(),
  ));
  // Intercambio: antes de aceptar no hay con quién coordinar; después sí.
  await createExchangePublications();
  const proposalId = 'conversation-proposal';
  await createProposal(proposalId);
  const exchangeConversation = {
    ...conversationData([requestedOwnerId, offeredOwnerId]),
    publicationId: requestedPublicationId,
    publicationTitle: 'Mesa',
    publicationImageUrl: 'https://example.test/foto_0.jpg',
    publicationMode: 'intercambio',
  };
  await assertFails(setDoc(
    doc(firestoreFor(offeredOwnerId), 'conversaciones', 'exchange-conversation'),
    exchangeConversation,
  ));
  await acceptProposal(proposalId);
  await assertSucceeds(setDoc(
    doc(firestoreFor(offeredOwnerId), 'conversaciones', 'exchange-conversation'),
    exchangeConversation,
  ));
  // Un tercero no entra aunque incluya al autor entre los participantes.
  await assertFails(setDoc(
    doc(firestoreFor('third-user'), 'conversaciones', 'intruder-conversation'),
    {
      ...exchangeConversation,
      participantIds: [requestedOwnerId, 'third-user'].sort(),
    },
  ));
});

test('HU09: leer una conversación que no existe no se deniega', async () => {
  // La app consulta la conversación dentro de una transacción antes de
  // crearla. Con `resource` nulo la regla de participantes fallaba y la
  // creación nunca llegaba a ejecutarse.
  await createVolunteerDonation();
  const snapshot = await assertSucceeds(getDoc(
    doc(firestoreFor(volunteerId), 'conversaciones', 'not-created-yet'),
  ));
  assert.equal(snapshot.exists(), false);
  // Listar sigue limitado a participantes: sin filtro no hay garantía.
  await assertFails(getDocs(
    collection(firestoreFor('third-user'), 'conversaciones'),
  ));
});

test('HU09: participante envía y no puede falsificar senderId', async () => {
  await seedCommitted();
  const conversationId = 'message-conversation';
  await assertSucceeds(setDoc(
    doc(firestoreFor(volunteerId), 'conversaciones', conversationId),
    conversationData(),
  ));
  const db = firestoreFor(volunteerId);
  const messageId = 'message-1';
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'conversaciones', conversationId, 'mensajes', messageId),
    {
      conversationId,
      publicationId: donationPublicationId,
      senderId: volunteerId,
      body: 'Coordinaré el recojo mañana.',
      queuedAt: new Date('2026-01-01T00:00:00Z'),
      sentAt: serverTimestamp(),
    },
  );
  batch.update(doc(db, 'conversaciones', conversationId), {
    lastMessage: 'Coordinaré el recojo mañana.',
    lastSenderId: volunteerId,
    lastMessageId: messageId,
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'notificaciones', `mensaje_${messageId}`), {
    recipientId: donorId,
    type: 'nuevo_mensaje',
    message: 'Tienes un nuevo mensaje sobre Mesa solidaria.',
    publicationId: donationPublicationId,
    conversationId,
    messageId,
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(
    doc(
      firestoreFor(donorId),
      'conversaciones',
      conversationId,
      'mensajes',
      messageId,
    ),
  ));
  await assertFails(getDoc(
    doc(
      firestoreFor('third-user'),
      'conversaciones',
      conversationId,
      'mensajes',
      messageId,
    ),
  ));

  const forgedId = 'forged-message';
  const forged = writeBatch(db);
  forged.set(
    doc(db, 'conversaciones', conversationId, 'mensajes', forgedId),
    {
      conversationId,
      publicationId: donationPublicationId,
      senderId: donorId,
      body: 'Mensaje falsificado',
      queuedAt: new Date('2026-01-01T00:00:00Z'),
      sentAt: serverTimestamp(),
    },
  );
  forged.update(doc(db, 'conversaciones', conversationId), {
    lastMessage: 'Mensaje falsificado',
    lastSenderId: donorId,
    lastMessageId: forgedId,
    updatedAt: serverTimestamp(),
  });
  await assertFails(forged.commit());
});

test('HU10: propietario no puede asumir su propio recojo', async () => {
  await createVolunteerDonation();
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    {
      status: 'comprometida',
      volunteerId: donorId,
      committedAt: serverTimestamp(),
      'statusDates.comprometida': serverTimestamp(),
    },
  ));
});

test('HU10: compromiso, conversación y notificación se crean atómicamente', async () => {
  await createVolunteerDonation();
  const db = firestoreFor(volunteerId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), {
    status: 'comprometida',
    volunteerId,
    committedAt: serverTimestamp(),
    'statusDates.comprometida': serverTimestamp(),
  });
  batch.set(
    doc(db, 'conversaciones', 'pickup-conversation'),
    conversationData(),
  );
  batch.set(doc(db, 'notificaciones', 'pickup-assumed'), {
    recipientId: donorId,
    type: 'recojo_asumido',
    message: 'Un usuario asumió el recojo de Mesa solidaria.',
    publicationId: donationPublicationId,
    actorId: volunteerId,
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
});

test('HU10: solo uno de dos voluntarios puede asumir el mismo bien', async () => {
  await createVolunteerDonation();
  const attempts = await Promise.allSettled([
    updateDoc(
      doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
      {
        status: 'comprometida',
        volunteerId,
        committedAt: serverTimestamp(),
        'statusDates.comprometida': serverTimestamp(),
      },
    ),
    updateDoc(
      doc(firestoreFor(otherVolunteerId), 'publicaciones', donationPublicationId),
      {
        status: 'comprometida',
        volunteerId: otherVolunteerId,
        committedAt: serverTimestamp(),
        'statusDates.comprometida': serverTimestamp(),
      },
    ),
  ]);
  assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(attempts.filter((result) => result.status === 'rejected').length, 1);
});

test('HU10: voluntario desiste y donante cancela solo en comprometida', async () => {
  for (const actor of [volunteerId, donorId]) {
    await testEnv.clearFirestore();
    await seedCommitted();
    await assertSucceeds(updateDoc(
      doc(firestoreFor(actor), 'publicaciones', donationPublicationId),
      {
        status: 'publicada',
        volunteerId: deleteField(),
        committedAt: deleteField(),
      },
    ));
  }
  await testEnv.clearFirestore();
  await seedPickedUp();
  await assertFails(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    { status: 'publicada' },
  ));
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    { status: 'publicada' },
  ));
});

test('HU10: liberar el compromiso avisa a la otra parte en el mismo lote', async () => {
  await seedCommitted();
  const db = firestoreFor(volunteerId);
  const release = {
    status: 'publicada',
    volunteerId: deleteField(),
    committedAt: deleteField(),
  };
  const notice = (recipientId) => ({
    recipientId,
    type: 'compromiso_liberado',
    message: 'El voluntario desistió del recojo.',
    publicationId: donationPublicationId,
    actorId: volunteerId,
    createdAt: serverTimestamp(),
    read: false,
  });
  const forged = writeBatch(db);
  forged.update(doc(db, 'publicaciones', donationPublicationId), release);
  forged.set(doc(db, 'notificaciones', 'forged-release'), notice('third-user'));
  await assertFails(forged.commit());

  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), release);
  batch.set(doc(db, 'notificaciones', 'release-notice'), notice(donorId));
  await assertSucceeds(batch.commit());
});

test('HU14-13: anuladas y retiradas solo las leen el autor, los participantes y la moderación', async () => {
  await createVolunteerDonation();
  await assertSucceeds(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    { status: 'anulada' },
  ));
  await assertFails(getDoc(
    doc(firestoreFor('third-user'), 'publicaciones', donationPublicationId),
  ));
  await assertSucceeds(getDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
  ));
  await seedAdmin();
  await assertSucceeds(getDoc(
    doc(firestoreFor(adminId), 'publicaciones', donationPublicationId),
  ));
  // Retirada con voluntario: el voluntario conserva el acceso a su historial.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'publicaciones', 'removed-with-volunteer'), {
      ...initialPublication({ authorId: donorId, mode: 'donacion', deliveryType: 'voluntario' }),
      status: 'retirada',
      volunteerId,
    });
  });
  await assertSucceeds(getDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', 'removed-with-volunteer'),
  ));
  await assertFails(getDoc(
    doc(firestoreFor('third-user'), 'publicaciones', 'removed-with-volunteer'),
  ));
  // El perfil público de un tercero lista solo con el filtro de estado; el
  // propio lista todo.
  const publicStatuses = ['publicada', 'comprometida', 'recogida', 'entregada', 'confirmada'];
  await assertSucceeds(getDocs(query(
    collection(firestoreFor('third-user'), 'publicaciones'),
    where('authorId', '==', donorId),
    where('status', 'in', publicStatuses),
  )));
  await assertFails(getDocs(query(
    collection(firestoreFor('third-user'), 'publicaciones'),
    where('authorId', '==', donorId),
  )));
  await assertSucceeds(getDocs(query(
    collection(firestoreFor(donorId), 'publicaciones'),
    where('authorId', '==', donorId),
  )));
  await assertSucceeds(getDocs(query(
    collection(firestoreFor(volunteerId), 'publicaciones'),
    where('volunteerId', '==', volunteerId),
  )));
});

test('HU11: solo donante confirma comprometida a recogida', async () => {
  await seedCommitted();
  const transition = {
    status: 'recogida',
    pickedUpAt: serverTimestamp(),
    'statusDates.recogida': serverTimestamp(),
  };
  await assertFails(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    transition,
  ));
  await assertSucceeds(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    transition,
  ));
});

test('HU11: transición legítima notifica al voluntario en el mismo lote', async () => {
  await seedCommitted();
  const db = firestoreFor(donorId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), {
    status: 'recogida',
    pickedUpAt: serverTimestamp(),
    'statusDates.recogida': serverTimestamp(),
  });
  batch.set(doc(db, 'notificaciones', 'picked-up-notification'), {
    recipientId: volunteerId,
    type: 'entrega_a_voluntario',
    message: 'El donante confirmó la entrega de Mesa solidaria.',
    publicationId: donationPublicationId,
    actorId: donorId,
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
});

test('HU11: nunca permite recogida a publicada', async () => {
  await seedPickedUp();
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    { status: 'publicada' },
  ));
  await assertFails(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    { status: 'publicada' },
  ));
});

function deliveryEvidence(actorId = volunteerId, overrides = {}) {
  return {
    recipientInitials: 'M.R.',
    district: 'Cajamarca',
    storagePath:
      `entregas/${donationPublicationId}/${actorId}/evidencia.jpg`,
    recordedAt: serverTimestamp(),
    ...overrides,
  };
}

test('HU12: solo voluntario asignado registra recogida a entregada', async () => {
  await seedPickedUp();
  const update = {
    status: 'entregada',
    deliveredAt: serverTimestamp(),
    'statusDates.entregada': serverTimestamp(),
    deliveryEvidence: deliveryEvidence(),
  };
  await assertFails(updateDoc(
    doc(firestoreFor('third-user'), 'publicaciones', donationPublicationId),
    update,
  ));
  await assertSucceeds(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    update,
  ));
});

test('HU12: entrega legítima notifica al donante en el mismo lote', async () => {
  await seedPickedUp();
  const db = firestoreFor(volunteerId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), {
    status: 'entregada',
    deliveredAt: serverTimestamp(),
    'statusDates.entregada': serverTimestamp(),
    deliveryEvidence: deliveryEvidence(),
  });
  batch.set(doc(db, 'notificaciones', 'delivered-notification'), {
    recipientId: donorId,
    type: 'entrega_destinatario',
    message: 'La entrega al destinatario fue registrada.',
    publicationId: donationPublicationId,
    actorId: volunteerId,
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
});

test('HU12: rechaza datos sensibles o campos arbitrarios del destinatario', async () => {
  await seedPickedUp();
  const db = firestoreFor(volunteerId);
  const publicationRef = doc(db, 'publicaciones', donationPublicationId);
  await assertFails(updateDoc(publicationRef, {
    status: 'entregada',
    deliveredAt: serverTimestamp(),
    'statusDates.entregada': serverTimestamp(),
    deliveryEvidence: deliveryEvidence(volunteerId, { dni: '12345678' }),
  }));
  await assertFails(updateDoc(publicationRef, {
    status: 'entregada',
    deliveredAt: serverTimestamp(),
    'statusDates.entregada': serverTimestamp(),
    deliveryEvidence: deliveryEvidence(volunteerId, {
      district: 'Distrito inventado',
    }),
  }));
});

async function seedDelivered(deliveredAt = new Date()) {
  await seedPickedUp();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'publicaciones', donationPublicationId),
      {
        status: 'entregada',
        deliveredAt,
        'statusDates.entregada': deliveredAt,
        deliveryEvidence: { ...deliveryEvidence(), recordedAt: deliveredAt },
      },
    );
  });
}

test('HU13: solo el donante confirma el cierre de entregada a confirmada', async () => {
  await seedDelivered();
  const update = {
    status: 'confirmada',
    'statusDates.confirmada': serverTimestamp(),
  };
  await assertFails(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    update,
  ));
  await assertFails(updateDoc(
    doc(firestoreFor('third-user'), 'publicaciones', donationPublicationId),
    update,
  ));
  await assertSucceeds(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    update,
  ));
});

test('HU13: el cierre no procede pasado el segundo plazo', async () => {
  await seedDelivered(new Date('2026-01-04T00:00:00Z'));
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    {
      status: 'confirmada',
      'statusDates.confirmada': serverTimestamp(),
    },
  ));
});

test('HU13: el cierre notifica al voluntario en el mismo lote', async () => {
  await seedDelivered();
  const db = firestoreFor(donorId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), {
    status: 'confirmada',
    'statusDates.confirmada': serverTimestamp(),
  });
  batch.set(doc(db, 'notificaciones', 'closed-notification'), {
    recipientId: volunteerId,
    type: 'cierre_confirmado',
    message: 'El donante confirmó el cierre de la entrega.',
    publicationId: donationPublicationId,
    actorId: donorId,
    createdAt: serverTimestamp(),
    read: false,
  });
  await assertSucceeds(batch.commit());
});

test('HU12: entrega directa pasa de publicada a confirmada solo por donante', async () => {
  await createVolunteerDonation('donante');
  const update = {
    status: 'confirmada',
    deliveredAt: serverTimestamp(),
    'statusDates.confirmada': serverTimestamp(),
    deliveryEvidence: deliveryEvidence(donorId),
  };
  await assertFails(updateDoc(
    doc(firestoreFor(volunteerId), 'publicaciones', donationPublicationId),
    update,
  ));
  await assertSucceeds(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    update,
  ));
});

test('HU12 Storage: autoriza actor correcto y prohíbe tercero y overwrite', async () => {
  await seedPickedUp();
  const path =
    `entregas/${donationPublicationId}/${volunteerId}/evidencia.jpg`;
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  await assertFails(uploadBytes(
    ref(storageFor('third-user'), path),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  const evidenceRef = ref(storageFor(volunteerId), path);
  await assertSucceeds(uploadBytes(evidenceRef, bytes, {
    contentType: 'image/jpeg',
  }));
  await assertFails(uploadBytes(evidenceRef, bytes, {
    contentType: 'image/jpeg',
  }));
});

test('notificaciones HU09-HU12 no pueden fabricarse sin operación legítima', async () => {
  await createVolunteerDonation();
  await assertFails(setDoc(
    doc(firestoreFor(volunteerId), 'notificaciones', 'forged-delivery'),
    {
      recipientId: donorId,
      type: 'recojo_asumido',
      message: 'Notificación inventada',
      publicationId: donationPublicationId,
      actorId: volunteerId,
      createdAt: serverTimestamp(),
      read: false,
    },
  ));
});

const adminId = 'admin-user';

// El rol lo asigna el backend (D06): se siembra sin reglas, como haría la
// consola de Firebase.
async function seedAdmin() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'usuarios', adminId), {
      nombreCompleto: 'Equipo ReHomeIt',
      nombres: 'Equipo',
      apellidos: 'ReHomeIt',
      correo: 'equipo@example.test',
      rol: 'administrador',
    });
  });
}

async function seedReport(reporterId, publicationId) {
  const reportId = reportIdFor(reporterId, publicationId);
  await assertSucceeds(setDoc(
    doc(firestoreFor(reporterId), 'reportes', reportId),
    initialReport({ reporterId, publicationId }),
  ));
  return reportId;
}

function resolution(status, resolvedBy = adminId) {
  return { status, resolvedAt: serverTimestamp(), resolvedBy };
}

function removal() {
  return { status: 'retirada', 'statusDates.retirada': serverTimestamp() };
}

function moderationNotification({
  recipientId,
  type,
  publicationId,
  reportId,
  proposalId,
  actorId = adminId,
}) {
  return {
    recipientId,
    type,
    message: 'Aviso de moderación.',
    publicationId,
    ...(reportId ? { reportId } : {}),
    ...(proposalId ? { proposalId } : {}),
    actorId,
    createdAt: serverTimestamp(),
    read: false,
  };
}

test('HU19: solo el administrador lista y lee los reportes pendientes', async () => {
  await createVolunteerDonation();
  const reportId = await seedReport('reporter', donationPublicationId);
  await seedAdmin();
  const pendingOf = (userId) => getDocs(query(
    collection(firestoreFor(userId), 'reportes'),
    where('status', '==', 'pendiente'),
    orderBy('createdAt'),
  ));
  await assertFails(pendingOf(donorId));
  await assertFails(pendingOf('reporter'));
  await assertSucceeds(pendingOf(adminId));
  await assertSucceeds(getDoc(doc(firestoreFor(adminId), 'reportes', reportId)));
});

test('HU19: desestimar resuelve el reporte, avisa a quien reportó y no toca la publicación', async () => {
  await createVolunteerDonation();
  const reportId = await seedReport('reporter', donationPublicationId);
  await seedAdmin();
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'reportes', reportId),
    resolution('desestimado', donorId),
  ));
  // Quien resuelve es quien firma la resolución.
  await assertFails(updateDoc(
    doc(firestoreFor(adminId), 'reportes', reportId),
    resolution('desestimado', 'otro'),
  ));

  const db = firestoreFor(adminId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'reportes', reportId), resolution('desestimado'));
  batch.set(doc(db, 'notificaciones', 'dismissed-notice'), moderationNotification({
    recipientId: 'reporter',
    type: 'reporte_resuelto',
    publicationId: donationPublicationId,
    reportId,
  }));
  await assertSucceeds(batch.commit());

  const report = await getDoc(doc(db, 'reportes', reportId));
  assert.equal(report.data().status, 'desestimado');
  assert.equal(report.data().resolvedBy, adminId);
  const publication = await getDoc(doc(db, 'publicaciones', donationPublicationId));
  assert.equal(publication.data().status, 'publicada');
});

test('HU19: retirar resuelve el reporte y avisa al autor y a quien reportó en el mismo lote', async () => {
  await createVolunteerDonation('donante');
  const reportId = await seedReport('reporter', donationPublicationId);
  await seedAdmin();
  // "Retirada" en el reporte exige la publicación retirada en el mismo lote.
  await assertFails(updateDoc(
    doc(firestoreFor(adminId), 'reportes', reportId),
    resolution('retirada'),
  ));
  // Un usuario común no retira, ni siquiera el autor.
  await assertFails(updateDoc(
    doc(firestoreFor(donorId), 'publicaciones', donationPublicationId),
    removal(),
  ));

  const db = firestoreFor(adminId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), removal());
  batch.update(doc(db, 'reportes', reportId), resolution('retirada'));
  batch.set(doc(db, 'notificaciones', 'author-notice'), moderationNotification({
    recipientId: donorId,
    type: 'publicacion_retirada',
    publicationId: donationPublicationId,
  }));
  batch.set(doc(db, 'notificaciones', 'reporter-notice'), moderationNotification({
    recipientId: 'reporter',
    type: 'reporte_resuelto',
    publicationId: donationPublicationId,
    reportId,
  }));
  await assertSucceeds(batch.commit());

  const publication = await getDoc(doc(db, 'publicaciones', donationPublicationId));
  assert.equal(publication.data().status, 'retirada');
  const report = await getDoc(doc(db, 'reportes', reportId));
  assert.equal(report.data().status, 'retirada');
});

test('HU19: retirar una donación comprometida avisa al voluntario', async () => {
  await seedCommitted();
  const reportId = await seedReport('reporter', donationPublicationId);
  await seedAdmin();
  const db = firestoreFor(adminId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', donationPublicationId), removal());
  batch.update(doc(db, 'reportes', reportId), resolution('retirada'));
  batch.set(doc(db, 'notificaciones', 'volunteer-notice'), moderationNotification({
    recipientId: volunteerId,
    type: 'compromiso_cancelado',
    publicationId: donationPublicationId,
  }));
  batch.set(doc(db, 'notificaciones', 'author-notice'), moderationNotification({
    recipientId: donorId,
    type: 'publicacion_retirada',
    publicationId: donationPublicationId,
  }));
  batch.set(doc(db, 'notificaciones', 'reporter-notice'), moderationNotification({
    recipientId: 'reporter',
    type: 'reporte_resuelto',
    publicationId: donationPublicationId,
    reportId,
  }));
  await assertSucceeds(batch.commit());
  // El aviso de cancelación solo va a quien tenía el compromiso.
  await assertFails(setDoc(
    doc(db, 'notificaciones', 'stranger-notice'),
    moderationNotification({
      recipientId: 'third-user',
      type: 'compromiso_cancelado',
      publicationId: donationPublicationId,
    }),
  ));
});

test('HU19: retirar un intercambio comprometido cancela la propuesta y libera la contraparte', async () => {
  await createExchangePublications();
  const proposalId = 'moderated-proposal';
  await createProposal(proposalId);
  await acceptProposal(proposalId);
  const reportId = await seedReport('reporter', requestedPublicationId);
  await seedAdmin();
  const db = firestoreFor(adminId);
  const release = {
    status: 'publicada',
    exchangeProposalId: deleteField(),
    counterpartPublicationId: deleteField(),
    counterpartUserId: deleteField(),
    committedAt: deleteField(),
  };
  // La contraparte no se libera sin cancelar la propuesta.
  await assertFails(updateDoc(
    doc(db, 'publicaciones', offeredPublicationId),
    release,
  ));

  const batch = writeBatch(db);
  batch.update(doc(db, 'publicaciones', requestedPublicationId), removal());
  batch.update(doc(db, 'propuestasIntercambio', proposalId), {
    status: 'cancelada',
    cancelledAt: serverTimestamp(),
  });
  batch.update(doc(db, 'publicaciones', offeredPublicationId), release);
  batch.update(doc(db, 'reportes', reportId), resolution('retirada'));
  batch.set(doc(db, 'notificaciones', 'counterpart-notice'), moderationNotification({
    recipientId: offeredOwnerId,
    type: 'compromiso_cancelado',
    publicationId: requestedPublicationId,
    proposalId,
  }));
  batch.set(doc(db, 'notificaciones', 'author-notice'), moderationNotification({
    recipientId: requestedOwnerId,
    type: 'publicacion_retirada',
    publicationId: requestedPublicationId,
  }));
  batch.set(doc(db, 'notificaciones', 'reporter-notice'), moderationNotification({
    recipientId: 'reporter',
    type: 'reporte_resuelto',
    publicationId: requestedPublicationId,
    reportId,
  }));
  await assertSucceeds(batch.commit());

  const offered = await getDoc(doc(db, 'publicaciones', offeredPublicationId));
  assert.equal(offered.data().status, 'publicada');
  assert.equal(offered.data().exchangeProposalId, undefined);
  const proposal = await getDoc(doc(db, 'propuestasIntercambio', proposalId));
  assert.equal(proposal.data().status, 'cancelada');
});

test('HU19: no se retira un bien que ya cambió de manos ni se fabrican avisos de moderación', async () => {
  await seedPickedUp();
  await seedAdmin();
  await assertFails(updateDoc(
    doc(firestoreFor(adminId), 'publicaciones', donationPublicationId),
    removal(),
  ));
  // Ni un usuario común, ni un administrador sin el retiro detrás.
  await assertFails(setDoc(
    doc(firestoreFor(volunteerId), 'notificaciones', 'forged-moderation'),
    moderationNotification({
      recipientId: donorId,
      type: 'publicacion_retirada',
      publicationId: donationPublicationId,
      actorId: volunteerId,
    }),
  ));
  await assertFails(setDoc(
    doc(firestoreFor(adminId), 'notificaciones', 'premature-notice'),
    moderationNotification({
      recipientId: donorId,
      type: 'publicacion_retirada',
      publicationId: donationPublicationId,
    }),
  ));
});

test('HU19: las propuestas pendientes sobre una publicación retirada se cancelan después', async () => {
  await createExchangePublications();
  const proposalId = 'pending-proposal';
  await createProposal(proposalId);
  await seedAdmin();
  const db = firestoreFor(adminId);
  const cancellation = { status: 'cancelada', cancelledAt: serverTimestamp() };
  // Con las dos publicaciones disponibles no hay nada que cancelar.
  await assertFails(updateDoc(
    doc(db, 'propuestasIntercambio', proposalId),
    cancellation,
  ));
  await assertSucceeds(updateDoc(
    doc(db, 'publicaciones', requestedPublicationId),
    removal(),
  ));
  await assertSucceeds(getDocs(query(
    collection(db, 'propuestasIntercambio'),
    where('requestedPublicationId', '==', requestedPublicationId),
    where('status', '==', 'pendiente'),
  )));
  await assertFails(updateDoc(
    doc(firestoreFor(offeredOwnerId), 'propuestasIntercambio', proposalId),
    cancellation,
  ));

  const batch = writeBatch(db);
  batch.update(doc(db, 'propuestasIntercambio', proposalId), cancellation);
  batch.set(doc(db, 'notificaciones', 'proposer-notice'), moderationNotification({
    recipientId: offeredOwnerId,
    type: 'compromiso_cancelado',
    publicationId: requestedPublicationId,
    proposalId,
  }));
  await assertSucceeds(batch.commit());
});

async function seedCampaignActor(userId, rol, nombreCompleto) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'usuarios', userId), {
      nombreCompleto,
      nombres: nombreCompleto,
      apellidos: '',
      correo: `${userId}@example.test`,
      rol,
    });
  });
}

function initialCampaign({
  organizationId = 'campaign-org',
  organizationName = 'Organización Solidaria',
  closeAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  status = 'active',
  contributedQuantity = 0,
  overrides = {},
} = {}) {
  return {
    organizationId,
    organizationName,
    title: 'Abrigo para Cajamarca',
    description: 'Recolectamos ropa de abrigo para familias de la zona.',
    district: 'Cajamarca',
    closeAt,
    imageUrl: null,
    imageStoragePath: null,
    collectionPoint: {
      name: 'Local comunal',
      address: 'Jr. Amalia 123',
      openingHours: 'Lunes a sábado, 9 a 17 h',
    },
    needs: [{
      id: 'ropa',
      name: 'Ropa',
      requiredQuantity: 10,
      contributedQuantity,
    }],
    contributions: {},
    status,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    closedAt: null,
    closedBy: null,
    closureReason: null,
    ...overrides,
  };
}

async function seedCampaign(campaignId, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'campanias', campaignId), data);
  });
}

test('HU15: un usuario normal no puede crear campañas', async () => {
  await seedCampaignActor('normal-user', 'usuario', 'Persona Regular');
  await assertFails(setDoc(
    doc(firestoreFor('normal-user'), 'campanias', 'normal-campaign'),
    initialCampaign({
      organizationId: 'normal-user',
      organizationName: 'Persona Regular',
    }),
  ));
});

test('HU15: una organización crea una campaña propia válida', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await assertSucceeds(setDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'own-campaign'),
    initialCampaign(),
  ));
});

test('HU15: una organización edita su campaña activa y agrega necesidades', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaign('editable-campaign', initialCampaign());
  await assertSucceeds(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'editable-campaign'),
    {
      title: 'Abrigo y alimentos para Cajamarca',
      needs: [
        {
          id: 'ropa',
          name: 'Ropa de abrigo',
          requiredQuantity: 12,
          contributedQuantity: 0,
        },
        {
          id: 'alimentos',
          name: 'Alimentos no perecibles',
          requiredQuantity: 20,
          contributedQuantity: 0,
        },
      ],
      updatedAt: serverTimestamp(),
    },
  ));
});

test('HU15: una organización no puede crear para otro uid', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await assertFails(setDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'foreign-campaign'),
    initialCampaign({ organizationId: 'other-org' }),
  ));
});

test('HU15: una organización no puede editar una campaña ajena', async () => {
  await seedCampaignActor('other-org', 'organizacion', 'Otra Organización');
  await seedCampaign('foreign-campaign', initialCampaign());
  await assertFails(updateDoc(
    doc(firestoreFor('other-org'), 'campanias', 'foreign-campaign'),
    { title: 'Título apropiado', updatedAt: serverTimestamp() },
  ));
});

test('HU15: la organización no manipula contributedQuantity', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaign('contributions-campaign', initialCampaign());
  await assertFails(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'contributions-campaign'),
    {
      needs: [{
        id: 'ropa',
        name: 'Ropa',
        requiredQuantity: 10,
        contributedQuantity: 7,
      }],
      updatedAt: serverTimestamp(),
    },
  ));
});

test('HU15: la organización no edita campañas vencidas ni cerradas', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaign('expired-campaign', initialCampaign({
    closeAt: new Date(Date.now() - 60 * 1000),
  }));
  await seedCampaign('closed-campaign', initialCampaign({
    status: 'closed',
    overrides: {
      closedAt: new Date(),
      closedBy: 'admin-user',
      closureReason: 'Cierre anticipado por administración',
    },
  }));
  const edit = { title: 'Título editado', updatedAt: serverTimestamp() };
  await assertFails(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'expired-campaign'),
    edit,
  ));
  await assertFails(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'closed-campaign'),
    edit,
  ));
});

test('HU15: el administrador cierra una campaña activa antes de fecha', async () => {
  await seedCampaignActor('campaign-admin', 'administrador', 'Admin');
  await seedCampaign('admin-close-campaign', initialCampaign());
  await assertSucceeds(updateDoc(
    doc(firestoreFor('campaign-admin'), 'campanias', 'admin-close-campaign'),
    {
      status: 'closed',
      updatedAt: serverTimestamp(),
      closedAt: serverTimestamp(),
      closedBy: 'campaign-admin',
      closureReason: 'Cierre anticipado por administración',
    },
  ));
});

test('HU15: la organización cierra una campaña propia antes de fecha', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaign('org-close-campaign', initialCampaign());
  await assertSucceeds(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'org-close-campaign'),
    {
      status: 'closed',
      updatedAt: serverTimestamp(),
      closedAt: serverTimestamp(),
      closedBy: 'campaign-org',
      closureReason: 'Cierre anticipado por la organización',
    },
  ));
});

test('HU15: la organización no cierra una campaña ajena ni usa el motivo de administración', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaignActor('other-org', 'organizacion', 'Otra Organización');
  await seedCampaign('foreign-close-campaign', initialCampaign());
  await seedCampaign('own-reason-campaign', initialCampaign());
  const closeAs = (uid) => ({
    status: 'closed',
    updatedAt: serverTimestamp(),
    closedAt: serverTimestamp(),
    closedBy: uid,
    closureReason: 'Cierre anticipado por la organización',
  });
  await assertFails(updateDoc(
    doc(firestoreFor('other-org'), 'campanias', 'foreign-close-campaign'),
    closeAs('other-org'),
  ));
  await assertFails(updateDoc(
    doc(firestoreFor('campaign-org'), 'campanias', 'own-reason-campaign'),
    {
      ...closeAs('campaign-org'),
      closureReason: 'Cierre anticipado por administración',
    },
  ));
});

test('HU15: una campaña cerrada no puede reabrirse', async () => {
  await seedCampaignActor('campaign-admin', 'administrador', 'Admin');
  await seedCampaign('no-reopen-campaign', initialCampaign({
    status: 'closed',
    overrides: {
      closedAt: new Date(),
      closedBy: 'campaign-admin',
      closureReason: 'Cierre anticipado por administración',
    },
  }));
  await assertFails(updateDoc(
    doc(firestoreFor('campaign-admin'), 'campanias', 'no-reopen-campaign'),
    { status: 'active', updatedAt: serverTimestamp() },
  ));
});

test('HU15: no se modifican campos inmutables', async () => {
  await seedCampaignActor(
    'campaign-org',
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaign('immutable-campaign', initialCampaign());
  const campaignRef = doc(
    firestoreFor('campaign-org'),
    'campanias',
    'immutable-campaign',
  );
  await assertFails(updateDoc(campaignRef, {
    organizationId: 'stolen-org',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(campaignRef, {
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(campaignRef, {
    status: 'closed',
    updatedAt: serverTimestamp(),
  }));
});

test('HU15: un usuario autenticado puede leer una campaña válida', async () => {
  await seedCampaign('readable-campaign', initialCampaign());
  await assertSucceeds(getDoc(
    doc(firestoreFor('reader'), 'campanias', 'readable-campaign'),
  ));
});

test('HU15: Storage reserva la portada a la organización propietaria', async () => {
  const campaignId = 'AbCdEfGhIjKlMnOpQrSt';
  const organizationId = 'storage-org';
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  await seedCampaignActor(
    organizationId,
    'organizacion',
    'Organización Storage',
  );
  await seedCampaignActor('storage-normal', 'usuario', 'Persona Regular');

  const path = `campanias/${campaignId}/${organizationId}/cover.jpg`;
  await assertSucceeds(uploadBytes(
    ref(storageFor(organizationId), path),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(storageFor('storage-normal'), path),
    bytes,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(storageFor(organizationId),
      `campanias/${campaignId}/${organizationId}/cover.txt`),
    bytes,
    { contentType: 'text/plain' },
  ));
  await assertSucceeds(deleteObject(ref(storageFor(organizationId), path)));
});

const contributionOrgId = 'campaign-org';
const contributionCampaignId = 'contribution-campaign';
const contributorId = 'contributor-user';

async function seedContributionScenario({
  status = 'active',
  closeAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  needs,
} = {}) {
  await seedCampaignActor(
    contributionOrgId,
    'organizacion',
    'Organización Solidaria',
  );
  await seedCampaignActor(contributorId, 'usuario', 'Persona Aportante');
  await seedCampaign(contributionCampaignId, initialCampaign({
    status,
    closeAt,
    overrides: needs ? { needs } : {},
  }));
}

function contributionData(overrides = {}) {
  return {
    campaignId: contributionCampaignId,
    campaignTitle: 'Abrigo para Cajamarca',
    organizationId: contributionOrgId,
    needId: 'ropa',
    needName: 'Ropa',
    quantity: 3,
    contributorId,
    contributorName: 'Persona A.',
    status: 'pendiente',
    createdAt: serverTimestamp(),
    confirmedAt: null,
    confirmedBy: null,
    rejectedAt: null,
    rejectedBy: null,
    rejectionReason: null,
    ...overrides,
  };
}

function confirmationNotification(contributionId, quantity = 3) {
  return {
    recipientId: contributorId,
    type: 'aporte_confirmado',
    message: `Confirmaron tu aporte de ${quantity} Ropa.`,
    campaignId: contributionCampaignId,
    contributionId,
    actorId: contributionOrgId,
    createdAt: serverTimestamp(),
    read: false,
  };
}

test('HU16: un usuario aporta a una necesidad declarada de una campaña activa', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-1'),
    contributionData(),
  ));
});

test('HU16: no se aporta fuera de las necesidades declaradas', async () => {
  await seedContributionScenario();
  await assertFails(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-unknown'),
    contributionData({ needId: 'no-existe', needName: 'Otra' }),
  ));
});

test('HU16: la organización no aporta a su propia campaña', async () => {
  await seedContributionScenario();
  await assertFails(setDoc(
    doc(firestoreFor(contributionOrgId), 'aportes', 'own-contribution'),
    contributionData({
      contributorId: contributionOrgId,
      contributorName: 'Organización Solidaria',
    }),
  ));
});

test('HU16: no se aporta a una campaña cerrada ni vencida', async () => {
  await seedContributionScenario({
    status: 'closed',
    closeAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  });
  await assertFails(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'closed-contribution'),
    contributionData(),
  ));

  await testEnv.clearFirestore();
  await seedContributionScenario({
    closeAt: new Date(Date.now() - 60 * 1000),
  });
  await assertFails(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'expired-contribution'),
    contributionData(),
  ));
});

test('HU16: la organización confirma el aporte e incrementa el contador en el mismo lote', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-2'),
    contributionData({ quantity: 4 }),
  ));

  const db = firestoreFor(contributionOrgId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'aportes', 'contribution-2'), {
    status: 'confirmado',
    confirmedAt: serverTimestamp(),
    confirmedBy: contributionOrgId,
  });
  batch.update(doc(db, 'campanias', contributionCampaignId), {
    'contributions.ropa': increment(4),
    lastContributionId: 'contribution-2',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(db, 'notificaciones', 'contribution-confirmed'),
    confirmationNotification('contribution-2', 4),
  );
  await assertSucceeds(batch.commit());

  const campaign = await getDoc(doc(db, 'campanias', contributionCampaignId));
  assert.equal(campaign.data().contributions.ropa, 4);
  const contribution = await getDoc(doc(db, 'aportes', 'contribution-2'));
  assert.equal(contribution.data().status, 'confirmado');
});

test('HU16: el avance puede superar la cantidad requerida', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'over-contribution'),
    contributionData({ quantity: 12 }),
  ));
  const db = firestoreFor(contributionOrgId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'aportes', 'over-contribution'), {
    status: 'confirmado',
    confirmedAt: serverTimestamp(),
    confirmedBy: contributionOrgId,
  });
  batch.update(doc(db, 'campanias', contributionCampaignId), {
    'contributions.ropa': increment(12),
    lastContributionId: 'over-contribution',
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  const campaign = await getDoc(doc(db, 'campanias', contributionCampaignId));
  assert.equal(campaign.data().contributions.ropa, 12);
});

test('HU16: solo la organización responsable confirma sus aportes', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-3'),
    contributionData(),
  ));
  await assertFails(updateDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-3'),
    {
      status: 'confirmado',
      confirmedAt: serverTimestamp(),
      confirmedBy: contributorId,
    },
  ));
});

test('HU16: la confirmación exige el incremento atómico real', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'contribution-4'),
    contributionData({ quantity: 5 }),
  ));
  const db = firestoreFor(contributionOrgId);
  // Confirmar sin tocar la campaña queda sin el respaldo del incremento.
  await assertFails(updateDoc(doc(db, 'aportes', 'contribution-4'), {
    status: 'confirmado',
    confirmedAt: serverTimestamp(),
    confirmedBy: contributionOrgId,
  }));
  // Un incremento que no coincide con la cantidad tampoco vale.
  const forged = writeBatch(db);
  forged.update(doc(db, 'aportes', 'contribution-4'), {
    status: 'confirmado',
    confirmedAt: serverTimestamp(),
    confirmedBy: contributionOrgId,
  });
  forged.update(doc(db, 'campanias', contributionCampaignId), {
    'contributions.ropa': increment(99),
    lastContributionId: 'contribution-4',
    updatedAt: serverTimestamp(),
  });
  await assertFails(forged.commit());
});

test('HU16: la organización rechaza un aporte con motivo acotado', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'rejected-contribution'),
    contributionData(),
  ));
  const db = firestoreFor(contributionOrgId);
  await assertSucceeds(updateDoc(doc(db, 'aportes', 'rejected-contribution'), {
    status: 'rechazado',
    rejectedAt: serverTimestamp(),
    rejectedBy: contributionOrgId,
    rejectionReason: 'No llegó el bien al punto de acopio.',
  }));
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'rejected-empty'),
    contributionData(),
  ));
  await assertFails(updateDoc(doc(db, 'aportes', 'rejected-empty'), {
    status: 'rechazado',
    rejectedAt: serverTimestamp(),
    rejectedBy: contributionOrgId,
    rejectionReason: '',
  }));
});

test('HU16: no se fabrican avisos de aporte sin la confirmación o rechazo reales', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'pending-contribution'),
    contributionData(),
  ));
  // El propio aportante no puede avisarse que su aporte fue confirmado.
  await assertFails(setDoc(
    doc(firestoreFor(contributorId), 'notificaciones', 'forged-contribution'),
    {
      recipientId: contributorId,
      type: 'aporte_confirmado',
      message: 'Aporte confirmado.',
      campaignId: contributionCampaignId,
      contributionId: 'pending-contribution',
      actorId: contributorId,
      createdAt: serverTimestamp(),
      read: false,
    },
  ));
  // La organización tampoco, porque el aporte sigue pendiente.
  await assertFails(setDoc(
    doc(firestoreFor(contributionOrgId), 'notificaciones', 'early-contribution'),
    confirmationNotification('pending-contribution'),
  ));
});

test('HU16: solo el aportante y la organización leen el aporte', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'private-contribution'),
    contributionData(),
  ));
  await assertSucceeds(getDoc(
    doc(firestoreFor(contributorId), 'aportes', 'private-contribution'),
  ));
  await assertSucceeds(getDoc(
    doc(firestoreFor(contributionOrgId), 'aportes', 'private-contribution'),
  ));
  await assertFails(getDoc(
    doc(firestoreFor('third-user'), 'aportes', 'private-contribution'),
  ));
});

test('HU16: la organización lista los aportes pendientes de su campaña', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'pending-list-item'),
    contributionData(),
  ));
  const db = firestoreFor(contributionOrgId);
  await assertSucceeds(getDocs(query(
    collection(db, 'aportes'),
    where('organizationId', '==', contributionOrgId),
    where('status', '==', 'pendiente'),
  )));
});

test('HU16: el aportante lista sus propios aportes', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'mine-list-item'),
    contributionData(),
  ));
  const db = firestoreFor(contributorId);
  await assertSucceeds(getDocs(query(
    collection(db, 'aportes'),
    where('contributorId', '==', contributorId),
  )));
});

test('HU16: un tercero no lista aportes ajenos y la organización no los lista todos', async () => {
  await seedContributionScenario();
  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'guarded-list-item'),
    contributionData(),
  ));
  await assertFails(getDocs(query(
    collection(firestoreFor('third-user'), 'aportes'),
    where('contributorId', '==', contributorId),
  )));
  await assertFails(getDocs(query(
    collection(firestoreFor(contributionOrgId), 'aportes'),
    where('status', '==', 'pendiente'),
  )));
});

test('HU16: la organización confirma aportes de campañas creadas antes de D08', async () => {
  await seedCampaignActor(contributionOrgId, 'organizacion', 'Organización Solidaria');
  await seedCampaignActor(contributorId, 'usuario', 'Persona Aportante');
  // Campaña anterior a D08: sin el mapa `contributions`.
  const legacy = initialCampaign();
  delete legacy.contributions;
  await seedCampaign(contributionCampaignId, legacy);

  await assertSucceeds(setDoc(
    doc(firestoreFor(contributorId), 'aportes', 'legacy-create'),
    contributionData(),
  ));

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'aportes', 'legacy-confirm'),
      contributionData({ quantity: 4 }),
    );
  });
  const db = firestoreFor(contributionOrgId);
  const batch = writeBatch(db);
  batch.update(doc(db, 'aportes', 'legacy-confirm'), {
    status: 'confirmado',
    confirmedAt: serverTimestamp(),
    confirmedBy: contributionOrgId,
  });
  batch.update(doc(db, 'campanias', contributionCampaignId), {
    'contributions.ropa': increment(4),
    lastContributionId: 'legacy-confirm',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(db, 'notificaciones', 'legacy-confirm-notif'),
    confirmationNotification('legacy-confirm', 4),
  );
  await assertSucceeds(batch.commit());

  const campaign = await getDoc(doc(db, 'campanias', contributionCampaignId));
  assert.equal(campaign.data().contributions.ropa, 4);
  const contribution = await getDoc(doc(db, 'aportes', 'legacy-confirm'));
  assert.equal(contribution.data().status, 'confirmado');
});


