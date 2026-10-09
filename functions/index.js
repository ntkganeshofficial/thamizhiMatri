const crypto = require('crypto');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const RAZORPAY_WEBHOOK_SECRET = defineSecret('RAZORPAY_WEBHOOK_SECRET');

// Authoritative prices in rupees. The app only sends a plan id, never an amount.
const PLANS = {
  m1: { months: 1, rupees: 49 },
  m3: { months: 3, rupees: 119 },
  m6: { months: 6, rupees: 199 },
};

const REGION = 'asia-south1';
const callOptions = { region: REGION, secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] };

function requireAuth(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return request.auth.uid;
}

function hmacHex(secret, data) {
  return crypto.createHmac('sha256', secret).update(data).digest('hex');
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

/**
 * Extends the member's premium window for a paid order. Safe to call repeatedly:
 * an order that is already marked paid is not credited twice.
 */
async function creditOrder(orderId, paymentId, expectedUid) {
  const orderRef = db.doc(`orders/${orderId}`);
  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = orderSnap.data();
    if (expectedUid && order.uid !== expectedUid) throw new HttpsError('not-found', 'Order not found.');

    const entitlementRef = db.doc(`entitlements/${order.uid}`);
    const entSnap = await tx.get(entitlementRef);
    const current = entSnap.exists && entSnap.data().premiumUntil ? entSnap.data().premiumUntil.toDate() : null;

    if (order.status === 'paid') return current;

    const plan = PLANS[order.planId];
    const start = current && current > new Date() ? current : new Date();
    const until = new Date(start);
    until.setMonth(until.getMonth() + plan.months);

    tx.set(entitlementRef, {
      premiumUntil: admin.firestore.Timestamp.fromDate(until),
      lastPlanId: order.planId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.update(orderRef, {
      status: 'paid',
      paymentId,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return until;
  });
}

/** Takes back the premium time granted by a paid order after a full refund. Idempotent. */
async function revokeOrder(orderRef) {
  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists || orderSnap.data().status !== 'paid') return false;
    const order = orderSnap.data();

    const entitlementRef = db.doc(`entitlements/${order.uid}`);
    const entSnap = await tx.get(entitlementRef);
    if (entSnap.exists && entSnap.data().premiumUntil) {
      const until = entSnap.data().premiumUntil.toDate();
      until.setMonth(until.getMonth() - PLANS[order.planId].months);
      tx.set(entitlementRef, {
        premiumUntil: admin.firestore.Timestamp.fromDate(until),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    tx.update(orderRef, { status: 'refunded', refundedAt: admin.firestore.FieldValue.serverTimestamp() });
    return true;
  });
}

exports.createOrder = onCall(callOptions, async (request) => {
  const uid = requireAuth(request);
  const plan = PLANS[request.data && request.data.planId];
  if (!plan) throw new HttpsError('invalid-argument', 'Unknown plan.');

  const basic = Buffer.from(`${RAZORPAY_KEY_ID.value()}:${RAZORPAY_KEY_SECRET.value()}`).toString('base64');
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: plan.rupees * 100,
      currency: 'INR',
      receipt: `${uid.slice(0, 16)}_${Date.now()}`,
      notes: { uid, planId: request.data.planId },
    }),
  });
  if (!response.ok) {
    console.error('Razorpay order failed', response.status, await response.text());
    throw new HttpsError('internal', 'Could not start the payment.');
  }
  const order = await response.json();

  await db.doc(`orders/${order.id}`).set({
    uid,
    planId: request.data.planId,
    amount: plan.rupees * 100,
    status: 'created',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { orderId: order.id, amount: order.amount, currency: order.currency, keyId: RAZORPAY_KEY_ID.value() };
});

// Called by the app right after checkout succeeds.
exports.verifyPayment = onCall(callOptions, async (request) => {
  const uid = requireAuth(request);
  const { orderId, paymentId, signature } = request.data || {};
  if (!orderId || !paymentId || !signature) throw new HttpsError('invalid-argument', 'Missing payment details.');

  if (!safeEqual(hmacHex(RAZORPAY_KEY_SECRET.value(), `${orderId}|${paymentId}`), signature)) {
    throw new HttpsError('permission-denied', 'Payment signature mismatch.');
  }

  const premiumUntil = await creditOrder(orderId, paymentId, uid);
  return { premiumUntil: premiumUntil ? premiumUntil.getTime() : null };
});

// Called by Razorpay itself, so premium is still granted if the app closes mid-payment.
exports.razorpayWebhook = onRequest({ region: REGION, secrets: [RAZORPAY_WEBHOOK_SECRET] }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }

  const signature = req.get('x-razorpay-signature') || '';
  if (!req.rawBody || !safeEqual(hmacHex(RAZORPAY_WEBHOOK_SECRET.value(), req.rawBody), signature)) {
    console.warn('Webhook rejected: signature mismatch (check the secret saved in the Razorpay dashboard)');
    res.status(400).send('Invalid signature');
    return;
  }

  const event = req.body || {};
  console.log('Webhook received', event.event);

  if (event.event === 'refund.processed') {
    const refund = event.payload && event.payload.refund && event.payload.refund.entity;
    if (!refund || !refund.payment_id) {
      res.status(200).send('No refund data');
      return;
    }
    try {
      const found = await db.collection('orders').where('paymentId', '==', refund.payment_id).limit(1).get();
      if (found.empty) {
        console.warn('Refund for unknown payment', refund.payment_id);
        res.status(200).send('Unknown payment');
        return;
      }
      const orderDoc = found.docs[0];
      if (refund.amount < orderDoc.data().amount) {
        console.log('Partial refund ignored for order', orderDoc.id);
        res.status(200).send('Partial refund ignored');
        return;
      }
      const revoked = await revokeOrder(orderDoc.ref);
      console.log('Refund processed for order', orderDoc.id, 'premium revoked:', revoked);
      res.status(200).send('OK');
    } catch (e) {
      console.error('Refund processing failed', e);
      res.status(500).send('Retry');
    }
    return;
  }

  if (event.event !== 'order.paid' && event.event !== 'payment.captured') {
    res.status(200).send('Ignored');
    return;
  }

  const payload = event.payload || {};
  const payment = payload.payment && payload.payment.entity;
  const orderId = (payment && payment.order_id) || (payload.order && payload.order.entity && payload.order.entity.id);
  if (!payment || !orderId) {
    res.status(200).send('No payment data');
    return;
  }

  try {
    const orderSnap = await db.doc(`orders/${orderId}`).get();
    if (!orderSnap.exists) {
      console.warn('Webhook for unknown order', orderId);
      res.status(200).send('Unknown order');
      return;
    }
    if (orderSnap.data().amount !== payment.amount) {
      console.error('Webhook amount mismatch', orderId, payment.amount);
      res.status(200).send('Amount mismatch');
      return;
    }
    await creditOrder(orderId, payment.id);
    console.log('Webhook processed order', orderId, 'for event', event.event);
    res.status(200).send('OK');
  } catch (e) {
    console.error('Webhook processing failed', e);
    res.status(500).send('Retry');
  }
});

// Machine translation of member-written text (name, occupation, about, ...). Results are cached for everyone.
const { Translate } = require('@google-cloud/translate').v2;
const translateClient = new Translate();

exports.translateTexts = onCall({ region: REGION }, async (request) => {
  requireAuth(request);
  const { texts, target } = request.data || {};
  if (!Array.isArray(texts) || texts.length === 0 || texts.length > 25 || !['ta', 'en'].includes(target)) {
    throw new HttpsError('invalid-argument', 'Invalid translation request.');
  }
  const clean = texts.map((t) => (typeof t === 'string' ? t.trim() : ''));
  if (clean.some((t) => t.length > 1500)) throw new HttpsError('invalid-argument', 'Text too long.');

  const keys = clean.map((t) => crypto.createHash('sha1').update(`${target}|${t}`).digest('hex'));
  const refs = keys.map((k) => db.doc(`translations/${k}`));
  const snaps = await db.getAll(...refs);

  const out = clean.map((t, i) => (snaps[i].exists ? snaps[i].data().out : null));
  const missing = [];
  out.forEach((v, i) => {
    if (v === null && clean[i]) missing.push(i);
  });

  if (missing.length > 0) {
    let translated;
    try {
      [translated] = await translateClient.translate(missing.map((i) => clean[i]), { to: target, format: 'text' });
    } catch (e) {
      console.error('Translation API failed:', e.code, e.message);
      throw new HttpsError('failed-precondition', 'Translation service unavailable.');
    }
    const list = Array.isArray(translated) ? translated : [translated];
    const batch = db.batch();
    missing.forEach((idx, n) => {
      out[idx] = list[n];
      batch.set(refs[idx], { target, text: clean[idx], out: list[n], createdAt: admin.firestore.FieldValue.serverTimestamp() });
    });
    await batch.commit();
  }

  return { translations: out.map((v, i) => v ?? clean[i]) };
});

// Permanently removes a member and everything tied to them. Payment orders are kept for accounting.
const REMOVAL_REASONS = ['found_here', 'found_elsewhere', 'break', 'unwanted_contact', 'privacy', 'poor_matches', 'other'];

exports.deleteAccount = onCall({ region: REGION, timeoutSeconds: 120 }, async (request) => {
  const uid = requireAuth(request);
  const { reason, note } = request.data || {};
  if (!REMOVAL_REASONS.includes(reason)) throw new HttpsError('invalid-argument', 'Choose a reason.');
  const cleanNote = typeof note === 'string' ? note.trim().slice(0, 500) : '';

  await db.collection('accountFeedback').add({
    uid,
    action: 'delete',
    reason,
    note: cleanNote,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const [photos] = await admin.storage().bucket().getFiles({ prefix: `profile_photos/${uid}_` });
  await Promise.all(photos.map((f) => f.delete().catch(() => {})));

  const pairQueries = [
    ['interests', 'fromUid'], ['interests', 'toUid'],
    ['shortlists', 'fromUid'], ['shortlists', 'toUid'],
    ['views', 'viewerUid'], ['views', 'targetUid'],
    ['photoRequests', 'fromUid'], ['photoRequests', 'toUid'],
  ];
  for (const [collection, field] of pairQueries) {
    const snap = await db.collection(collection).where(field, '==', uid).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }

  const chats = await db.collection('chats').where('participants', 'array-contains', uid).get();
  await Promise.all(chats.docs.map((d) => db.recursiveDelete(d.ref)));

  // Profiles this member (if an admin) created for other people go with the account.
  const managed = await db.collection('profiles').where('managedBy', '==', uid).get();
  await Promise.all(managed.docs.map((d) => db.recursiveDelete(d.ref)));

  await db.recursiveDelete(db.doc(`profiles/${uid}`));
  await db.doc(`entitlements/${uid}`).delete();
  await admin.auth().deleteUser(uid);
  return { ok: true };
});
