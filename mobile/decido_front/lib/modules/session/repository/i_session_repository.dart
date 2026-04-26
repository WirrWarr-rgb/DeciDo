import '../models/session_models.dart';

abstract class ISessionRepository {
  Future<SessionModel> createLobby(CreateLobbyRequest request);
  Future<SessionModel> getLobby(int sessionId);
  Future<void> markReady(int sessionId);
  Future<void> forceStart(int sessionId);
  Future<Map<String, dynamic>> submitVote(int sessionId, {List<int>? rankedItemIds, bool spin = false});
  Future<Map<String, dynamic>> getResults(int sessionId);
  Future<void> leaveLobby(int sessionId);
  Future<void> closeLobby(int sessionId);
  Future<void> backToLobby(int sessionId);
  Future<SessionListItemModel> addItem(int sessionId, {required String name, String? description, String? imageUrl});
  Future<SessionListItemModel> updateItem(int sessionId, int itemId, {String? name, String? description, String? imageUrl});
  Future<void> deleteItem(int sessionId, int itemId);
  Future<void> updateOrder(int sessionId, List<Map<String, int>> itemsOrder);
  Future<void> kickParticipant(int sessionId, int userId);
  Future<void> inviteFriends(int sessionId, List<int> friendIds);
  Future<void> lockList(int sessionId);
  Future<void> unlockList(int sessionId);
}