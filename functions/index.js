const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

admin.initializeApp();

/**
 * Create Payment Intent
 */
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated to create payment intent",
      );
    }

    const {amount, currency, clientId, trainerId} = data;

    // Validate required fields
    if (!amount || !currency || !clientId || !trainerId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields: amount, currency, clientId, trainerId",
      );
    }

    // Create payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        client_id: clientId,
        trainer_id: trainerId,
        sessions_purchased: "10",
        firebase_user_id: context.auth.uid,
      },
    });

    // Return only necessary data to client
    return {
      id: paymentIntent.id,
      client_secret: paymentIntent.client_secret,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      status: paymentIntent.status,
    };
  } catch (error) {
    console.error("Error creating payment intent:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Confirm Payment Intent (optional - for additional server-side logic)
 */
exports.confirmPaymentIntent = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated",
      );
    }

    const {paymentIntentId} = data;

    if (!paymentIntentId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Payment intent ID is required",
      );
    }

    // Retrieve payment intent from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    return {
      id: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
    };
  } catch (error) {
    console.error("Error confirming payment intent:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Webhook to handle successful payments
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const endpointSecret = functions.config().stripe.webhook_secret;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Handle the event
  switch (event.type) {
    case "payment_intent.succeeded": {
      const paymentIntent = event.data.object;

      // Update your database with successful payment
      try {
        const clientId = paymentIntent.metadata.client_id;
        const trainerId = paymentIntent.metadata.trainer_id;

        // Add sessions to the client's package
        await updateSessionPackage(clientId, trainerId, paymentIntent);

        // Record payment history
        await recordPaymentHistory(clientId, trainerId, paymentIntent);

        console.log("Payment succeeded:", paymentIntent.id);
      } catch (error) {
        console.error("Error processing successful payment:", error);
      }
      break;
    }
    case "payment_intent.payment_failed":
      console.log("Payment failed:", event.data.object.id);
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({received: true});
});

/**
 * Helper function to update session package
 * @param {string} clientId - The client ID
 * @param {string} trainerId - The trainer ID
 * @param {object} paymentIntent - The Stripe payment intent object
 */
async function updateSessionPackage(clientId, trainerId, paymentIntent) {
  const db = admin.firestore();

  try {
    // Get session package
    const packageQuery = await db.collection("sessionPackages")
        .where("clientId", "==", clientId)
        .where("trainerId", "==", trainerId)
        .limit(1)
        .get();

    if (!packageQuery.empty) {
      const packageDoc = packageQuery.docs[0];
      const currentData = packageDoc.data();

      // Add 10 sessions
      await packageDoc.ref.update({
        sessionsRemaining: (currentData.sessionsRemaining || 0) + 10,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Error updating session package:", error);
    throw error;
  }
}

/**
 * Helper function to record payment history
 * @param {string} clientId - The client ID
 * @param {string} trainerId - The trainer ID
 * @param {object} paymentIntent - The Stripe payment intent object
 */
async function recordPaymentHistory(clientId, trainerId, paymentIntent) {
  const db = admin.firestore();

  try {
    await db.collection("paymentHistory").add({
      clientId: clientId,
      trainerId: trainerId,
      sessionPackageId: "", // You might want to get this from session package
      amount: paymentIntent.amount / 100, // Convert back from cents
      sessionsPurchased: 10,
      stripePaymentIntentId: paymentIntent.id,
      status: "completed",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error recording payment history:", error);
    throw error;
  }
}
