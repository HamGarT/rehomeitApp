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
  doc,
  deleteField,
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
  await createVolunteerDonation();
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

test('HU09: participante envía y no puede falsificar senderId', async () => {
  await createVolunteerDonation();
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
