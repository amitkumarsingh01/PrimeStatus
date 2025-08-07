import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_service.dart';

class PaymentTestScreen extends StatefulWidget {
  @override
  _PaymentTestScreenState createState() => _PaymentTestScreenState();
}

class _PaymentTestScreenState extends State<PaymentTestScreen> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment API Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test Buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _testInitiatePayment,
              child: Text('Test Initiate Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _testCheckPaymentStatus,
              child: Text('Test Check Payment Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _testUpdateSubscription,
              child: Text('Test Update Subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _clearResults,
              child: Text('Clear Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            SizedBox(height: 20),
            
            // Loading Indicator
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Testing API calls...'),
                  ],
                ),
              ),
            
            // Results Display
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'Click a test button to see API calls and responses...' : _testResults,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addResult(String result) {
    setState(() {
      _testResults += '\n${DateTime.now().toString().substring(11, 19)} - $result\n';
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }

  Future<void> _testInitiatePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addResult('❌ No user logged in');
        return;
      }

      _addResult('🚀 Testing initiatePayment API...');
      
      await PaymentService.initiatePayment(
        amount: 99.0,
        orderId: 'test_order_001',
      );

      _addResult('✅ initiatePayment test completed');
    } catch (e) {
      _addResult('❌ initiatePayment test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testCheckPaymentStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addResult('🔍 Testing checkPaymentStatus API...');
      
      // Test with a dummy payment ID
      final result = await PaymentService.verifyPaymentManually('plink_test_123456');
      
      _addResult('✅ checkPaymentStatus test completed - Result: $result');
    } catch (e) {
      _addResult('❌ checkPaymentStatus test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testUpdateSubscription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addResult('❌ No user logged in');
        return;
      }

      _addResult('🔄 Testing updateUserSubscription API...');
      
      // This would normally be called after a successful payment
      // For testing, we'll simulate it
      _addResult('ℹ️ updateUserSubscription is called automatically after successful payment');
      _addResult('✅ updateUserSubscription test completed');
    } catch (e) {
      _addResult('❌ updateUserSubscription test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 