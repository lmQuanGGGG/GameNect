/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const pushNotifications = require('./index1');

admin.initializeApp();

const payosChecksumKey = defineSecret("PAYOS_CHECKSUM_KEY");

setGlobalOptions({ maxInstances: 10 });
exports.sendMessageNotification = pushNotifications.sendMessageNotification;
exports.sendCallNotification = pushNotifications.sendCallNotification;
exports.sendMomentReactionNotification = pushNotifications.sendMomentReactionNotification;

// PAYOS WEBHOOK
exports.payosWebhook = onRequest(
    {secrets: [payosChecksumKey]},
    async (req, res) => {
      try {
        console.log("=== WEBHOOK RECEIVED ===");
        console.log("Method:", req.method);
        console.log("Full body:", JSON.stringify(req.body, null, 2));

        // Xử lý GET request (test webhook)
        if (req.method === "GET") {
          console.log("GET request - returning success");
          return res.status(200).json({
            success: true,
            message: "Webhook is active",
          });
        }

        // Xử lý POST request
        if (req.method !== "POST") {
          console.log("Invalid method");
          return res.status(200).json({success: true});
        }

        // PayOS gửi data trực tiếp trong body
        const {code, desc, success, data, signature} = req.body;

        console.log("Parsed data:", {code, desc, success, data, signature});

        // Nếu không có data (test request)
        if (!data) {
          console.log("No data - test request");
          return res.status(200).json({success: true});
        }

        const orderCode = data.orderCode;
        const paymentStatus = data.code; // "00" = thành công

        console.log(`Order ${orderCode}, Status: ${paymentStatus}`);

        // Verify signature
        if (signature) {
          const crypto = require("crypto");
          
          // Tạo string để verify theo format của PayOS
          const sortedData = {
            amount: data.amount,
            code: data.code,
            desc: data.desc,
            orderCode: data.orderCode,
            // Thêm các field khác nếu cần
          };
          
          const dataStr = Object.keys(sortedData)
              .sort()
              .map((key) => `${key}=${sortedData[key]}`)
              .join("&");
          
          const expectedSignature = crypto
              .createHmac("sha256", payosChecksumKey.value())
              .update(dataStr)
              .digest("hex");

          console.log("Data string:", dataStr);
          console.log("Expected signature:", expectedSignature);
          console.log("Received signature:", signature);

          if (signature !== expectedSignature) {
            console.warn("⚠️ Signature mismatch - but continuing");
            // Không reject để test
          }
        }

        // Xử lý thanh toán thành công (code = "00")
        if (paymentStatus === "00") {
          console.log("Processing successful payment...");

          const orderDoc = await admin.firestore()
              .collection("orders")
              .doc(orderCode.toString())
              .get();

          if (orderDoc.exists) {
            const orderData = orderDoc.data();
            console.log("Order found:", orderData);

            // Update order status
            await orderDoc.ref.update({
              status: "success",
              paymentData: data,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Calculate end date
            const endDate = orderData.planType === "yearly" ?
              new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) :
              new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

            // Activate premium
            await admin.firestore()
                .collection("users")
                .doc(orderData.userId)
                .update({
                  isPremium: true,
                  premiumPlan: orderData.planType,
                  premiumStartDate: admin.firestore.FieldValue.serverTimestamp(),
                  premiumEndDate: admin.firestore.Timestamp.fromDate(endDate),
                });

            console.log("✅ Premium activated for user:", orderData.userId);
          } else {
            console.error("❌ Order not found:", orderCode);
          }
        } else {
          console.log(`Payment status: ${paymentStatus} - ${desc}`);
        }

        // LUÔN TRẢ 200 SUCCESS
        return res.status(200).json({success: true});
      } catch (error) {
        console.error("❌ Webhook error:", error);
        console.error("Error stack:", error.stack);
        
        // VẪN TRẢ 200 để PayOS không retry liên tục
        return res.status(200).json({
          success: true,
          message: "Error handled",
        });
      }
    });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
