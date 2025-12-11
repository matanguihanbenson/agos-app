import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/base_model.dart';
import 'logging_service.dart';

abstract class BaseService<T extends BaseModel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggingService _loggingService = LoggingService();
  
  String get collectionName;
  
  // Protected getters for subclasses
  FirebaseFirestore get firestore => _firestore;
  LoggingService get loggingService => _loggingService;
  CollectionReference get collection => _firestore.collection(collectionName);
  
  T fromMap(Map<String, dynamic> map, String id);
  
  Future<String> create(T model) async {
    try {
      final docRef = await _firestore.collection(collectionName).add(model.toMap());
      await _loggingService.logEvent(
        event: '${collectionName}_created',
        parameters: {'id': docRef.id},
      );
      return docRef.id;
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_create',
      );
      rethrow;
    }
  }
  
  Future<T?> getById(String id) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(id).get();
      if (!doc.exists) return null;
      return fromMap(doc.data()!, doc.id);
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getById',
      );
      return null;
    }
  }
  
  Stream<List<T>> getAll() {
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<T>> getByField(String field, dynamic value) {
    return _firestore
        .collection(collectionName)
        .where(field, isEqualTo: value)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromMap(doc.data(), doc.id))
            .toList());
  }
  
  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _loggingService.logEvent(
        event: '${collectionName}_updated',
        parameters: {'id': id},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_update',
      );
      rethrow;
    }
  }
  
  Future<void> delete(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
      await _loggingService.logEvent(
        event: '${collectionName}_deleted',
        parameters: {'id': id},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_delete',
      );
      rethrow;
    }
  }

  Future<List<T>> getAllOnce() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getAllOnce',
      );
      rethrow;
    }
  }

  Future<List<T>> getByFieldOnce(String field, dynamic value) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where(field, isEqualTo: value)
          .get();
      return snapshot.docs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getByFieldOnce',
      );
      rethrow;
    }
  }
}
