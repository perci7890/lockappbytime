import '../database/lock_database.dart';
import '../models/lock_record.dart';
import '../../core/services/native_bridge_service.dart';

class LockRepository {
  final LockDatabase _db = LockDatabase.instance;

  Future<List<LockRecord>> getActiveLocks() async {
    // Automatically prune expired locks from the database
    await _db.cleanupExpiredLocks();
    return await _db.getActiveLocks();
  }

  Future<List<LockRecord>> getAllLocks() async {
    return await _db.getAllLocks();
  }

  Future<List<LockRecord>> getSchedules() async {
    return await _db.getSchedules();
  }

  Future<void> saveLock(LockRecord lock) async {
    // 1. Save to SQLite database
    await _db.insertOrUpdateLock(lock);
    // 2. Sync to Android Native storage for immediate AccessibilityService awareness
    await NativeBridgeService.saveLockNative(lock);
  }

  Future<void> removeLock(String packageName, {String? lockType, String? sourceId}) async {
    // 1. Remove from SQLite
    await _db.deleteLock(packageName, lockType: lockType, sourceId: sourceId);
    // 2. Remove from Android Native storage
    await NativeBridgeService.removeLockNative(packageName, lockType: lockType, sourceId: sourceId);
  }

  Future<LockRecord?> getLock(String packageName, {String? lockType, String? sourceId}) async {
    return await _db.getLockByPackage(packageName, lockType: lockType, sourceId: sourceId);
  }

  // Focus Modes
  Future<void> saveFocusMode(Map<String, dynamic> focusMode) async {
    await _db.saveFocusMode(focusMode);
  }

  Future<List<Map<String, dynamic>>> getFocusModes() async {
    return await _db.getFocusModes();
  }

  Future<void> deleteFocusMode(String id) async {
    await _db.deleteFocusMode(id);
  }
}
