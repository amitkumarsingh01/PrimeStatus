import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Added for webhook handling

class PaymentService {
  // Replace with your actual Razorpay credentials
  static const String _razorpayKeyId = 'rzp_live_9ssoAG3CKktfqO'; // Replace with your test/live key  rzp_test_0Boj1vgEUw5VZW
  static const String _razorpayKeySecret = 'P9Kqka188NLtSDO3aYVwhE6r'; // Replace with your test/live secret
  
  // Direct Razorpay API endpoints
  static const String _razorpayApiUrl = 'https://api.razorpay.com/v1';

  // Polling variables
  static Timer? _pollingTimer;
  static bool _isPolling = false;
  static String? _currentPaymentId;
  static String? _currentOrderId;
  static Function(bool)? _onPaymentStatusChanged;

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
    Function(bool)? onPaymentStatusChanged,
  }) async {
    print('🔄 [PAYMENT] Starting payment initiation...');
    print('📋 [PAYMENT] Plan Details:');
    print('   - Plan ID: $planId');
    print('   - Plan Title: $planTitle');
    print('   - Amount: ₹$amount');
    print('   - Duration: $duration days');
    print('   - Usage Type: $userUsageType');
    print('   - User: $userName ($userEmail)');
    
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [PAYMENT] User not authenticated');
        throw Exception('User not authenticated');
      }
      print('✅ [PAYMENT] User authenticated: ${user.uid}');

      // Store callback for payment status updates
      _onPaymentStatusChanged = onPaymentStatusChanged;
      print('📞 [PAYMENT] Payment status callback registered');

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
      print('📝 [PAYMENT] Order data created: ${jsonEncode(orderData)}');

      // Create payment link directly with Razorpay
      print('🌐 [PAYMENT] Creating payment link with Razorpay...');
      final paymentUrl = await _createPaymentLink(orderData);
      print('🔗 [PAYMENT] Razorpay payment URL: $paymentUrl');

      if (paymentUrl == null || paymentUrl.isEmpty) {
        print('❌ [PAYMENT] Payment URL is empty!');
        throw Exception('Payment URL is empty!');
      }

      // Store order details for webhook tracking
      print('💾 [PAYMENT] Storing order details for webhook tracking...');
      final orderId = orderData['receipt'] as String;
      
      // Store payment attempt in Firestore for tracking
      await _savePaymentAttempt(
        userId: user.uid,
        planId: planId,
        planTitle: planTitle,
        amount: amount,
        duration: duration,
        usageType: userUsageType,
        paymentUrl: paymentUrl,
      );
      
      print('✅ [PAYMENT] Payment link created with webhook callback');
      print('🔔 [PAYMENT] Webhook will handle payment verification automatically');

      // Launch payment URL in browser with better error handling
      print('🌐 [PAYMENT] Attempting to launch payment URL in browser...');
      final uri = Uri.parse(paymentUrl);
      
      if (await canLaunchUrl(uri)) {
        print('✅ [PAYMENT] URL can be launched');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          print('✅ [PAYMENT] Payment URL launched successfully');
          // Save payment attempt to Firestore
          print('💾 [PAYMENT] Saving payment attempt to Firestore...');
          await _savePaymentAttempt(
            userId: user.uid,
            planId: planId,
            planTitle: planTitle,
            amount: amount,
            duration: duration,
            usageType: userUsageType,
            paymentUrl: paymentUrl,
          );
          print('✅ [PAYMENT] Payment attempt saved to Firestore');
        } else {
          print('❌ [PAYMENT] Failed to launch payment URL');
          throw Exception('Failed to launch payment URL. Please try again.');
        }
      } else {
        print('⚠️ [PAYMENT] URL cannot be launched with external application, trying platform default...');
        // Try alternative launch methods
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          
          if (launched) {
            print('✅ [PAYMENT] Payment URL launched with platform default');
            // Save payment attempt to Firestore
            print('💾 [PAYMENT] Saving payment attempt to Firestore...');
            await _savePaymentAttempt(
              userId: user.uid,
              planId: planId,
              planTitle: planTitle,
              amount: amount,
              duration: duration,
              usageType: userUsageType,
              paymentUrl: paymentUrl,
            );
            print('✅ [PAYMENT] Payment attempt saved to Firestore');
          } else {
            print('❌ [PAYMENT] Could not launch payment URL with platform default');
            throw Exception('Could not launch payment URL. Please check your browser settings.');
          }
        } catch (e) {
          print('❌ [PAYMENT] All launch methods failed: $e');
          // If all launch methods fail, return the URL for manual opening
          throw Exception('Payment URL launch failed: $e. Please try opening the URL manually: $paymentUrl');
        }
      }
    } catch (e) {
      print('❌ [PAYMENT] Payment initiation failed: $e');
      // If the error contains a URL, preserve it for manual opening
      if (e.toString().contains('http')) {
        print('🔗 [PAYMENT] Error contains URL, preserving for manual opening');
        throw e; // Re-throw to preserve the URL in the error message
      } else {
        print('❌ [PAYMENT] Payment initiation failed with error: $e');
        throw Exception('Payment initiation failed: $e');
      }
    }
  }

  /// Start polling for payment status every 15 seconds for 15 minutes
  static void _startPaymentPolling() {
    if (_isPolling) {
      print('⚠️ [POLLING] Payment polling already in progress');
      return;
    }

    _isPolling = true;
    int pollCount = 0;
    const int maxPolls = 60; // 15 minutes / 15 seconds = 60 polls
    const int pollInterval = 15; // 15 seconds

    print('🚀 [POLLING] Starting payment polling for payment ID: $_currentPaymentId');
    print('⏱️ [POLLING] Polling interval: $pollInterval seconds');
    print('⏰ [POLLING] Maximum polls: $maxPolls (15 minutes total)');
    print('🔄 [POLLING] Polling will check every $pollInterval seconds for payment status');

    _pollingTimer = Timer.periodic(Duration(seconds: pollInterval), (timer) async {
      pollCount++;
      print('🔄 [POLLING] Poll attempt $pollCount/$maxPolls - ${DateTime.now().toString()}');

      if (_currentPaymentId == null) {
        print('❌ [POLLING] No payment ID available for polling');
        _stopPaymentPolling();
        return;
      }

      try {
        print('🔍 [POLLING] Checking payment status for ID: $_currentPaymentId');
        // Check payment status
        final isSuccessful = await verifyPaymentManually(
          paymentId: _currentPaymentId!,
          orderId: '', // Not needed for direct API check
        );

        if (isSuccessful) {
          print('🎉 [POLLING] Payment successful! Stopping polling.');
          _stopPaymentPolling();
          
          // Notify callback about successful payment
          if (_onPaymentStatusChanged != null) {
            print('📞 [POLLING] Notifying callback about successful payment');
            _onPaymentStatusChanged!(true);
          }
          
          // Update user subscription in Firebase
          print('🔥 [POLLING] Updating user subscription in Firebase...');
          await _updateUserSubscriptionFromPayment(_currentPaymentId!);
          
        } else {
          print('⏳ [POLLING] Payment not yet successful, continuing...');
          if (pollCount >= maxPolls) {
            print('⏰ [POLLING] Payment polling timeout after 15 minutes');
            _stopPaymentPolling();
            
            // Notify callback about timeout
            if (_onPaymentStatusChanged != null) {
              print('📞 [POLLING] Notifying callback about timeout');
              _onPaymentStatusChanged!(false);
            }
          }
        }
      } catch (e) {
        print('❌ [POLLING] Error during payment polling: $e');
        
        if (pollCount >= maxPolls) {
          print('⏰ [POLLING] Payment polling timeout after 15 minutes due to errors');
          _stopPaymentPolling();
          
          // Notify callback about timeout
          if (_onPaymentStatusChanged != null) {
            print('📞 [POLLING] Notifying callback about timeout due to errors');
            _onPaymentStatusChanged!(false);
          }
        }
      }
    });
  }

  /// Start polling for payment status using order ID
  static void _startPaymentPollingWithOrderId(String orderId) {
    if (_isPolling) {
      print('⚠️ [POLLING] Payment polling already in progress');
      return;
    }

    _isPolling = true;
    int pollCount = 0;
    const int maxPolls = 60; // 15 minutes / 15 seconds = 60 polls
    const int pollInterval = 15; // 15 seconds

    print('🚀 [POLLING] Starting payment polling using order ID: $orderId');
    print('⏱️ [POLLING] Polling interval: $pollInterval seconds');
    print('⏰ [POLLING] Maximum polls: $maxPolls (15 minutes total)');
    print('🔄 [POLLING] Polling will check every $pollInterval seconds for payment status');

    _pollingTimer = Timer.periodic(Duration(seconds: pollInterval), (timer) async {
      pollCount++;
      print('🔄 [POLLING] Poll attempt $pollCount/$maxPolls - ${DateTime.now().toString()}');

      try {
        print('🔍 [POLLING] Checking payment status for order ID: $orderId');
        // Check payment status using order ID
        final isSuccessful = await verifyPaymentByOrderId(orderId);

        if (isSuccessful) {
          print('🎉 [POLLING] Payment successful! Stopping polling.');
          _stopPaymentPolling();
          
          // Notify callback about successful payment
          if (_onPaymentStatusChanged != null) {
            print('📞 [POLLING] Notifying callback about successful payment');
            _onPaymentStatusChanged!(true);
          }
          
          // Update user subscription in Firebase using order ID
          print('🔥 [POLLING] Updating user subscription in Firebase...');
          await _updateUserSubscriptionFromOrderId(orderId);
          
        } else {
          print('⏳ [POLLING] Payment not yet successful, continuing...');
          if (pollCount >= maxPolls) {
            print('⏰ [POLLING] Payment polling timeout after 15 minutes');
            _stopPaymentPolling();
            
            // Notify callback about timeout
            if (_onPaymentStatusChanged != null) {
              print('📞 [POLLING] Notifying callback about timeout');
              _onPaymentStatusChanged!(false);
            }
          }
        }
      } catch (e) {
        print('❌ [POLLING] Error during payment polling: $e');
        
        if (pollCount >= maxPolls) {
          print('⏰ [POLLING] Payment polling timeout after 15 minutes due to errors');
          _stopPaymentPolling();
          
          // Notify callback about timeout
          if (_onPaymentStatusChanged != null) {
            print('📞 [POLLING] Notifying callback about timeout due to errors');
            _onPaymentStatusChanged!(false);
          }
        }
      }
    });
  }

  /// Stop payment polling
  static void _stopPaymentPolling() {
    print('🛑 [POLLING] Stopping payment polling...');
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      print('✅ [POLLING] Timer cancelled');
    }
    _isPolling = false;
    _currentPaymentId = null;
    _currentOrderId = null;
    _onPaymentStatusChanged = null;
    print('✅ [POLLING] Payment polling stopped');
  }

  /// Manually stop payment polling (public method)
  static void stopPaymentPolling() {
    print('🛑 [POLLING] Manual stop requested');
    _stopPaymentPolling();
  }

  /// Check if payment polling is active
  static bool isPollingActive() {
    print('🔍 [POLLING] Polling status check: $_isPolling');
    return _isPolling;
  }

  /// Store payment URL for manual verification when payment ID extraction fails
  static Future<void> _storePaymentUrlForManualVerification(String paymentUrl, Map<String, dynamic> orderData) async {
    print('💾 [MANUAL] Storing payment URL for manual verification...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pendingPayments')
            .add({
          'paymentUrl': paymentUrl,
          'orderData': orderData,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending_manual_verification',
        });
        print('✅ [MANUAL] Payment URL stored for manual verification');
      }
    } catch (e) {
      print('❌ [MANUAL] Error storing payment URL: $e');
    }
  }

  /// Update user subscription from successful payment
  static Future<void> _updateUserSubscriptionFromPayment(String paymentId) async {
    print('🔥 [SUBSCRIPTION] Starting subscription update for payment: $paymentId');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [SUBSCRIPTION] No authenticated user found for subscription update');
        return;
      }
      print('✅ [SUBSCRIPTION] User authenticated: ${user.uid}');

      // Get payment details from Razorpay
      print('🔍 [SUBSCRIPTION] Fetching payment details from Razorpay...');
      final response = await http.get(
        Uri.parse('$_razorpayApiUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      if (response.statusCode == 200) {
        print('✅ [SUBSCRIPTION] Payment details fetched successfully');
        final paymentData = jsonDecode(response.body);
        final notes = paymentData['notes'] ?? {};
        
        // Extract plan details from payment notes
        final planId = notes['plan_id'] ?? '';
        final planTitle = notes['plan_title'] ?? '';
        final duration = int.tryParse(notes['duration']?.toString() ?? '30') ?? 30;
        final usageType = notes['usage_type'] ?? 'Personal';
        final amount = (paymentData['amount'] ?? 0) / 100.0; // Convert from paise to rupees

        print('📋 [SUBSCRIPTION] Plan details extracted:');
        print('   - Plan ID: $planId');
        print('   - Plan Title: $planTitle');
        print('   - Duration: $duration days');
        print('   - Usage Type: $usageType');
        print('   - Amount: ₹$amount');

        // Update user subscription
        final now = DateTime.now();
        final expiryDate = now.add(Duration(days: duration));
        print('📅 [SUBSCRIPTION] Subscription period: ${now.toString()} to ${expiryDate.toString()}');

        print('💾 [SUBSCRIPTION] Updating user document in Firestore...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'subscription': 'Premium',
          'subscriptionPlanId': planId,
          'subscriptionPlanTitle': planTitle,
          'subscriptionStartDate': now,
          'subscriptionEndDate': expiryDate,
          'subscriptionStatus': 'active',
          'lastPaymentDate': now,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ [SUBSCRIPTION] User document updated successfully');

        // Add subscription history
        print('📚 [SUBSCRIPTION] Adding subscription history...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subscriptionHistory')
            .add({
          'planId': planId,
          'planTitle': planTitle,
          'amount': amount,
          'duration': duration,
          'usageType': usageType,
          'startDate': now,
          'endDate': expiryDate,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ [SUBSCRIPTION] Subscription history added successfully');

        print('🎉 [SUBSCRIPTION] User subscription updated successfully for payment: $paymentId');
      } else {
        print('❌ [SUBSCRIPTION] Failed to get payment details. Status: ${response.statusCode}');
        print('❌ [SUBSCRIPTION] Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ [SUBSCRIPTION] Error updating user subscription from payment: $e');
    }
  }

  /// Update user subscription from order ID
  static Future<void> _updateUserSubscriptionFromOrderId(String orderId) async {
    print('🔥 [SUBSCRIPTION] Starting subscription update for order: $orderId');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [SUBSCRIPTION] No authenticated user found for subscription update');
        return;
      }
      print('✅ [SUBSCRIPTION] User authenticated: ${user.uid}');

      // Get order details from Razorpay
      print('🔍 [SUBSCRIPTION] Fetching order details from Razorpay...');
      final response = await http.get(
        Uri.parse('$_razorpayApiUrl/orders/$orderId/payments'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      if (response.statusCode == 200) {
        print('✅ [SUBSCRIPTION] Order details fetched successfully');
        final orderData = jsonDecode(response.body);
        final payments = orderData['items'] as List?;
        
        if (payments != null && payments.isNotEmpty) {
          final latestPayment = payments.first;
          final paymentId = latestPayment['id'];
          final notes = latestPayment['notes'] ?? {};
          
          // Extract plan details from payment notes
          final planId = notes['plan_id'] ?? '';
          final planTitle = notes['plan_title'] ?? '';
          final duration = int.tryParse(notes['duration']?.toString() ?? '30') ?? 30;
          final usageType = notes['usage_type'] ?? 'Personal';
          final amount = (latestPayment['amount'] ?? 0) / 100.0; // Convert from paise to rupees

          print('📋 [SUBSCRIPTION] Plan details extracted:');
          print('   - Plan ID: $planId');
          print('   - Plan Title: $planTitle');
          print('   - Duration: $duration days');
          print('   - Usage Type: $usageType');
          print('   - Amount: ₹$amount');

          // Update user subscription
          final now = DateTime.now();
          final expiryDate = now.add(Duration(days: duration));
          print('📅 [SUBSCRIPTION] Subscription period: ${now.toString()} to ${expiryDate.toString()}');

          print('💾 [SUBSCRIPTION] Updating user document in Firestore...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'subscription': 'Premium',
            'subscriptionPlanId': planId,
            'subscriptionPlanTitle': planTitle,
            'subscriptionStartDate': now,
            'subscriptionEndDate': expiryDate,
            'subscriptionStatus': 'active',
            'lastPaymentDate': now,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ [SUBSCRIPTION] User document updated successfully');

          // Add subscription history
          print('📚 [SUBSCRIPTION] Adding subscription history...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('subscriptionHistory')
              .add({
            'planId': planId,
            'planTitle': planTitle,
            'amount': amount,
            'duration': duration,
            'usageType': usageType,
            'startDate': now,
            'endDate': expiryDate,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('✅ [SUBSCRIPTION] Subscription history added successfully');

          print('🎉 [SUBSCRIPTION] User subscription updated successfully for order: $orderId');
        } else {
          print('❌ [SUBSCRIPTION] No payments found for order: $orderId');
        }
      } else {
        print('❌ [SUBSCRIPTION] Failed to get order details. Status: ${response.statusCode}');
        print('❌ [SUBSCRIPTION] Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ [SUBSCRIPTION] Error updating user subscription from order: $e');
    }
  }

  /// Create order and payment link with Razorpay API
  static Future<String> _createPaymentLink(Map<String, dynamic> orderData) async {
    try {
      // First create an order
      print('📋 [RAZORPAY] Creating order...');
      final orderResponse = await http.post(
        Uri.parse('$_razorpayApiUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
        body: jsonEncode({
          'amount': orderData['amount'],
          'currency': orderData['currency'],
          'receipt': orderData['receipt'],
          'notes': orderData['notes'],
        }),
      );

      if (orderResponse.statusCode != 200) {
        print('❌ [RAZORPAY] Order creation failed: ${orderResponse.body}');
        throw Exception('Order creation failed');
      }

      final orderResponseData = jsonDecode(orderResponse.body);
      final orderId = orderResponseData['id'];
      print('✅ [RAZORPAY] Order created with ID: $orderId');

      // Store order ID for webhook tracking
      _currentOrderId = orderId;
      print('💾 [RAZORPAY] Stored order ID for webhook tracking: $orderId');

      // Create payment link with order ID and proper webhook data
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
        'callback_url': 'https://us-central1-prime-status-1db09.cloudfunctions.net/razorpayWebhook',
        'reference_id': orderId, // Use order ID as reference
        'notes': orderData['notes'], // This contains user_id and plan details
        'options': {
          'checkout': {
            'name': 'Prime Status',
            'description': 'Subscription Payment',
            'prefill': {
              'name': orderData['notes']['user_name'],
              'email': orderData['notes']['user_email'],
              'contact': orderData['notes']['user_phone'],
            },
            'theme': {
              'color': '#3399cc'
            }
          }
        }
      };

      print('📋 [RAZORPAY] Payment link data with webhook info:');
      print('   - Order ID: $orderId');
      print('   - User ID: ${orderData['notes']['user_id']}');
      print('   - Plan: ${orderData['notes']['plan_title']}');
      print('   - Callback URL: ${paymentLinkData['callback_url']}');

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
        print('✅ [RAZORPAY] Payment link created successfully');
        print('📋 [RAZORPAY] Payment link response: $responseData');
        
        // Check for the payment URL in different possible fields
        String? paymentUrl = responseData['short_url'] ?? 
                           responseData['payment_link'] ?? 
                           responseData['url'] ??
                           responseData['hosted_page_url'];
        
        if (paymentUrl == null || paymentUrl.isEmpty) {
          throw Exception('No payment URL received from Razorpay. Response: $responseData');
        }
        
        print('🔗 [RAZORPAY] Payment URL generated: $paymentUrl');
        return paymentUrl;
      } else {
        print('❌ [RAZORPAY] Payment link creation failed');
        print('❌ [RAZORPAY] Status code: ${response.statusCode}');
        print('❌ [RAZORPAY] Response body: ${response.body}');
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['description'] ?? errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Payment link creation failed: $errorMessage');
      }
    } catch (e) {
      print('❌ [RAZORPAY] Error in payment link creation: $e');
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
    print('💾 [FIRESTORE] Saving payment attempt to Firestore...');
    print('📋 [FIRESTORE] Payment attempt details:');
    print('   - User ID: $userId');
    print('   - Plan ID: $planId');
    print('   - Plan Title: $planTitle');
    print('   - Amount: ₹$amount');
    print('   - Duration: $duration days');
    print('   - Usage Type: $usageType');
    print('   - Payment URL: $paymentUrl');
    
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
      print('✅ [FIRESTORE] Payment attempt saved successfully');
    } catch (e) {
      print('❌ [FIRESTORE] Error saving payment attempt: $e');
    }
  }

  /// Manual payment verification (for when user returns to app)
  static Future<bool> verifyPaymentManually({
    required String paymentId,
    required String orderId,
  }) async {
    print('🔍 [VERIFY] Verifying payment: $paymentId');
    try {
      // Get payment details from Razorpay
      print('🌐 [VERIFY] Fetching payment details from Razorpay API...');
      final response = await http.get(
        Uri.parse('$_razorpayApiUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      print('📊 [VERIFY] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final paymentData = jsonDecode(response.body);
        final status = paymentData['status'];
        print('📋 [VERIFY] Payment status: $status');
        print('📋 [VERIFY] Payment data: ${jsonEncode(paymentData)}');
        
        // Check multiple success statuses
        final successStatuses = ['captured', 'authorized', 'completed'];
        final failureStatuses = ['failed', 'cancelled', 'expired'];
        
        if (successStatuses.contains(status)) {
          print('✅ [VERIFY] Payment successful (status: $status)');
          // Payment successful, update user subscription
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            print('👤 [VERIFY] Updating payment status for user: ${user.uid}');
            await _updatePaymentStatus(
              userId: user.uid,
              paymentId: paymentId,
              status: 'success',
              paymentDetails: paymentData,
            );
          }
          return true;
        } else if (failureStatuses.contains(status)) {
          print('❌ [VERIFY] Payment failed (status: $status)');
          // Payment failed
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            print('👤 [VERIFY] Updating payment status for user: ${user.uid}');
            await _updatePaymentStatus(
              userId: user.uid,
              paymentId: paymentId,
              status: 'failed',
              paymentDetails: paymentData,
            );
          }
          return false;
        } else {
          print('⏳ [VERIFY] Payment status: $status (not yet captured)');
          return false;
        }
      } else {
        print('❌ [VERIFY] Failed to fetch payment details. Status: ${response.statusCode}');
        print('❌ [VERIFY] Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [VERIFY] Error verifying payment: $e');
      return false;
    }
  }

  /// Alternative verification method using order ID
  static Future<bool> verifyPaymentByOrderId(String orderId) async {
    print('🔍 [VERIFY] Verifying payment by order ID: $orderId');
    try {
      // Get order details from Razorpay
      print('🌐 [VERIFY] Fetching order details from Razorpay API...');
      final response = await http.get(
        Uri.parse('$_razorpayApiUrl/orders/$orderId/payments'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      print('📊 [VERIFY] Order response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final orderData = jsonDecode(response.body);
        final payments = orderData['items'] as List?;
        
        if (payments != null && payments.isNotEmpty) {
          final latestPayment = payments.first;
          final status = latestPayment['status'];
          final paymentId = latestPayment['id'];
          
          print('📋 [VERIFY] Latest payment status: $status');
          print('📋 [VERIFY] Payment ID: $paymentId');
          
          if (status == 'captured') {
            print('✅ [VERIFY] Payment successful via order verification');
            return true;
          }
        }
      }
      
      print('⏳ [VERIFY] Payment not yet captured via order verification');
      return false;
    } catch (e) {
      print('❌ [VERIFY] Error verifying payment by order ID: $e');
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
    print('🔍 [PENDING] Checking for pending payments...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [PENDING] No authenticated user');
        return;
      }

      final pendingPayments = await getPendingPayments(user.uid);
      print('📋 [PENDING] Found ${pendingPayments.length} pending payments');
      
      for (final payment in pendingPayments) {
        print('📋 [PENDING] Payment: ${payment['planTitle']} - ${payment['status']}');
        
        // Try to verify payment if it's still pending
        if (payment['status'] == 'pending') {
          print('🔄 [PENDING] Attempting to verify pending payment...');
          
          // You can implement a simple UI to ask user for payment ID
          // or use a different method to get payment details
          print('💡 [PENDING] Consider implementing manual verification UI for payment: ${payment['planTitle']}');
        }
      }
    } catch (e) {
      print('❌ [PENDING] Error checking pending payments: $e');
    }
  }

  /// Check for pending payments when app resumes
  static Future<void> checkPaymentsOnAppResume() async {
    print('🔄 [RESUME] App resumed - checking payment status...');
    
    // If polling is active, let it continue
    if (_isPolling) {
      print('⏳ [RESUME] Payment polling is already active, continuing...');
      return;
    }
    
    // Check for any pending payments
    await checkPendingPayments();
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

  /// Webhook-based payment verification (works even when app is disconnected)
  static Future<void> handlePaymentWebhook(Map<String, dynamic> webhookData) async {
    print('🔔 [WEBHOOK] Received payment webhook: ${jsonEncode(webhookData)}');
    
    try {
      final event = webhookData['event'] as String?;
      final payload = webhookData['payload'] as Map<String, dynamic>?;
      
      if (event == null || payload == null) {
        print('❌ [WEBHOOK] Invalid webhook data structure');
        return;
      }
      
      print('📋 [WEBHOOK] Event: $event');
      
      if (event == 'payment.captured') {
        await _handlePaymentCaptured(payload);
      } else if (event == 'payment.failed') {
        await _handlePaymentFailed(payload);
      } else {
        print('ℹ️ [WEBHOOK] Unhandled event: $event');
      }
    } catch (e) {
      print('❌ [WEBHOOK] Error handling webhook: $e');
    }
  }

  /// Handle successful payment webhook
  static Future<void> _handlePaymentCaptured(Map<String, dynamic> payload) async {
    print('✅ [WEBHOOK] Payment captured event received');
    
    try {
      final payment = payload['payment'] as Map<String, dynamic>?;
      final entity = payload['entity'] as Map<String, dynamic>?;
      
      if (payment == null && entity == null) {
        print('❌ [WEBHOOK] No payment data in webhook');
        return;
      }
      
      final paymentData = payment ?? entity!;
      final paymentId = paymentData['id'] as String?;
      final orderId = paymentData['order_id'] as String?;
      final status = paymentData['status'] as String?;
      final notes = paymentData['notes'] as Map<String, dynamic>?;
      
      print('📋 [WEBHOOK] Payment details:');
      print('   - Payment ID: $paymentId');
      print('   - Order ID: $orderId');
      print('   - Status: $status');
      
      if (status == 'captured' && notes != null) {
        // Extract user and plan details from notes
        final userId = notes['user_id'] as String?;
        final planId = notes['plan_id'] as String?;
        final planTitle = notes['plan_title'] as String?;
        final duration = int.tryParse(notes['duration']?.toString() ?? '30') ?? 30;
        final usageType = notes['usage_type'] as String? ?? 'Personal';
        final amount = (paymentData['amount'] ?? 0) / 100.0;
        
        if (userId != null && planId != null) {
          print('👤 [WEBHOOK] Updating subscription for user: $userId');
          await _updateUserSubscriptionFromWebhook(
            userId: userId,
            planId: planId,
            planTitle: planTitle ?? 'Premium Plan',
            duration: duration,
            usageType: usageType,
            amount: amount,
            paymentId: paymentId,
            orderId: orderId,
          );
          
          // Send notification to user
          await _sendPaymentSuccessNotification(userId, planTitle ?? 'Premium Plan');
        } else {
          print('❌ [WEBHOOK] Missing user or plan details in notes');
        }
      }
    } catch (e) {
      print('❌ [WEBHOOK] Error handling payment captured: $e');
    }
  }

  /// Handle failed payment webhook
  static Future<void> _handlePaymentFailed(Map<String, dynamic> payload) async {
    print('❌ [WEBHOOK] Payment failed event received');
    
    try {
      final payment = payload['payment'] as Map<String, dynamic>?;
      final entity = payload['entity'] as Map<String, dynamic>?;
      
      if (payment == null && entity == null) {
        print('❌ [WEBHOOK] No payment data in webhook');
        return;
      }
      
      final paymentData = payment ?? entity!;
      final notes = paymentData['notes'] as Map<String, dynamic>?;
      final userId = notes?['user_id'] as String?;
      
      if (userId != null) {
        print('👤 [WEBHOOK] Payment failed for user: $userId');
        await _sendPaymentFailedNotification(userId);
      }
    } catch (e) {
      print('❌ [WEBHOOK] Error handling payment failed: $e');
    }
  }

  /// Update user subscription from webhook data
  static Future<void> _updateUserSubscriptionFromWebhook({
    required String userId,
    required String planId,
    required String planTitle,
    required int duration,
    required String usageType,
    required double amount,
    String? paymentId,
    String? orderId,
  }) async {
    print('🔥 [WEBHOOK] Updating user subscription from webhook');
    print('📋 [WEBHOOK] Subscription details:');
    print('   - User ID: $userId');
    print('   - Plan ID: $planId');
    print('   - Plan Title: $planTitle');
    print('   - Duration: $duration days');
    print('   - Amount: ₹$amount');
    
    try {
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: duration));
      
      // Update user subscription
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'subscription': 'Premium',
        'subscriptionPlanId': planId,
        'subscriptionPlanTitle': planTitle,
        'subscriptionStartDate': now,
        'subscriptionEndDate': expiryDate,
        'subscriptionStatus': 'active',
        'lastPaymentDate': now,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [WEBHOOK] User subscription updated successfully');

      // Add subscription history
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('subscriptionHistory')
          .add({
        'planId': planId,
        'planTitle': planTitle,
        'amount': amount,
        'duration': duration,
        'usageType': usageType,
        'startDate': now,
        'endDate': expiryDate,
        'status': 'active',
        'paymentId': paymentId,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ [WEBHOOK] Subscription history added successfully');

      // Update payment attempt status
      await _updatePaymentAttemptStatus(userId, 'success', paymentId, orderId);
      
      print('🎉 [WEBHOOK] User subscription updated successfully via webhook');
    } catch (e) {
      print('❌ [WEBHOOK] Error updating user subscription: $e');
    }
  }

  /// Update payment attempt status in Firestore
  static Future<void> _updatePaymentAttemptStatus(
    String userId, 
    String status, 
    String? paymentId, 
    String? orderId
  ) async {
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
          'orderId': orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ [WEBHOOK] Payment attempt status updated to: $status');
      }
    } catch (e) {
      print('❌ [WEBHOOK] Error updating payment attempt status: $e');
    }
  }

  /// Send payment success notification
  static Future<void> _sendPaymentSuccessNotification(String userId, String planTitle) async {
    try {
      // Send FCM notification
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('sendPaymentSuccessNotification').call({
        'userId': userId,
        'title': 'Payment Successful! 🎉',
        'body': 'Your $planTitle subscription has been activated successfully.',
        'data': {
          'type': 'payment_success',
          'planTitle': planTitle,
        }
      });
      print('✅ [WEBHOOK] Payment success notification sent');
    } catch (e) {
      print('❌ [WEBHOOK] Error sending payment success notification: $e');
    }
  }

  /// Send payment failed notification
  static Future<void> _sendPaymentFailedNotification(String userId) async {
    try {
      // Send FCM notification
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('sendPaymentFailedNotification').call({
        'userId': userId,
        'title': 'Payment Failed',
        'body': 'Your payment was unsuccessful. Please try again.',
        'data': {
          'type': 'payment_failed',
        }
      });
      print('✅ [WEBHOOK] Payment failed notification sent');
    } catch (e) {
      print('❌ [WEBHOOK] Error sending payment failed notification: $e');
    }
  }
} 