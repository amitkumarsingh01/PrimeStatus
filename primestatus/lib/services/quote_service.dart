import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_template.dart';
import '../models/user_model.dart';

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QuoteTemplate>> getQuotesForUser(UserModel user) async {
    try {
      Query query = _firestore.collection('quotes');
      
      // Filter by user preferences
      if (user.language.isNotEmpty) {
        query = query.where('language', arrayContains: user.language);
      }
      if (user.religion.isNotEmpty) {
        query = query.where('religion', arrayContains: user.religion);
      }
      if (user.state.isNotEmpty) {
        query = query.where('state', arrayContains: user.state);
      }
      
      // Filter by subscription
      if (user.subscription == 'free') {
        query = query.where('isFree', isEqualTo: true);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => QuoteTemplate.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting quotes: $e');
      return [];
    }
  }

  Future<QuoteTemplate?> getQuoteById(String quoteId) async {
    try {
      final doc = await _firestore.collection('quotes').doc(quoteId).get();
      if (doc.exists) {
        return QuoteTemplate.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting quote: $e');
      return null;
    }
  }
} 