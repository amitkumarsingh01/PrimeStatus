import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';

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

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String get selectedUsageType => widget.userUsageType;
  bool _isProcessingPayment = false;

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
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      await PaymentService.initiatePayment(
        planId: plan.id,
        planTitle: plan.title,
        amount: plan.price,
        duration: plan.duration,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userEmail: widget.userEmail,
        userPhone: widget.userPhone,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment gateway opened in browser. Please complete the payment and return to the app.'),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Verify Payment',
            onPressed: () => _showPaymentVerificationDialog(),
          ),
        ),
      );
    } catch (e) {
      String errorMessage = 'Payment initiation failed';
      String? paymentUrl;
      
      if (e.toString().contains('Payment URL launch failed')) {
        errorMessage = 'Could not open payment page automatically';
        // Extract URL from error message if available
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(e.toString());
        if (urlMatch != null) {
          paymentUrl = urlMatch.group(0);
        }
      } else if (e.toString().contains('Could not launch payment URL')) {
        errorMessage = 'Unable to open payment gateway';
        // Try to extract URL from the error message
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(e.toString());
        if (urlMatch != null) {
          paymentUrl = urlMatch.group(0);
        }
      } else {
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
      setState(() {
        _isProcessingPayment = false;
      });
    }
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