const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

admin.initializeApp();

// === UTILITY FUNCTIONS ===

/**
 * Send push notification to user via FCM
 * @param {string} userId - The user ID to send notification to
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data payload
 */
async function sendPushNotification(userId, title, body, data = {}) {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens found for user ${userId}`);
      return;
    }

    // Create the notification payload
    const payload = {
      notification: {
        title: title,
        body: body,
        sound: "default",
        badge: "1",
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    // Send to all tokens
    const validTokens = [];
    const promises = fcmTokens.map(async (token) => {
      try {
        await admin.messaging().send({
          token: token,
          ...payload,
        });
        validTokens.push(token);
        const shortToken = token.substring(0, 20);
        console.log(
            `Notification sent successfully to token: ${shortToken}...`,
        );
      } catch (error) {
        const shortToken = token.substring(0, 20);
        console.error(
            `Failed to send notification to token ${shortToken}...:`,
            error,
        );
        // Token might be invalid, we'll clean it up
        return token;
      }
    });

    const invalidTokens = (await Promise.all(promises)).filter(Boolean);

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      const remainingTokens = fcmTokens.filter(
          (token) => !invalidTokens.includes(token),
      );
      await userDoc.ref.update({
        fcmTokens: remainingTokens,
      });
      console.log(
          `Cleaned up ${invalidTokens.length} invalid tokens for ` +
          `user ${userId}`,
      );
    }

    console.log(
        `Push notification sent to user ${userId}: ${title}`,
    );
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
}

/**
 * Get user display name
 * @param {string} userId - The user ID
 * @return {string} The display name or 'Someone'
 */
async function getUserDisplayName(userId) {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      return "Someone";
    }

    const userData = userDoc.data();
    return userData.displayName || userData.name || "Someone";
  } catch (error) {
    console.error("Error getting user display name:", error);
    return "Someone";
  }
}

/**
 * Format date for notifications
 * @param {admin.firestore.Timestamp} timestamp - Firestore timestamp
 * @return {string} Formatted date string
 */
function formatDate(timestamp) {
  if (!timestamp) return "";

  const date = timestamp.toDate();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetDate = new Date(
      date.getFullYear(),
      date.getMonth(),
      date.getDate(),
  );

  if (targetDate.getTime() === today.getTime()) {
    const timeStr = date.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
    return `today at ${timeStr}`;
  } else {
    const dateStr = date.toLocaleDateString();
    const timeStr = date.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
    return `${dateStr} at ${timeStr}`;
  }
}

// === NOTIFICATION TRIGGERS ===

/**
 * Trigger when a workout is assigned to a client
 */
exports.onWorkoutAssigned = functions.firestore
    .document("assignedWorkouts/{workoutId}")
    .onCreate(async (snap, context) => {
      try {
        const workout = snap.data();
        const clientId = workout.clientId;
        const trainerId = workout.trainerId;

        // Get trainer name
        const trainerName = await getUserDisplayName(trainerId);

        // Send notification to client
        await sendPushNotification(
            clientId,
            "New Workout Assigned! 💪",
            `${trainerName} assigned you a new workout: ${workout.workoutName}`,
            {
              type: "workout_assigned",
              workoutId: context.params.workoutId,
              trainerId: trainerId,
            },
        );

        console.log(
            `Workout assignment notification sent to client ${clientId}`,
        );
      } catch (error) {
        console.error("Error in onWorkoutAssigned:", error);
      }
    });

/**
 * Trigger when a workout is completed by a client
 */
exports.onWorkoutCompleted = functions.firestore
    .document("assignedWorkouts/{workoutId}")
    .onUpdate(async (change, context) => {
      try {
        const before = change.before.data();
        const after = change.after.data();

        // Check if workout was just completed
        if (before.status !== "completed" && after.status === "completed") {
          const clientId = after.clientId;
          const trainerId = after.trainerId;

          // Get client name
          const clientName = await getUserDisplayName(clientId);

          // Send notification to trainer
          await sendPushNotification(
              trainerId,
              "Workout Completed! 🎉",
              `${clientName} just completed "${after.workoutName}"`,
              {
                type: "workout_completed",
                workoutId: context.params.workoutId,
                clientId: clientId,
              },
          );

          console.log(
              `Workout completion notification sent to trainer ${trainerId}`,
          );
        }
      } catch (error) {
        console.error("Error in onWorkoutCompleted:", error);
      }
    });

/**
 * Trigger when a training session is booked
 */
exports.onSessionBooked = functions.firestore
    .document("sessions/{sessionId}")
    .onCreate(async (snap, context) => {
      try {
        const session = snap.data();
        const clientId = session.clientId;
        const trainerId = session.trainerId;

        // Get names
        const clientName = await getUserDisplayName(clientId);
        const sessionTime = formatDate(session.startTime);

        // Send notification to trainer
        await sendPushNotification(
            trainerId,
            "New Session Booked! 📅",
            `${clientName} booked a session for ${sessionTime}`,
            {
              type: "session_booked",
              sessionId: context.params.sessionId,
              clientId: clientId,
            },
        );

        console.log(
            `Session booking notification sent to trainer ${trainerId}`,
        );
      } catch (error) {
        console.error("Error in onSessionBooked:", error);
      }
    });

/**
 * Trigger when a session is cancelled or updated
 */
exports.onSessionUpdated = functions.firestore
    .document("sessions/{sessionId}")
    .onUpdate(async (change, context) => {
      try {
        const before = change.before.data();
        const after = change.after.data();

        // Check if session was cancelled
        if (before.status !== "cancelled" && after.status === "cancelled") {
          const clientId = after.clientId;
          const trainerId = after.trainerId;

          // Get names
          const trainerName = await getUserDisplayName(trainerId);
          const clientName = await getUserDisplayName(clientId);
          const sessionTime = formatDate(after.startTime);

          // Determine who cancelled and send notification accordingly
          const lastModified = after.lastModifiedBy || after.trainerId;

          if (lastModified === trainerId) {
            // Trainer cancelled - notify client
            let message = `Your session with ${trainerName} for ` +
                         `${sessionTime} has been cancelled`;
            if (after.cancellationReason) {
              message += `. Reason: ${after.cancellationReason}`;
            }

            await sendPushNotification(
                clientId,
                "Session Cancelled",
                message,
                {
                  type: "session_cancelled",
                  sessionId: context.params.sessionId,
                  trainerId: trainerId,
                },
            );
          } else {
            // Client cancelled - notify trainer
            let message = `${clientName} cancelled their session for ` +
                         `${sessionTime}`;
            if (after.cancellationReason) {
              message += `. Reason: ${after.cancellationReason}`;
            }

            await sendPushNotification(
                trainerId,
                "Session Cancelled",
                message,
                {
                  type: "session_cancelled",
                  sessionId: context.params.sessionId,
                  clientId: clientId,
                },
            );
          }

          console.log(
              `Session cancellation notification sent for ` +
              `session ${context.params.sessionId}`,
          );
        }
      } catch (error) {
        console.error("Error in onSessionUpdated:", error);
      }
    });

/**
 * Trigger when a user account status is updated (approval/rejection)
 */
exports.onAccountStatusUpdated = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
      try {
        const before = change.before.data();
        const after = change.after.data();

        // Check if account status changed
        if (before.accountStatus !== after.accountStatus) {
          const userId = context.params.userId;

          if (after.accountStatus === "approved") {
            // Account approved
            const userName = after.displayName || after.name || "there";

            await sendPushNotification(
                userId,
                "Account Approved! 🎉",
                `Welcome to Merge Fitness, ${userName}! Your account has ` +
                `been approved and you can now access all features.`,
                {
                  type: "account_approved",
                  userId: userId,
                },
            );

            console.log(`Account approval notification sent to user ${userId}`);
          } else if (after.accountStatus === "rejected") {
            // Account rejected
            await sendPushNotification(
                userId,
                "Account Update",
                "Your account application was not approved. Please contact " +
                "support at bj@mergeintohealth.com if you believe this was " +
                "a mistake.",
                {
                  type: "account_rejected",
                  userId: userId,
                },
            );

            console.log(
                `Account rejection notification sent to user ${userId}`,
            );
          }
        }
      } catch (error) {
        console.error("Error in onAccountStatusUpdated:", error);
      }
    });

/**
 * Trigger when a nutrition plan is assigned
 */
exports.onNutritionPlanAssigned = functions.firestore
    .document("nutritionPlans/{planId}")
    .onCreate(async (snap, context) => {
      try {
        const plan = snap.data();
        const clientId = plan.clientId;
        const trainerId = plan.trainerId;

        // Get trainer name
        const trainerName = await getUserDisplayName(trainerId);

        // Send notification to client
        await sendPushNotification(
            clientId,
            "New Nutrition Plan! 🥗",
            `${trainerName} assigned you a new nutrition plan: ` +
            `${plan.name || "Custom Plan"}`,
            {
              type: "nutrition_plan_assigned",
              planId: context.params.planId,
              trainerId: trainerId,
            },
        );

        console.log(
            `Nutrition plan assignment notification sent to client ${clientId}`,
        );
      } catch (error) {
        console.error("Error in onNutritionPlanAssigned:", error);
      }
    });

/**
 * Trigger when a meal is logged (notify trainer)
 */
exports.onMealLogged = functions.firestore
    .document("mealEntries/{entryId}")
    .onCreate(async (snap, context) => {
      try {
        const entry = snap.data();
        const clientId = entry.clientId;
        const trainerId = entry.trainerId;

        if (!trainerId) return; // Skip if no trainer assigned

        // Get client name
        const clientName = await getUserDisplayName(clientId);

        // Send notification to trainer
        await sendPushNotification(
            trainerId,
            "New Meal Logged! 🍽️",
            `${clientName} logged a meal: ${entry.description || "Meal entry"}`,
            {
              type: "meal_logged",
              entryId: context.params.entryId,
              clientId: clientId,
            },
        );

        console.log(`Meal logging notification sent to trainer ${trainerId}`);
      } catch (error) {
        console.error("Error in onMealLogged:", error);
      }
    });

/**
 * Trigger when a client sends a message (if you have a messaging system)
 */
exports.onMessageSent = functions.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      try {
        const message = snap.data();
        const senderId = message.senderId;
        const conversationId = context.params.conversationId;

        // Get conversation to find the recipient
        const db = admin.firestore();
        const conversationDoc = await db.collection("conversations")
            .doc(conversationId).get();

        if (!conversationDoc.exists) return;

        const conversationData = conversationDoc.data();
        const participants = conversationData.participants || [];

        // Find the recipient (not the sender)
        const recipientId = participants.find((id) => id !== senderId);

        if (!recipientId) return;

        // Get sender name
        const senderName = await getUserDisplayName(senderId);

        // Send notification to recipient
        await sendPushNotification(
            recipientId,
            `New message from ${senderName}`,
            message.text || "Sent a message",
            {
              type: "message_received",
              conversationId: conversationId,
              senderId: senderId,
            },
        );

        console.log(`Message notification sent to user ${recipientId}`);
      } catch (error) {
        console.error("Error in onMessageSent:", error);
      }
    });

/**
 * Scheduled function to send session reminders
 */
exports.sendSessionReminders = functions.pubsub
    .schedule("every 15 minutes")
    .timeZone("America/New_York")
    .onRun(async (context) => {
      try {
        const db = admin.firestore();
        const now = new Date();

        // Find sessions starting in the next 15-30 minutes
        const reminderStart = new Date(now.getTime() + 15 * 60 * 1000);
        const reminderEnd = new Date(now.getTime() + 30 * 60 * 1000);

        const sessionsSnapshot = await db.collection("sessions")
            .where("startTime", ">=",
                admin.firestore.Timestamp.fromDate(reminderStart))
            .where("startTime", "<=",
                admin.firestore.Timestamp.fromDate(reminderEnd))
            .where("status", "==", "scheduled")
            .get();

        const promises = sessionsSnapshot.docs.map(async (doc) => {
          const session = doc.data();
          const clientId = session.clientId;
          const trainerId = session.trainerId;

          // Get names
          const trainerName = await getUserDisplayName(trainerId);
          const clientName = await getUserDisplayName(clientId);

          // Send reminder to client
          await sendPushNotification(
              clientId,
              "Session Reminder! ⏰",
              `Your session with ${trainerName} starts in 15 minutes`,
              {
                type: "session_reminder",
                sessionId: doc.id,
                trainerId: trainerId,
              },
          );

          // Send reminder to trainer
          await sendPushNotification(
              trainerId,
              "Session Reminder! ⏰",
              `Your session with ${clientName} starts in 15 minutes`,
              {
                type: "session_reminder",
                sessionId: doc.id,
                clientId: clientId,
              },
          );
        });

        await Promise.all(promises);

        console.log(`Sent ${sessionsSnapshot.size} session reminders`);
      } catch (error) {
        console.error("Error in sendSessionReminders:", error);
      }
    });

/**
 * Scheduled function to send daily workout reminders
 */
exports.sendWorkoutReminders = functions.pubsub
    .schedule("0 19 * * *") // 7 PM daily
    .timeZone("America/New_York")
    .onRun(async (context) => {
      try {
        const db = admin.firestore();
        const today = new Date();
        const startOfDay = new Date(
            today.getFullYear(),
            today.getMonth(),
            today.getDate(),
        );
        const endOfDay = new Date(
            today.getFullYear(),
            today.getMonth(),
            today.getDate(),
            23,
            59,
            59,
        );

        // Find incomplete workouts for today
        const workoutsSnapshot = await db.collection("assignedWorkouts")
            .where("scheduledDate", ">=",
                admin.firestore.Timestamp.fromDate(startOfDay))
            .where("scheduledDate", "<=",
                admin.firestore.Timestamp.fromDate(endOfDay))
            .where("status", "==", "assigned")
            .get();

        const promises = workoutsSnapshot.docs.map(async (doc) => {
          const workout = doc.data();
          const clientId = workout.clientId;

          // Send reminder to client
          await sendPushNotification(
              clientId,
              "Workout Reminder! 💪",
              `Don't forget to complete your workout: ${workout.workoutName}`,
              {
                type: "workout_reminder",
                workoutId: doc.id,
              },
          );
        });

        await Promise.all(promises);

        console.log(`Sent ${workoutsSnapshot.size} workout reminders`);
      } catch (error) {
        console.error("Error in sendWorkoutReminders:", error);
      }
    });

// === EXISTING STRIPE FUNCTIONS ===

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

        // Send notification to client about successful payment
        await sendPushNotification(
            clientId,
            "Payment Successful! 💳",
            "Your payment has been processed successfully. " +
            "10 sessions have been added to your account.",
            {
              type: "payment_success",
              amount: paymentIntent.amount / 100,
              sessions: 10,
            },
        );

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
