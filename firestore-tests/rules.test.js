// Tests de firestore.rules. Correr con: npm test (levanta el emulador).
// Cada caso "permite" replica una operación real de la app (lib/);
// cada caso "rechaza" es un abuso que las reglas deben bloquear.
const { test, before, after, beforeEach, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, addDoc, deleteDoc, collection, query, where,
  orderBy, limit, getDocs, serverTimestamp, deleteField, Timestamp, writeBatch,
} = require('firebase/firestore');

let env;
const A = 'alice';
const B = 'bob';
const C = 'carol';

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-truequeapp',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    for (const uid of [A, B, C]) {
      await setDoc(doc(f, 'users', uid), {
        uid, email: `${uid}@x.com`, name: uid, phoneNumber: `+593${uid.length}`, photoUrl: null,
        notifyNewItems: true, fcmToken: `tok-${uid}`,
      });
    }
    await setDoc(doc(f, 'items', 'itemA'), { ownerId: A, title: 'A', status: 'available' });
    await setDoc(doc(f, 'items', 'itemB'), { ownerId: B, title: 'B', status: 'available' });
    await setDoc(doc(f, 'exchanges', 'ex1'), {
      senderId: B, receiverId: A, senderItemId: 'itemB', receiverItemId: 'itemA',
      status: 'pending', type: 'proposal',
    });
    await setDoc(doc(f, 'exchanges', 'ex1', 'messages', 'm1'), { senderId: B, text: 'hola' });
    await setDoc(doc(f, 'notifications', 'n1'), {
      userId: A, exchangeId: 'ex1', type: 'new_message', isRead: false, senderId: B,
    });
  });
});

describe('users', () => {
  test('permite: registro crea su propio documento (sin email verificado)', async () => {
    await assertSucceeds(setDoc(doc(db('dave'), 'users', 'dave'), {
      uid: 'dave', email: 'd@x.com', name: 'd', phoneNumber: '1', photoUrl: null, notifyNewItems: true,
    }));
  });
  test('rechaza: crear el documento de otro usuario', async () => {
    await assertFails(setDoc(doc(db('dave'), 'users', A), { uid: A }));
  });
  test('permite: leer el perfil de otro usuario con sesión', async () => {
    await assertSucceeds(getDoc(doc(db(B), 'users', A)));
  });
  test('rechaza: leer un perfil sin sesión', async () => {
    await assertFails(getDoc(doc(db(null), 'users', A)));
  });
  test('rechaza: buscar usuarios por teléfono (con o sin sesión)', async () => {
    await assertFails(getDocs(query(collection(db(null), 'users'),
      where('phoneNumber', '==', '+5935'), limit(1))));
    await assertFails(getDocs(query(collection(db(A), 'users'),
      where('phoneNumber', '==', '+5935'), limit(1))));
  });
  test('rechaza: listar todos los usuarios', async () => {
    await assertFails(getDocs(collection(db(null), 'users')));
    await assertFails(getDocs(collection(db(A), 'users')));
  });
  test('permite: editar nombre y teléfono propios', async () => {
    await assertSucceeds(updateDoc(doc(db(A), 'users', A), { name: 'Ali', phoneNumber: '9' }));
  });
  test('permite: guardar y borrar el token propio, y la preferencia', async () => {
    const f = db(A);
    await assertSucceeds(setDoc(doc(f, 'users', A), { fcmToken: 't2', tokenUpdatedAt: serverTimestamp() }, { merge: true }));
    await assertSucceeds(setDoc(doc(f, 'users', A), { fcmToken: deleteField() }, { merge: true }));
    await assertSucceeds(setDoc(doc(f, 'users', A), { notifyNewItems: false }, { merge: true }));
  });
  test('rechaza: editar a otro usuario o cambiar campos protegidos', async () => {
    await assertFails(updateDoc(doc(db(B), 'users', A), { name: 'x' }));
    await assertFails(updateDoc(doc(db(A), 'users', A), { email: 'otro@x.com' }));
    await assertFails(updateDoc(doc(db(A), 'users', A), { deleted: true }));
  });
  test('rechaza: borrar un usuario', async () => {
    await assertFails(deleteDoc(doc(db(A), 'users', A)));
  });
});

describe('items', () => {
  test('permite: listar todos los artículos (Home) y leer uno', async () => {
    await assertSucceeds(getDocs(collection(db(C), 'items')));
    await assertSucceeds(getDoc(doc(db(C), 'items', 'itemA')));
  });
  test('permite: publicar un artículo propio disponible', async () => {
    await assertSucceeds(addDoc(collection(db(A), 'items'), {
      ownerId: A, title: 'n', description: 'd', categoryId: 'tech', imageUrls: [],
      desiredItem: 'Donation', status: 'available', createdAt: serverTimestamp(),
    }));
  });
  test('rechaza: publicar a nombre de otro (push masiva suplantando)', async () => {
    await assertFails(addDoc(collection(db(C), 'items'), { ownerId: A, title: 'spam', status: 'available' }));
  });
  test('rechaza: publicar sin sesión', async () => {
    await assertFails(addDoc(collection(db(null), 'items'), { ownerId: A, status: 'available' }));
  });
  test('permite: el dueño edita su artículo', async () => {
    await assertSucceeds(updateDoc(doc(db(A), 'items', 'itemA'), {
      ownerId: A, title: 'nuevo', status: 'available',
    }));
  });
  test('rechaza: el dueño transfiere el artículo a otro', async () => {
    await assertFails(updateDoc(doc(db(A), 'items', 'itemA'), { ownerId: B }));
  });
  test('permite: al aceptar, el receptor marca intercambiado el artículo del remitente', async () => {
    await assertSucceeds(updateDoc(doc(db(A), 'items', 'itemB'), {
      status: 'exchanged', updatedAt: serverTimestamp(),
    }));
  });
  test('rechaza: otro usuario edita título o reactiva un artículo ajeno', async () => {
    await assertFails(updateDoc(doc(db(C), 'items', 'itemA'), { title: 'hack' }));
    await assertFails(updateDoc(doc(db(C), 'items', 'itemA'), { status: 'exchanged', title: 'x' }));
  });
  test('permite: el dueño borra; rechaza: otro borra', async () => {
    await assertFails(deleteDoc(doc(db(C), 'items', 'itemA')));
    await assertSucceeds(deleteDoc(doc(db(A), 'items', 'itemA')));
  });
});

describe('exchanges', () => {
  test('permite: crear una propuesta como remitente', async () => {
    await assertSucceeds(addDoc(collection(db(C), 'exchanges'), {
      senderId: C, receiverId: A, receiverItemId: 'itemA', senderItemId: null, message: null,
      status: 'pending', type: 'donation_request', createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(), notificationSent: false,
    }));
  });
  test('rechaza: crear a nombre de otro, consigo mismo o ya aceptada', async () => {
    await assertFails(addDoc(collection(db(C), 'exchanges'), { senderId: A, receiverId: B, status: 'pending' }));
    await assertFails(addDoc(collection(db(C), 'exchanges'), { senderId: C, receiverId: C, status: 'pending' }));
    await assertFails(addDoc(collection(db(C), 'exchanges'), { senderId: C, receiverId: A, status: 'accepted' }));
  });
  test('permite: consultas de la app por remitente y receptor', async () => {
    await assertSucceeds(getDocs(query(collection(db(B), 'exchanges'),
      where('senderId', '==', B), orderBy('createdAt', 'desc'))));
    await assertSucceeds(getDocs(query(collection(db(A), 'exchanges'),
      where('receiverId', '==', A), where('status', 'in', ['accepted', 'received']))));
  });
  test('rechaza: listar intercambios ajenos o leer uno ajeno', async () => {
    await assertFails(getDocs(collection(db(C), 'exchanges')));
    await assertFails(getDoc(doc(db(C), 'exchanges', 'ex1')));
  });
  test('permite: participantes cambian estado y último mensaje', async () => {
    await assertSucceeds(updateDoc(doc(db(A), 'exchanges', 'ex1'), { status: 'accepted', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db(B), 'exchanges', 'ex1'), {
      lastMessage: 'hola', lastMessageAt: serverTimestamp(), lastMessageSenderId: B,
    }));
  });
  test('rechaza: tercero cambia el estado; participante cambia las partes', async () => {
    await assertFails(updateDoc(doc(db(C), 'exchanges', 'ex1'), { status: 'accepted' }));
    await assertFails(updateDoc(doc(db(A), 'exchanges', 'ex1'), { receiverId: C }));
  });
  test('rechaza: borrar un intercambio', async () => {
    await assertFails(deleteDoc(doc(db(A), 'exchanges', 'ex1')));
  });
});

describe('messages', () => {
  test('permite: participantes leen y escriben el chat', async () => {
    await assertSucceeds(getDocs(query(collection(db(A), 'exchanges', 'ex1', 'messages'), orderBy('createdAt'))));
    await assertSucceeds(addDoc(collection(db(A), 'exchanges', 'ex1', 'messages'), {
      exchangeId: 'ex1', senderId: A, senderName: 'alice', text: 'hola', createdAt: serverTimestamp(),
    }));
  });
  test('rechaza: tercero lee o escribe; participante firma como otro', async () => {
    await assertFails(getDocs(collection(db(C), 'exchanges', 'ex1', 'messages')));
    await assertFails(addDoc(collection(db(C), 'exchanges', 'ex1', 'messages'), { senderId: C, text: 'x' }));
    await assertFails(addDoc(collection(db(A), 'exchanges', 'ex1', 'messages'), { senderId: B, text: 'x' }));
  });
  test('rechaza: editar o borrar mensajes', async () => {
    await assertFails(updateDoc(doc(db(B), 'exchanges', 'ex1', 'messages', 'm1'), { text: 'x' }));
    await assertFails(deleteDoc(doc(db(B), 'exchanges', 'ex1', 'messages', 'm1')));
  });
});

describe('notifications', () => {
  const chatNotif = (from, to) => ({
    userId: to, exchangeId: 'ex1', type: 'new_message', title: 't', body: 'b',
    isRead: false, createdAt: Timestamp.now(), senderId: from, senderName: from,
  });
  test('permite: aviso de chat para el otro participante', async () => {
    await assertSucceeds(addDoc(collection(db(B), 'notifications'), chatNotif(B, A)));
  });
  test('rechaza: avisos a terceros, de otro tipo o firmados por otro', async () => {
    await assertFails(addDoc(collection(db(B), 'notifications'), chatNotif(B, C)));
    await assertFails(addDoc(collection(db(C), 'notifications'), chatNotif(C, A)));
    await assertFails(addDoc(collection(db(B), 'notifications'), { ...chatNotif(B, A), type: 'exchange_accepted' }));
    await assertFails(addDoc(collection(db(B), 'notifications'), { ...chatNotif(A, A), senderId: A }));
  });
  test('permite: el destinatario lista y marca como leídas', async () => {
    const f = db(A);
    await assertSucceeds(getDocs(query(collection(f, 'notifications'), where('userId', '==', A), orderBy('createdAt', 'desc'))));
    const unread = await getDocs(query(collection(f, 'notifications'), where('userId', '==', A), where('isRead', '==', false)));
    const batch = writeBatch(f);
    unread.forEach((d) => batch.update(d.ref, { isRead: true }));
    await assertSucceeds(batch.commit());
  });
  test('rechaza: leer avisos ajenos o cambiar otros campos', async () => {
    await assertFails(getDocs(query(collection(db(B), 'notifications'), where('userId', '==', A))));
    await assertFails(updateDoc(doc(db(B), 'notifications', 'n1'), { isRead: true }));
    await assertFails(updateDoc(doc(db(A), 'notifications', 'n1'), { body: 'x' }));
  });
});
