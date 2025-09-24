import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionPlan {
  final String id;
  final String title;
  final String subtitle;
  final double price;
  final int duration;
  final String usageType;
  final bool isActive;
  final DateTime createdAt;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.duration,
    required this.usageType,
    required this.isActive,
    required this.createdAt,
  });

  factory SubscriptionPlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SubscriptionPlan(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      duration: data['duration'] ?? 30,
      usageType: data['usageType'] ?? 'Personal',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SubscriptionPlansScreen extends StatefulWidget {
  final String userUsageType;
  final String userName;
  final String userEmail;
  final String userPhone;
  
  const SubscriptionPlansScreen({
    Key? key,
    required this.userUsageType,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  }) : super(key: key);

  @override
  _SubscriptionPlansScreenState createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> with WidgetsBindingObserver {
  String get selectedUsageType => widget.userUsageType;
  bool _isProcessingPayment = false;
  
  // Firebase Functions base URL
  static const String _firebaseFunctionsUrl = 'https://us-central1-prime-status-1db09.cloudfunctions.net';
  
  // Payment status polling
  Timer? _paymentPollingTimer;
  int _pollingAttempts = 0;
  static const int maxPollingAttempts = 120; // 20 minutes (120 * 10 seconds)
  static const Duration pollingInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for pending payments when screen loads
    _checkPendingPayments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentPollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayments();
    }
  }

  Future<void> _checkPendingPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check for pending payments in Firestore
        final pendingPayments = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('paymentAttempts')
            .where('status', isEqualTo: 'pending')
            .get();

        for (final payment in pendingPayments.docs) {
          final paymentData = payment.data();
          final paymentId = paymentData['paymentId'];
          if (paymentId != null) {
            final isPaid = await _checkPaymentStatus(paymentId);
            if (isPaid) {
              // _showPaymentSuccessMessage();
            }
          }
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }

  // Start payment status polling
  void _startPaymentPolling(String paymentId) {
    print('🔄 [PAYMENT POLLING] Starting payment status polling for payment ID: $paymentId');
    _pollingAttempts = 0;
    _paymentPollingTimer?.cancel();
    
    _paymentPollingTimer = Timer.periodic(pollingInterval, (timer) async {
      _pollingAttempts++;
      print('🔄 [PAYMENT POLLING] Attempt $_pollingAttempts/$maxPollingAttempts - Checking payment status...');
      
        try {
          // Frontend-only: still check by posting from app (same endpoint)
          final isPaid = await _checkPaymentStatus(paymentId);
        if (isPaid) {
          print('✅ [PAYMENT POLLING] Payment confirmed! Stopping polling.');
          _stopPaymentPolling();
          _showPaymentSuccessMessage();
          return;
        }
        
        if (_pollingAttempts >= maxPollingAttempts) {
          print('⏰ [PAYMENT POLLING] Max polling attempts reached. Stopping polling.');
          _stopPaymentPolling();
          _showPaymentTimeoutMessage();
          return;
        }
      } catch (e) {
        print('❌ [PAYMENT POLLING] Error checking payment status: $e');
        if (_pollingAttempts >= maxPollingAttempts) {
          _stopPaymentPolling();
          _showPaymentTimeoutMessage();
        }
      }
    });
  }

  // Stop payment status polling
  void _stopPaymentPolling() {
    _paymentPollingTimer?.cancel();
    _paymentPollingTimer = null;
    _pollingAttempts = 0;
    print('🛑 [PAYMENT POLLING] Payment polling stopped.');
  }

  // Show payment timeout message
  void _showPaymentTimeoutMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.schedule, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment verification timeout. Please check your subscription status manually.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Store payment ID in SharedPreferences
  Future<void> _storePaymentId(String paymentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_payment_id', paymentId);
      print('✅ [PAYMENT] Payment ID stored in SharedPreferences: $paymentId');
    } catch (e) {
      print('❌ [PAYMENT] Error storing payment ID: $e');
    }
  }

  Future<bool> _checkPaymentStatus(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseFunctionsUrl/checkPaymentStatus'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'paymentId': paymentId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final status = responseData['status'];
          return status == 'paid';
        }
      }
      return false;
    } catch (e) {
      print('Error checking payment status: $e');
      return false;
    }
  }

  // Frontend-only helper: read paymentId from SharedPreferences and POST from the app
  Future<bool> _checkPaymentStatusFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paymentId = prefs.getString('last_payment_id');
      print('🧾 [PAYMENT] Loaded last payment ID from SharedPreferences: $paymentId');
      if (paymentId == null || paymentId.isEmpty) {
        print('⚠️ [PAYMENT] No last payment ID found in SharedPreferences');
        return false;
      }
      print('📤 [PAYMENT] (Frontend) POST /checkPaymentStatus with paymentId: $paymentId');
      final isPaid = await _checkPaymentStatus(paymentId);
      print('📊 [PAYMENT] (Frontend) Status for $paymentId: ${isPaid ? 'paid' : 'pending'}');
      return isPaid;
    } catch (e) {
      print('❌ [PAYMENT] Error reading payment ID from SharedPreferences: $e');
      return false;
    }
  }

  String formatDuration(int days) {
    if (days == 30) return 'month';
    if (days == 90) return '3 months';
    if (days == 180) return '6 months';
    if (days == 365) return 'year';
    if (days == 730) return '2 years';
    if (days < 30) return '$days days';
    if (days < 365) return '${(days / 30).round()} months';
    return '${(days / 365).round()} years';
  }

  Future<void> _initiatePayment(SubscriptionPlan plan) async {
    print('🚀 [SUBSCRIPTION] Starting payment for plan: ${plan.title}');
    print('📋 [SUBSCRIPTION] Plan details:');
    print('   - Plan ID: ${plan.id}');
    print('   - Plan Title: ${plan.title}');
    print('   - Amount: ₹${plan.price}');
    print('   - Duration: ${plan.duration} days');
    print('   - Usage Type: ${widget.userUsageType}');
    
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique order ID
      final orderId = 'plan_${plan.id}_${DateTime.now().millisecondsSinceEpoch}';
      
      print('🔄 [SUBSCRIPTION] Calling Firebase Functions API...');
      print('   URL: $_firebaseFunctionsUrl/initiatePayment');
      print('   Method: POST');
      
      // Prepare request data
      final requestData = {
        'amount': plan.price,
        'userId': user.uid,
        'orderId': orderId,
      };

      print('   Body: ${jsonEncode(requestData)}');

      // Call Firebase Functions API
      final response = await http.post(
        Uri.parse('$_firebaseFunctionsUrl/initiatePayment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📥 [SUBSCRIPTION] API Response:');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final paymentUrl = responseData['payment_url'];
          final paymentId = responseData['payment_id'];
          
          print('✅ [SUBSCRIPTION] Payment link created successfully');
          print('   Payment URL: $paymentUrl');
          print('   Payment ID: $paymentId');

          // Save payment attempt to Firestore
          await _savePaymentAttempt(
            userId: user.uid,
            planId: plan.id,
            planTitle: plan.title,
            amount: plan.price,
            duration: plan.duration,
            usageType: widget.userUsageType,
            paymentUrl: paymentUrl,
            paymentId: paymentId,
            orderId: orderId,
          );

          // Launch payment URL
          await _launchPaymentUrl(paymentUrl);

          print('✅ [SUBSCRIPTION] Payment initiated successfully - showing info message');
          // _showPaymentInstructionsDialog();
          
          // Start polling for payment status
          _startPaymentPolling(paymentId);
          
          // Store payment ID in SharedPreferences for manual refresh
          await _storePaymentId(paymentId);
        } else {
          throw Exception('Payment initiation failed: ${responseData['error']}');
        }
      } else {
        throw Exception('Payment initiation failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [SUBSCRIPTION] Payment initiation failed: $e');
      String errorMessage = 'Payment initiation failed';
      String? paymentUrl;
      
      if (e.toString().contains('Payment URL launch failed')) {
        print('⚠️ [SUBSCRIPTION] Payment URL launch failed');
        errorMessage = 'Could not open payment page automatically';
        // Extract URL from error message if available
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(e.toString());
        if (urlMatch != null) {
          paymentUrl = urlMatch.group(0);
          print('🔗 [SUBSCRIPTION] Extracted payment URL: $paymentUrl');
        }
      } else if (e.toString().contains('Could not launch payment URL')) {
        print('⚠️ [SUBSCRIPTION] Could not launch payment URL');
        errorMessage = 'Unable to open payment gateway';
        // Try to extract URL from the error message
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(e.toString());
        if (urlMatch != null) {
          paymentUrl = urlMatch.group(0);
          print('🔗 [SUBSCRIPTION] Extracted payment URL: $paymentUrl');
        }
      } else {
        print('❌ [SUBSCRIPTION] Generic payment initiation error');
        errorMessage = 'Payment initiation failed: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 8),
          action: paymentUrl != null ? SnackBarAction(
            label: 'Open Manually',
            textColor: Colors.white,
            onPressed: () => _showPaymentUrlDialog(paymentUrl!),
          ) : null,
        ),
      );
    } finally {
      print('🔄 [SUBSCRIPTION] Payment processing completed - updating UI state');
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<void> _savePaymentAttempt({
    required String userId,
    required String planId,
    required String planTitle,
    required double amount,
    required int duration,
    required String usageType,
    required String paymentUrl,
    required String paymentId,
    required String orderId,
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
        'paymentId': paymentId,
        'orderId': orderId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving payment attempt: $e');
    }
  }

  Future<void> _launchPaymentUrl(String paymentUrl) async {
    try {
      final uri = Uri.parse(paymentUrl);
      
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          throw Exception('Failed to launch payment URL');
        }
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      throw Exception('Payment URL launch failed: $e. Please try opening the URL manually: $paymentUrl');
    }
  }

  void _showPaymentInstructionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Payment Instructions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment gateway has been opened in your browser. Please follow these steps:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildInstructionStep('1', 'Complete the payment in your browser'),
            _buildInstructionStep('2', 'After successful payment, close the browser and return to this app'),
            _buildInstructionStep('3', 'We\'ll automatically check your payment status every 10 seconds'),
            _buildInstructionStep('4', 'You\'ll receive a notification when payment is confirmed'),
            _buildInstructionStep('5', 'Your subscription will be activated automatically'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Tip:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'We\'ll automatically check your payment status every 10 seconds for up to 20 minutes. You can close the app and return later!',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPaymentVerificationDialog();
            },
            child: Text('Manual Verification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show success message after a delay to simulate payment completion
              Future.delayed(Duration(seconds: 2), () {
                if (mounted) {
                  _showPaymentSuccessMessage();
                }
              });
            },
            child: Text('Got It'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Payment successful! Your subscription has been activated.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View Profile',
          textColor: Colors.white,
          onPressed: () {
            // Return to home screen and refresh subscription status
            Navigator.pop(context);
            // The home screen will automatically refresh when it becomes active
          },
        ),
      ),
    );
    
    // Automatically return to home screen after a short delay
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentVerificationDialog({String? paymentUrl}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Payment Verification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (paymentUrl != null) ...[
              Text(
                'Payment page could not be opened automatically. Please use the link below:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  paymentUrl,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            Text(
              'If you have completed the payment, please enter the payment details to verify:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Payment ID (from Razorpay)',
                hintText: 'pay_xxxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Store payment ID for verification
              },
            ),
            SizedBox(height: 8),
            Text(
              'You can find the Payment ID in the confirmation email from Razorpay or in the payment page URL.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          if (paymentUrl != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openPaymentUrlManually(paymentUrl);
              },
              child: Text('Open Payment Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _verifyPaymentManually();
            },
            child: Text('Verify Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Payment Link'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The payment page could not be opened automatically. Please use one of the options below:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                url,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You can copy this link and paste it in your browser, or use the button below to try opening it again.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openPaymentUrlManually(url);
            },
            child: Text('Try Opening Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentUrlManually(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open URL. Please copy and paste this URL in your browser: $url'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyPaymentManually() async {
    // This is a simplified version. In a real app, you'd get the payment ID from the dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying payment...'),
          ],
        ),
      ),
    );

    try {
      // For demo purposes, you can implement a way to get the payment ID
      // For now, we'll just show a message
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please contact support with your payment ID for manual verification.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5F0),
              Color(0xFFF8F4FF),
              Color(0xFFFFF0E6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Back Button and Title Row
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Subscription Plans',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Logo placeholder - replace with your actual logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.star,
                        size: 40,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Choose the perfect plan for your ${selectedUsageType.toLowerCase()} needs',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Usage Type Indicator
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: selectedUsageType == 'Personal' ? Colors.blue[400] : Colors.green[400],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      selectedUsageType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Plans List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('subscriptionPlans')
                      .where('usageType', isEqualTo: selectedUsageType)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading plans',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please try again later',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No ${selectedUsageType} plans found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Check back later for new plans',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    List<SubscriptionPlan> plans = snapshot.data!.docs
                        .map((doc) => SubscriptionPlan.fromFirestore(doc))
                        .toList();

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: plan.isActive 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Plan Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  plan.title,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  plan.subtitle,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: plan.isActive
                                                  ? Colors.green[100]
                                                  : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  plan.isActive
                                                      ? Icons.check_circle
                                                      : Icons.circle_outlined,
                                                  size: 16,
                                                  color: plan.isActive
                                                      ? Colors.green[700]
                                                      : Colors.grey[600],
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  plan.isActive ? 'Active' : 'Inactive',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: plan.isActive
                                                        ? Colors.green[700]
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 16),

                                      // Price
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          ShaderMask(
                                            shaderCallback: (bounds) => LinearGradient(
                                              colors: [Colors.blue, Colors.purple],
                                            ).createShader(bounds),
                                            child: Text(
                                              '₹${plan.price.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '/${formatDuration(plan.duration)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 20),

                                      // Action Button
                                      Container(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: plan.isActive && !_isProcessingPayment ? () {
                                            _initiatePayment(plan);
                                          } : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: plan.isActive ? null : Colors.grey[300],
                                            foregroundColor: plan.isActive ? Colors.white : Colors.grey[600],
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: plan.isActive ? 4 : 0,
                                          ).copyWith(
                                            backgroundColor: plan.isActive 
                                                ? MaterialStateProperty.all(Colors.transparent)
                                                : MaterialStateProperty.all(Colors.grey[300]),
                                          ),
                                          child: Container(
                                            decoration: plan.isActive ? BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.blue, Colors.purple],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ) : null,
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: _isProcessingPayment
                                                  ? Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Processing...',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Text(
                                                      plan.isActive ? 'Select Plan' : 'Unavailable',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Indicator Bar
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: plan.isActive
                                        ? LinearGradient(
                                            colors: [Colors.green[400]!, Colors.green[600]!],
                                          )
                                        : null,
                                    color: plan.isActive ? null : Colors.grey[300],
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Main App Widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subscription Plans',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SubscriptionPlansScreen(
        userUsageType: 'Personal',
        userName: 'Test User',
        userEmail: 'test@example.com',
        userPhone: '9876543210',
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(MyApp());
}