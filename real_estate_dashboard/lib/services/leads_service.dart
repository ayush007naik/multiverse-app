import 'package:db_compat/db_compat.dart';

class LeadsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new lead and triggers auto-assignment/notification logic
  Future<void> createLead({
    required String sellerId,
    required String propertyId,
    required String propertyTitle,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
    String leadType = 'inquiry',
  }) async {
    final leadData = {
      'sellerId': sellerId,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'buyerEmail': buyerEmail,
      'leadType': leadType,
      'status': 'new',
      'isAssigned': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 1. Create the lead in Firestore
    DocumentReference leadRef = await _firestore.collection('property_leads').add(leadData);

    // 2. Add to lead_notifications for backend (Cloud Functions) to handle push/SMS
    await _firestore.collection('lead_notifications').add({
      'leadId': leadRef.id,
      'sellerId': sellerId,
      'message': 'New $leadType for $propertyTitle from $buyerName',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // 3. Auto-assignment logic (Simulated for now, usually handled by Cloud Functions)
    // In a multi-agent scenario, we might assign to a specific team member here.
    await leadRef.update({
      'isAssigned': true,
      'assignedTo': sellerId, // Default to the primary broker
    });
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _firestore.collection('property_leads').doc(leadId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveLead(String leadId) async {
    await _firestore.collection('property_leads').doc(leadId).update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
