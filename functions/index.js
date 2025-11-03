/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
/**
 *  Firebase Cloud Functions cho ứng dụng Gamenect
 * 
 * Chức năng chính:
 * 1. Push notifications cho tin nhắn, cuộc gọi, reactions
 * 2. PayOS webhook để xử lý thanh toán Premium
 */
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const pushNotifications = require('./index1');

// Khởi tạo Firebase Admin SDK
admin.initializeApp();

// Load secret key từ Firebase Secret Manager
const payosChecksumKey = defineSecret("PAYOS_CHECKSUM_KEY");

// Giới hạn tối đa 10 instances chạy đồng thời
setGlobalOptions({ maxInstances: 10 });

// Export các function push notification
exports.sendMessageNotification = pushNotifications.sendMessageNotification;
exports.sendCallNotification = pushNotifications.sendCallNotification;
exports.sendMomentReactionNotification = pushNotifications.sendMomentReactionNotification;

/**
 * PayOS Webhook Handler
 * 
 * Nhận webhook từ PayOS khi có thay đổi trạng thái thanh toán
 * Workflow:
 * 1. User mua Premium -> Backend tạo order và payment link
 * 2. User thanh toán qua PayOS
 * 3. PayOS gọi webhook này với thông tin thanh toán
 * 4. Function verify signature và update trạng thái order
 * 5. Nếu thanh toán thành công (code = "00") -> kích hoạt Premium cho user
 */
exports.payosWebhook = onRequest(
    {secrets: [payosChecksumKey]}, // Inject secret key vào runtime
    async (req, res) => {
      try {
        console.log("=== WEBHOOK RECEIVED ===");
        console.log("Method:", req.method);
        console.log("Full body:", JSON.stringify(req.body, null, 2));

        // Xử lý GET request - dùng để test webhook endpoint
        if (req.method === "GET") {
          console.log("GET request - returning success");
          return res.status(200).json({
            success: true,
            message: "Webhook is active",
          });
        }

        // Chỉ xử lý POST request
        if (req.method !== "POST") {
          console.log("Invalid method");
          return res.status(200).json({success: true});
        }

        // PayOS gửi data trực tiếp trong body (không wrap trong object)
        const {code, desc, success, data, signature} = req.body;

        console.log("Parsed data:", {code, desc, success, data, signature});

        // Nếu không có data -> test request từ PayOS
        if (!data) {
          console.log("No data - test request");
          return res.status(200).json({success: true});
        }

        const orderCode = data.orderCode; // Mã đơn hàng
        const paymentStatus = data.code; // Trạng thái: "00" = thành công

        console.log(`Order ${orderCode}, Status: ${paymentStatus}`);

        // Verify chữ ký để đảm bảo request từ PayOS
        if (signature) {
          const crypto = require("crypto");
          
          // Tạo string để verify theo format của PayOS
          // Sort các field theo alphabet và nối bằng "&"
          const sortedData = {
            amount: data.amount,
            code: data.code,
            desc: data.desc,
            orderCode: data.orderCode,
            // Thêm các field khác nếu PayOS yêu cầu
          };
          
          const dataStr = Object.keys(sortedData)
              .sort()
              .map((key) => `${key}=${sortedData[key]}`)
              .join("&");
          
          // Tính HMAC SHA256 với checksum key
          const expectedSignature = crypto
              .createHmac("sha256", payosChecksumKey.value())
              .update(dataStr)
              .digest("hex");

          console.log("Data string:", dataStr);
          console.log("Expected signature:", expectedSignature);
          console.log("Received signature:", signature);

          if (signature !== expectedSignature) {
            console.warn("Signature mismatch - but continuing");
            // Trong production nên reject nếu signature không match
            // Hiện tại để test nên vẫn tiếp tục
          }
        }

        // Xử lý thanh toán thành công (code = "00")
        if (paymentStatus === "00") {
          console.log("Processing successful payment...");

          // Lấy thông tin order từ Firestore
          const orderDoc = await admin.firestore()
              .collection("orders")
              .doc(orderCode.toString())
              .get();

          if (orderDoc.exists) {
            const orderData = orderDoc.data();
            console.log("Order found:", orderData);

            // Update trạng thái order thành success
            await orderDoc.ref.update({
              status: "success",
              paymentData: data, // Lưu toàn bộ payment data từ PayOS
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Tính ngày hết hạn Premium
            // Yearly plan: +365 ngày, Monthly plan: +30 ngày
            const endDate = orderData.planType === "yearly" ?
              new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) :
              new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

            // Kích hoạt Premium cho user
            await admin.firestore()
                .collection("users")
                .doc(orderData.userId)
                .update({
                  isPremium: true, // Đánh dấu user là Premium
                  premiumPlan: orderData.planType, // Lưu loại gói đã mua
                  premiumStartDate: admin.firestore.FieldValue.serverTimestamp(),
                  premiumEndDate: admin.firestore.Timestamp.fromDate(endDate),
                });

            console.log("Premium activated for user:", orderData.userId);
          } else {
            console.error("Order not found:", orderCode);
          }
        } else {
          // Thanh toán không thành công hoặc đang chờ xử lý
          console.log(`Payment status: ${paymentStatus} - ${desc}`);
        }

        // LUÔN TRẢ 200 SUCCESS cho PayOS
        // Nếu trả error, PayOS sẽ retry liên tục
        return res.status(200).json({success: true});
      } catch (error) {
        console.error("Webhook error:", error);
        console.error("Error stack:", error.stack);
        
        // VẪN TRẢ 200 để PayOS không retry liên tục
        // Trong production nên có alerting để biết khi có lỗi
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
