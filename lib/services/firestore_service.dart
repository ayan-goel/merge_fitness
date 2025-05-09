import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  void _checkAuthentication() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
  }

  // Generic method to add a document to a collection
  Future<DocumentReference> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    return await _firestore.collection(collection).add(data);
  }

  // Generic method to set a document with ID
  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: merge));
  }

  // Generic method to update a document
  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collection).doc(documentId).update(data);
  }

  // Generic method to delete a document
  Future<void> deleteDocument(
    String collection,
    String documentId,
  ) async {
    await _firestore.collection(collection).doc(documentId).delete();
  }

  // Generic method to get a document
  Future<DocumentSnapshot> getDocument(
    String collection,
    String documentId,
  ) async {
    return await _firestore.collection(collection).doc(documentId).get();
  }

  // Generic method to query collection
  Future<QuerySnapshot> queryCollection(
    String collection, {
    required List<QueryCondition> conditions,
    String? orderBy,
    bool descending = false,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore.collection(collection);

    // Apply where conditions
    for (var condition in conditions) {
      query = query.where(
        condition.field,
        isEqualTo: condition.isEqualTo,
        isNotEqualTo: condition.isNotEqualTo,
        isLessThan: condition.isLessThan,
        isLessThanOrEqualTo: condition.isLessThanOrEqualTo,
        isGreaterThan: condition.isGreaterThan,
        isGreaterThanOrEqualTo: condition.isGreaterThanOrEqualTo,
        arrayContains: condition.arrayContains,
        arrayContainsAny: condition.arrayContainsAny,
        whereIn: condition.whereIn,
        whereNotIn: condition.whereNotIn,
      );
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    // Apply pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  // Get stream of documents
  Stream<QuerySnapshot> streamCollection(
    String collection, {
    List<QueryCondition> conditions = const [],
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);

    // Apply where conditions
    for (var condition in conditions) {
      query = query.where(
        condition.field,
        isEqualTo: condition.isEqualTo,
        isNotEqualTo: condition.isNotEqualTo,
        isLessThan: condition.isLessThan,
        isLessThanOrEqualTo: condition.isLessThanOrEqualTo,
        isGreaterThan: condition.isGreaterThan,
        isGreaterThanOrEqualTo: condition.isGreaterThanOrEqualTo,
        arrayContains: condition.arrayContains,
        arrayContainsAny: condition.arrayContainsAny,
        whereIn: condition.whereIn,
        whereNotIn: condition.whereNotIn,
      );
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  // Stream a specific document
  Stream<DocumentSnapshot> streamDocument(
    String collection,
    String documentId,
  ) {
    return _firestore.collection(collection).doc(documentId).snapshots();
  }

  // Batch operations
  Future<void> batchOperation(
    List<BatchOperation> operations,
  ) async {
    WriteBatch batch = _firestore.batch();

    for (var operation in operations) {
      DocumentReference ref = _firestore.collection(operation.collection).doc(operation.documentId);

      switch (operation.type) {
        case BatchOperationType.set:
          batch.set(ref, operation.data!, SetOptions(merge: operation.merge ?? false));
          break;
        case BatchOperationType.update:
          batch.update(ref, operation.data!);
          break;
        case BatchOperationType.delete:
          batch.delete(ref);
          break;
      }
    }

    await batch.commit();
  }

  // Transaction operations
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionFunction,
  ) async {
    return await _firestore.runTransaction(transactionFunction);
  }
}

// Helper class for query conditions
class QueryCondition {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic>? arrayContainsAny;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;

  QueryCondition({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
  });
}

// Helper enum for batch operations
enum BatchOperationType {
  set,
  update,
  delete,
}

// Helper class for batch operations
class BatchOperation {
  final String collection;
  final String documentId;
  final Map<String, dynamic>? data;
  final BatchOperationType type;
  final bool? merge;

  BatchOperation.set(
    this.collection,
    this.documentId,
    this.data, {
    this.merge = false,
  }) : type = BatchOperationType.set;

  BatchOperation.update(
    this.collection,
    this.documentId,
    this.data,
  ) : type = BatchOperationType.update, merge = null;

  BatchOperation.delete(
    this.collection,
    this.documentId,
  ) : type = BatchOperationType.delete, data = null, merge = null;
} 