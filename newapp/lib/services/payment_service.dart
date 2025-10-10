import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  // Firebase Functions endpoints - Update this URL after deployment
  static const String _firebaseFunctionsUrl = 'https://us-central1-prime-status-1db09.cloudfunctions.net';

  /// Create a payment order and redirect to Razorpay payment gateway
  static Future<void> initiatePayment({
    required double amount,
    required String orderId,
  }) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare request parameters - only 3 parameters like server.js
      final requestData = {
        'amount': amount,
        'userId': user.uid,
        'orderId': orderId,
      };

      print('📤 [PAYMENT] Sending request to Firebase Function:');
      print('   URL: $_firebaseFunctionsUrl/initiatePayment');
      print('   Method: POST');
      print('   Headers: {"Content-Type": "application/json"}');
      print('   Body: ${jsonEncode(requestData)}');

      // Call Firebase Functions to create payment link
      final response = await http.post(
        Uri.parse('$_firebaseFunctionsUrl/initiatePayment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📥 [PAYMENT] Received response from Firebase Function:');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final paymentUrl = responseData['payment_url'];
          final paymentId = responseData['payment_id'];
          
          print('Payment URL: $paymentUrl');
          print('Payment ID: $paymentId');

          if (paymentUrl == null || paymentUrl.isEmpty) {
            throw Exception('Payment URL is empty!');
          }

          // Save payment attempt to Firestore with payment ID
          await _savePaymentAttempt(
            userId: user.uid,
            amount: amount,
            orderId: orderId,
            paymentUrl: paymentUrl,
            paymentId: paymentId,
          );

          // Launch payment URL in browser
          final uri = Uri.parse(paymentUrl);
          
          if (await canLaunchUrl(uri)) {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            
            if (launched) {
              // Start polling for payment status
              _startPaymentStatusPolling(paymentId, user.uid);
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
                // Start polling for payment status
                _startPaymentStatusPolling(paymentId, user.uid);
              } else {
                throw Exception('Could not launch payment URL. Please check your browser settings.');
              }
            } catch (e) {
              // If all launch methods fail, return the URL for manual opening
              throw Exception('Payment URL launch failed: $e. Please try opening the URL manually: $paymentUrl');
            }
          }
        } else {
          throw Exception('Payment initiation failed: ${responseData['error']}');
        }
      } else {
        throw Exception('Payment initiation failed: HTTP ${response.statusCode}');
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



  /// Save payment attempt to Firestore
  static Future<void> _savePaymentAttempt({
    required String userId,
    required double amount,
    required String orderId,
    required String paymentUrl,
    String? paymentId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paymentAttempts')
          .add({
        'amount': amount,
        'orderId': orderId,
        'paymentUrl': paymentUrl,
        'paymentId': paymentId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving payment attempt: $e');
    }
  }

  /// Start polling for payment status
  static void _startPaymentStatusPolling(String paymentId, String userId) {
    int attempts = 0;
    const maxAttempts = 120; // 20 minutes (120 * 10 seconds)
    const pollInterval = Duration(seconds: 10);
    
    Timer.periodic(pollInterval, (timer) async {
      attempts++;
      
      try {
        final requestData = {'paymentId': paymentId};
        
        print('📤 [PAYMENT] Checking payment status:');
        print('   URL: $_firebaseFunctionsUrl/checkPaymentStatus');
        print('   Method: POST');
        print('   Body: ${jsonEncode(requestData)}');

        final response = await http.post(
          Uri.parse('$_firebaseFunctionsUrl/checkPaymentStatus'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestData),
        );

        print('📥 [PAYMENT] Payment status response:');
        print('   Status Code: ${response.statusCode}');
        print('   Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            final status = responseData['status'];
            
            if (status == 'paid') {
              // Payment successful, update user subscription
              await _updateSubscriptionViaFirebase(userId, paymentId);
              _showPaymentSuccessNotification();
              timer.cancel();
            } else if (status == 'failed' || status == 'cancelled') {
              // Payment failed
              await _updatePaymentStatus(
                userId: userId,
                paymentId: paymentId,
                status: 'failed',
              );
              _showPaymentFailedNotification();
              timer.cancel();
            }
          }
        }
      } catch (e) {
        print('Error checking payment status: $e');
      }
      
      // Stop polling after max attempts
      if (attempts >= maxAttempts) {
        timer.cancel();
        print('Payment status polling stopped after $maxAttempts attempts');
        _showPaymentTimeoutNotification();
      }
    });
  }

  /// Show payment success notification
  static void _showPaymentSuccessNotification() {
    // This will be handled by the UI layer
    print('🎉 Payment successful! Subscription activated.');
  }

  /// Show payment failed notification
  static void _showPaymentFailedNotification() {
    print('❌ Payment failed or cancelled.');
  }

  /// Show payment timeout notification
  static void _showPaymentTimeoutNotification() {
    print('⏰ Payment verification timeout. Please check manually.');
  }

  /// Update subscription via Firebase Functions
  static Future<void> _updateSubscriptionViaFirebase(String userId, String paymentId) async {
    try {
      // Get payment attempt details
      final paymentAttempts = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paymentAttempts')
          .where('paymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (paymentAttempts.docs.isNotEmpty) {
        final paymentData = paymentAttempts.docs.first.data();
        
        // Update payment status to success
        await _updatePaymentStatus(
          userId: userId,
          paymentId: paymentId,
          status: 'success',
        );
        
        print('Payment confirmed and subscription updated successfully');
      }
    } catch (e) {
      print('Error updating subscription: $e');
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
      final amount = paymentData['amount'] as double;
      final orderId = paymentData['orderId'] as String;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'subscription': 'Premium',
        'subscriptionAmount': amount,
        'subscriptionOrderId': orderId,
        'subscriptionStartDate': now,
        'subscriptionEndDate': now.add(const Duration(days: 30)), // Default to 30 days
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
        'amount': amount,
        'orderId': orderId,
        'startDate': now,
        'endDate': now.add(const Duration(days: 30)),
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
          'subscriptionAmount': data['subscriptionAmount'],
          'subscriptionOrderId': data['subscriptionOrderId'],
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
      // First check user's usage type
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final usageType = userData['usageType'] ?? 'Personal';

        // Personal users always have free access
        if (usageType == 'Personal') {
          return true;
        }
      }

      // For Business users, check subscription
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

  /// Manual payment verification for when user returns to app
  static Future<bool> verifyPaymentManually(String paymentId) async {
    try {
      final requestData = {'paymentId': paymentId};
      
      print('📤 [PAYMENT] Manual payment verification:');
      print('   URL: $_firebaseFunctionsUrl/checkPaymentStatus');
      print('   Method: POST');
      print('   Body: ${jsonEncode(requestData)}');

      final response = await http.post(
        Uri.parse('$_firebaseFunctionsUrl/checkPaymentStatus'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📥 [PAYMENT] Manual verification response:');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final status = responseData['status'];
          
          if (status == 'paid') {
            // Payment successful, update user subscription
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await _updateSubscriptionViaFirebase(user.uid, paymentId);
            }
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error verifying payment manually: $e');
      return false;
    }
  }

  /// Manual payment verification method (call this when user returns to app)
  static Future<void> checkPendingPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pendingPayments = await getPendingPayments(user.uid);
      
      for (final payment in pendingPayments) {
        final paymentId = payment['paymentId'];
        if (paymentId != null) {
          print('Checking payment status for: ${payment['orderId']}');
          final isPaid = await verifyPaymentManually(paymentId);
          if (isPaid) {
            print('Payment confirmed for: ${payment['orderId']}');
          }
        }
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