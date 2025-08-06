import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  // Replace with your actual Razorpay credentials
  static const String _razorpayKeyId = 'rzp_test_0Boj1vgEUw5VZW'; // Replace with your test/live key  rzp_test_0Boj1vgEUw5VZW
  static const String _razorpayKeySecret = 'cpC64lAXhleU8ScWmaJDBZbC'; // Replace with your test/live secret
  
  // Direct Razorpay API endpoints
  static const String _razorpayApiUrl = 'https://api.razorpay.com/v1';

  /// Create a payment order and redirect to Razorpay payment gateway
  static Future<void> initiatePayment({
    required String planId,
    required String planTitle,
    required double amount,
    required int duration,
    required String userUsageType,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create order data (no prefill field)
      final orderData = {
        'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
        'currency': 'INR',
        'receipt': 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'plan_id': planId,
          'plan_title': planTitle,
          'duration': duration,
          'usage_type': userUsageType,
          'user_id': user.uid,
          'user_name': userName,
          'user_email': userEmail,
          'user_phone': userPhone,
        },
      };

      // Create payment link directly with Razorpay
      final paymentUrl = await _createPaymentLink(orderData);
      print('Razorpay paymentUrl: $paymentUrl');

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception('Payment URL is empty!');
      }

      // Launch payment URL in browser with better error handling
      final uri = Uri.parse(paymentUrl);
      
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          // Save payment attempt to Firestore
          await _savePaymentAttempt(
            userId: user.uid,
            planId: planId,
            planTitle: planTitle,
            amount: amount,
            duration: duration,
            usageType: userUsageType,
            paymentUrl: paymentUrl,
          );
        } else {
          throw Exception('Failed to launch payment URL. Please try again.');
        }
      } else {
        // Try alternative launch methods
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          
          if (launched) {
            // Save payment attempt to Firestore
            await _savePaymentAttempt(
              userId: user.uid,
              planId: planId,
              planTitle: planTitle,
              amount: amount,
              duration: duration,
              usageType: userUsageType,
              paymentUrl: paymentUrl,
            );
          } else {
            throw Exception('Could not launch payment URL. Please check your browser settings.');
          }
        } catch (e) {
          // If all launch methods fail, return the URL for manual opening
          throw Exception('Payment URL launch failed: $e. Please try opening the URL manually: $paymentUrl');
        }
      }
    } catch (e) {
      // If the error contains a URL, preserve it for manual opening
      if (e.toString().contains('http')) {
        throw e; // Re-throw to preserve the URL in the error message
      } else {
        throw Exception('Payment initiation failed: $e');
      }
    }
  }

  /// Create payment link directly with Razorpay API
  static Future<String> _createPaymentLink(Map<String, dynamic> orderData) async {
    try {
      // Create payment link data as per Razorpay docs
      final paymentLinkData = {
        'amount': orderData['amount'],
        'currency': orderData['currency'],
        'description': 'Subscription for ${orderData['notes']['plan_title']}',
        'customer': {
          'name': orderData['notes']['user_name'],
          'email': orderData['notes']['user_email'],
          'contact': orderData['notes']['user_phone'],
        },
        'notify': {
          'email': true,
          'sms': true,
        },
        'callback_url': 'https://your-app.com/payment/callback', // Replace with your callback URL
        'callback_method': 'get',
        'reference_id': orderData['receipt'],
        'notes': orderData['notes'],
      };

      // Make API call to Razorpay
      final response = await http.post(
        Uri.parse('$_razorpayApiUrl/payment_links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
        body: jsonEncode(paymentLinkData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Razorpay payment link response: $responseData');
        
        // Check for the payment URL in different possible fields
        String? paymentUrl = responseData['short_url'] ?? 
                           responseData['payment_link'] ?? 
                           responseData['url'] ??
                           responseData['hosted_page_url'];
        
        if (paymentUrl == null || paymentUrl.isEmpty) {
          throw Exception('No payment URL received from Razorpay. Response: $responseData');
        }
        
        return paymentUrl;
      } else {
        print('Razorpay error: ${response.body}');
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['description'] ?? errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Payment link creation failed: $errorMessage');
      }
    } catch (e) {
      throw Exception('Direct Razorpay integration failed: $e');
    }
  }

  /// Save payment attempt to Firestore
  static Future<void> _savePaymentAttempt({
    required String userId,
    required String planId,
    required String planTitle,
    required double amount,
    required int duration,
    required String usageType,
    required String paymentUrl,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paymentAttempts')
          .add({
        'planId': planId,
        'planTitle': planTitle,
        'amount': amount,
        'duration': duration,
        'usageType': usageType,
        'paymentUrl': paymentUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving payment attempt: $e');
    }
  }

  /// Manual payment verification (for when user returns to app)
  static Future<bool> verifyPaymentManually({
    required String paymentId,
    required String orderId,
  }) async {
    try {
      // Get payment details from Razorpay
      final response = await http.get(
        Uri.parse('$_razorpayApiUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      if (response.statusCode == 200) {
        final paymentData = jsonDecode(response.body);
        final status = paymentData['status'];
        
        if (status == 'captured') {
          // Payment successful, update user subscription
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _updatePaymentStatus(
              userId: user.uid,
              paymentId: paymentId,
              status: 'success',
              paymentDetails: paymentData,
            );
          }
          return true;
        } else if (status == 'failed') {
          // Payment failed
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _updatePaymentStatus(
              userId: user.uid,
              paymentId: paymentId,
              status: 'failed',
              paymentDetails: paymentData,
            );
          }
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  /// Update payment status in Firestore
  static Future<void> _updatePaymentStatus({
    required String userId,
    required String paymentId,
    required String status,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final paymentAttempts = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paymentAttempts')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (paymentAttempts.docs.isNotEmpty) {
        final doc = paymentAttempts.docs.first;
        await doc.reference.update({
          'status': status,
          'paymentId': paymentId,
          'paymentDetails': paymentDetails,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If payment is successful, update user subscription
        if (status == 'success' && paymentDetails != null) {
          await _updateUserSubscription(userId, doc.data());
        }
      }
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  /// Update user subscription after successful payment
  static Future<void> _updateUserSubscription(String userId, Map<String, dynamic> paymentData) async {
    try {
      final now = DateTime.now();
      final duration = paymentData['duration'] as int;
      final expiryDate = now.add(Duration(days: duration));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'subscription': 'Premium',
        'subscriptionPlanId': paymentData['planId'],
        'subscriptionPlanTitle': paymentData['planTitle'],
        'subscriptionStartDate': now,
        'subscriptionEndDate': expiryDate,
        'subscriptionStatus': 'active',
        'lastPaymentDate': now,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add subscription history
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('subscriptionHistory')
          .add({
        'planId': paymentData['planId'],
        'planTitle': paymentData['planTitle'],
        'amount': paymentData['amount'],
        'duration': paymentData['duration'],
        'usageType': paymentData['usageType'],
        'startDate': now,
        'endDate': expiryDate,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user subscription: $e');
    }
  }

  /// Get user's current subscription status
  static Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'subscription': data['subscription'] ?? 'Free',
          'subscriptionPlanId': data['subscriptionPlanId'],
          'subscriptionPlanTitle': data['subscriptionPlanTitle'],
          'subscriptionStartDate': data['subscriptionStartDate'],
          'subscriptionEndDate': data['subscriptionEndDate'],
          'subscriptionStatus': data['subscriptionStatus'] ?? 'inactive',
        };
      }
      return null;
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;

      final status = subscription['subscriptionStatus'] as String?;
      final endDate = subscription['subscriptionEndDate'] as Timestamp?;

      if (status == 'active' && endDate != null) {
        final expiryDate = endDate.toDate();
        return DateTime.now().isBefore(expiryDate);
      }

      return false;
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }

  /// Get pending payment attempts for manual verification
  static Future<List<Map<String, dynamic>>> getPendingPayments(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paymentAttempts')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting pending payments: $e');
      return [];
    }
  }

  /// Manual payment verification method (call this when user returns to app)
  static Future<void> checkPendingPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pendingPayments = await getPendingPayments(user.uid);
      
      for (final payment in pendingPayments) {
        // You can implement a simple UI to ask user for payment ID
        // or use a different method to get payment details
        print('Pending payment found: ${payment['planTitle']}');
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }

  /// Debug method to test URL launching
  static Future<bool> testUrlLaunch(String url) async {
    try {
      final uri = Uri.parse(url);
      print('Testing URL launch for: $url');
      print('Can launch URL: ${await canLaunchUrl(uri)}');
      
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('URL launch result: $launched');
        return launched;
      }
      return false;
    } catch (e) {
      print('URL launch test failed: $e');
      return false;
    }
  }
} 