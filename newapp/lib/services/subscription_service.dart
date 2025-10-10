import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class SubscriptionPlan {
  final String id;
  final String title;
  final String subtitle;
  final double price;
  final int duration; // Duration in days
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
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionPlan(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      duration: data['duration'] ?? 30,
      usageType: data['usageType'] ?? 'Personal',
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'duration': duration,
      'usageType': usageType,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Razorpay Configuration - Replace with your actual credentials
  static const String _razorpayKeyId = 'rzp_test_0Boj1vgEUw5VZW';
  static const String _razorpayKeySecret = 'cpC64lAXhleU8ScWmaJDBZbC';
  static const String _razorpayBaseUrl = 'https://api.razorpay.com/v1';

  /// Fetch all active subscription plans for a specific usage type
  Future<List<SubscriptionPlan>> getActivePlans(String usageType) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('subscriptionPlans')
          .where('usageType', isEqualTo: usageType)
          .where('isActive', isEqualTo: true)
          .orderBy('price')
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching subscription plans: $e');
      return [];
    }
  }

  /// Fetch all subscription plans (active and inactive) for admin purposes
  Future<List<SubscriptionPlan>> getAllPlans() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('subscriptionPlans')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching all subscription plans: $e');
      return [];
    }
  }

  /// Get a specific subscription plan by ID
  Future<SubscriptionPlan?> getPlanById(String planId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('subscriptionPlans')
          .doc(planId)
          .get();

      if (doc.exists) {
        return SubscriptionPlan.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching subscription plan by ID: $e');
      return null;
    }
  }

  /// Create a new subscription plan (admin only)
  Future<bool> createPlan(SubscriptionPlan plan) async {
    try {
      await _firestore
          .collection('subscriptionPlans')
          .add(plan.toMap());
      return true;
    } catch (e) {
      print('Error creating subscription plan: $e');
      return false;
    }
  }

  /// Update an existing subscription plan (admin only)
  Future<bool> updatePlan(String planId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('subscriptionPlans')
          .doc(planId)
          .update(updates);
      return true;
    } catch (e) {
      print('Error updating subscription plan: $e');
      return false;
    }
  }

  /// Delete a subscription plan (admin only)
  Future<bool> deletePlan(String planId) async {
    try {
      await _firestore
          .collection('subscriptionPlans')
          .doc(planId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting subscription plan: $e');
      return false;
    }
  }

  /// Get the best value plan (lowest price) for a usage type
  Future<SubscriptionPlan?> getBestValuePlan(String usageType) async {
    try {
      final plans = await getActivePlans(usageType);
      if (plans.isEmpty) return null;
      
      // Sort by price and return the cheapest
      plans.sort((a, b) => a.price.compareTo(b.price));
      return plans.first;
    } catch (e) {
      print('Error getting best value plan: $e');
      return null;
    }
  }

  /// Check if a user has an active subscription
  Future<bool> hasActiveSubscription(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final usageType = userData['usageType'] ?? 'Personal';
        final subscription = userData['subscription'];
        final subscriptionDate = userData['subscriptionDate'];

        // Personal users always have free access
        if (usageType == 'Personal') {
          return true;
        }

        // For Business users, check subscription
        if (subscription == null || subscriptionDate == null) {
          return false;
        }

        // Check if subscription is 'free'
        if (subscription == 'free') {
          return false; // Business users need paid subscription
        }

        // Check subscription expiry based on subscription type
        final DateTime subDate = (subscriptionDate as Timestamp).toDate();
        final DateTime now = DateTime.now();
        
        switch (subscription) {
          case 'monthly':
            return now.difference(subDate).inDays <= 30;
          case '6-month':
            return now.difference(subDate).inDays <= 180;
          case 'yearly':
            return now.difference(subDate).inDays <= 365;
          default:
            return false;
        }
      }
      return false;
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }

  /// Update user subscription
  Future<bool> updateUserSubscription(String userId, String subscriptionType) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'subscription': subscriptionType,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user subscription: $e');
      return false;
    }
  }

  /// Get subscription expiry date for a user
  Future<DateTime?> getSubscriptionExpiryDate(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final subscription = userData['subscription'];
        final subscriptionDate = userData['subscriptionDate'];

        if (subscription == null || subscriptionDate == null) {
          return null;
        }

        if (subscription == 'free') {
          return null; // Free users don't have expiry
        }

        final DateTime subDate = (subscriptionDate as Timestamp).toDate();
        
        switch (subscription) {
          case 'monthly':
            return subDate.add(Duration(days: 30));
          case '6-month':
            return subDate.add(Duration(days: 180));
          case 'yearly':
            return subDate.add(Duration(days: 365));
          default:
            return null;
        }
      }
      return null;
    } catch (e) {
      print('Error getting subscription expiry date: $e');
      return null;
    }
  }

  /// Generate Razorpay payment link for subscription
  Future<Map<String, dynamic>?> createPaymentLink({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required SubscriptionPlan plan,
  }) async {
    try {
      // Generate unique receipt ID
      final String receiptId = 'receipt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      
      // Create payment link request body
      final Map<String, dynamic> requestBody = {
        'amount': (plan.price * 100).round(), // Convert to paise
        'currency': 'INR',
        'accept_partial': false,
        'first_min_partial_amount': 0,
        'reference_id': receiptId,
        'description': '${plan.title} - ${plan.subtitle}',
        'customer': {
          'name': userName,
          'email': userEmail,
          'contact': userPhone,
        },
        'notify': {
          'sms': true,
          'email': true,
        },
        'reminder_enable': true,
        'notes': {
          'plan_id': plan.id,
          'user_id': userId,
          'plan_title': plan.title,
          'duration_days': plan.duration.toString(),
          'usage_type': plan.usageType,
        },
        'callback_url': 'https://your-app-domain.com/payment/callback',
        'callback_method': 'get',
      };

      // Make API request to Razorpay
      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/payment_links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Store payment record in Firestore
        await _firestore.collection('payments').add({
          'userId': userId,
          'planId': plan.id,
          'planTitle': plan.title,
          'amount': plan.price,
          'currency': 'INR',
          'razorpayPaymentId': responseData['id'],
          'razorpayPaymentLinkId': responseData['id'],
          'paymentLink': responseData['short_url'],
          'status': 'pending',
          'receiptId': receiptId,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': DateTime.now().add(Duration(hours: 24)), // Link expires in 24 hours
        });

        return {
          'success': true,
          'paymentLink': responseData['short_url'],
          'paymentId': responseData['id'],
          'receiptId': receiptId,
        };
      } else {
        print('Razorpay API Error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to create payment link',
        };
      }
    } catch (e) {
      print('Error creating payment link: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify payment and update user subscription
  Future<bool> verifyPaymentAndUpdateSubscription({
    required String paymentId,
    required String userId,
  }) async {
    try {
      // Get payment details from Razorpay
      final response = await http.get(
        Uri.parse('$_razorpayBaseUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'))}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> paymentData = jsonDecode(response.body);
        
        if (paymentData['status'] == 'captured') {
          // Payment successful, update user subscription
          final String planId = paymentData['notes']['plan_id'];
          final plan = await getPlanById(planId);
          
          if (plan != null) {
            // Update user subscription
            await _firestore.collection('users').doc(userId).update({
              'subscription': planId,
              'subscriptionDate': FieldValue.serverTimestamp(),
              'subscriptionPlan': {
                'id': plan.id,
                'title': plan.title,
                'duration': plan.duration,
                'usageType': plan.usageType,
              },
              'lastPayment': {
                'paymentId': paymentId,
                'amount': paymentData['amount'] / 100, // Convert from paise
                'currency': paymentData['currency'],
                'date': FieldValue.serverTimestamp(),
              },
            });

            // Update payment record
            await _firestore.collection('payments').where('razorpayPaymentId', isEqualTo: paymentId).get().then((snapshot) {
              if (snapshot.docs.isNotEmpty) {
                snapshot.docs.first.reference.update({
                  'status': 'completed',
                  'completedAt': FieldValue.serverTimestamp(),
                  'razorpayPaymentData': paymentData,
                });
              }
            });

            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  /// Get payment history for a user
  Future<List<Map<String, dynamic>>> getUserPaymentHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'planTitle': data['planTitle'],
          'amount': data['amount'],
          'currency': data['currency'],
          'status': data['status'],
          'paymentLink': data['paymentLink'],
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
          'completedAt': data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
        };
      }).toList();
    } catch (e) {
      print('Error fetching payment history: $e');
      return [];
    }
  }

  /// Get pending payments for a user
  Future<List<Map<String, dynamic>>> getPendingPayments(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'planTitle': data['planTitle'],
          'amount': data['amount'],
          'currency': data['currency'],
          'paymentLink': data['paymentLink'],
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
          'expiresAt': (data['expiresAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error fetching pending payments: $e');
      return [];
    }
  }

  /// Cancel pending payment
  Future<bool> cancelPayment(String paymentId) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error cancelling payment: $e');
      return false;
    }
  }

  /// Get payment statistics
  Future<Map<String, dynamic>> getPaymentStatistics() async {
    try {
      final QuerySnapshot allPayments = await _firestore.collection('payments').get();
      final QuerySnapshot completedPayments = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      for (var doc in completedPayments.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['amount'] ?? 0).toDouble();
      }

      return {
        'totalPayments': allPayments.docs.length,
        'completedPayments': completedPayments.docs.length,
        'pendingPayments': allPayments.docs.length - completedPayments.docs.length,
        'totalRevenue': totalRevenue,
        'successRate': allPayments.docs.length > 0 
            ? (completedPayments.docs.length / allPayments.docs.length * 100).toStringAsFixed(2)
            : '0.00',
      };
    } catch (e) {
      print('Error fetching payment statistics: $e');
      return {};
    }
  }

  Future<List<SubscriptionPlan>> getAllActivePlans() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('subscriptionPlans')
          .where('isActive', isEqualTo: true)
          .orderBy('price')
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching all active subscription plans: $e');
      return [];
    }
  }
} 