import 'package:equatable/equatable.dart';

// ============= Enums =============
enum SessionStatus {
  waiting('waiting'),
  editing('editing'),
  ready('ready'),
  voting('voting'),
  results('results'),
  closed('closed');

  final String value;
  const SessionStatus(this.value);

  static SessionStatus fromString(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionStatus.waiting,
    );
  }
}

enum SessionMode {
  random('random'),
  ranking('ranking');

  final String value;
  const SessionMode(this.value);

  static SessionMode fromString(String value) {
    return SessionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionMode.ranking,
    );
  }
}

// В ParticipantStatus:
enum ParticipantStatus {
  invited('invited'),
  accepted('accepted'),
  declined('declined'),
  left('left'),
  kicked('kicked');  // Добавить

  final String value;
  const ParticipantStatus(this.value);
  
  static ParticipantStatus fromString(String value) {
    switch (value) {
      case 'invited': return ParticipantStatus.invited;
      case 'accepted': return ParticipantStatus.accepted;
      case 'declined': return ParticipantStatus.declined;
      case 'left': return ParticipantStatus.left;
      case 'kicked': return ParticipantStatus.kicked;
      default: return ParticipantStatus.invited;
    }
  }
}

// ============= Модели =============
class SessionListItemModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int orderIndex;
  final int? createdBy;
  final String? creatorName;

  const SessionListItemModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.orderIndex,
    this.createdBy,
    this.creatorName,
  });

  factory SessionListItemModel.fromJson(Map<String, dynamic> json) {
    return SessionListItemModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      orderIndex: json['order_index'],
      createdBy: json['created_by'],
      creatorName: json['creator_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'order_index': orderIndex,
      'created_by': createdBy,
      'creator_name': creatorName,
    };
  }

  SessionListItemModel copyWith({
    int? id,
    String? name,
    String? description,
    String? imageUrl,
    int? orderIndex,
    int? createdBy,
    String? creatorName,
  }) {
    return SessionListItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      orderIndex: orderIndex ?? this.orderIndex,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
    );
  }

  @override
  List<Object?> get props => [id, name, description, imageUrl, orderIndex, createdBy, creatorName];
}

class SessionListModel extends Equatable {
  final int id;
  final String name;
  final bool isActive;
  final List<SessionListItemModel> items;
  final DateTime createdAt;

  const SessionListModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.items,
    required this.createdAt,
  });

  factory SessionListModel.fromJson(Map<String, dynamic> json) {
    return SessionListModel(
      id: json['id'],
      name: json['name'],
      isActive: json['is_active'],
      items: (json['items'] as List)
          .map((item) => SessionListItemModel.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, isActive, items, createdAt];
}

class ParticipantModel extends Equatable {
  final int userId;
  final String username;
  final ParticipantStatus status;
  final bool isReady;
  final bool hasVoted;
  final bool isOwner;
  final DateTime invitedAt;
  final DateTime? joinedAt;

  const ParticipantModel({
    required this.userId,
    required this.username,
    required this.status,
    required this.isReady,
    required this.hasVoted,
    required this.isOwner,
    required this.invitedAt,
    this.joinedAt,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      userId: json['user_id'],
      username: json['username'],
      status: ParticipantStatus.fromString(json['status']),
      isReady: json['is_ready'],
      hasVoted: json['has_voted'],
      isOwner: json['is_owner'],
      invitedAt: DateTime.parse(json['invited_at']),
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'status': status.value,
      'is_ready': isReady,
      'has_voted': hasVoted,
      'is_owner': isOwner,
      'invited_at': invitedAt.toIso8601String(),
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [userId, username, status, isReady, hasVoted, isOwner, invitedAt, joinedAt];
}

class SessionModel extends Equatable {
  final int id;
  final int ownerId;
  final String ownerName;
  final SessionStatus status;
  final SessionMode mode;
  final bool listLocked;
  final SessionListModel? currentList;
  final List<ParticipantModel> participants;
  final int votingDuration;
  final DateTime createdAt;
  final DateTime? votingEndsAt;
  final DateTime? countdownEndsAt;
  final Map<String, dynamic>? results;
  
  // Права текущего пользователя
  final bool isOwner;
  final bool canEditList;
  final bool canStart;
  final bool canInvite;
  final bool canLockList;

  const SessionModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.status,
    required this.mode,
    required this.listLocked,
    this.currentList,
    required this.participants,
    required this.votingDuration,
    required this.createdAt,
    this.votingEndsAt,
    this.countdownEndsAt,
    this.results,
    required this.isOwner,
    required this.canEditList,
    required this.canStart,
    required this.canInvite,
    required this.canLockList,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      ownerId: json['owner_id'],
      ownerName: json['owner_name'],
      status: SessionStatus.fromString(json['status']),
      mode: SessionMode.fromString(json['mode']),
      listLocked: json['list_locked'],
      currentList: json['current_list'] != null 
          ? SessionListModel.fromJson(json['current_list']) 
          : null,
      participants: (json['participants'] as List)
          .map((p) => ParticipantModel.fromJson(p))
          .toList(),
      votingDuration: json['voting_duration'],
      createdAt: DateTime.parse(json['created_at']),
      votingEndsAt: json['voting_ends_at'] != null 
          ? DateTime.parse(json['voting_ends_at']) 
          : null,
      countdownEndsAt: json['countdown_ends_at'] != null 
          ? DateTime.parse(json['countdown_ends_at']) 
          : null,
      results: json['results'],
      isOwner: json['is_owner'] ?? false,
      canEditList: json['can_edit_list'] ?? false,
      canStart: json['can_start'] ?? false,
      canInvite: json['can_invite'] ?? false,
      canLockList: json['can_lock_list'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'status': status.value,
      'mode': mode.value,
      'list_locked': listLocked,
      'current_list': currentList?.toJson(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'voting_duration': votingDuration,
      'created_at': createdAt.toIso8601String(),
      'voting_ends_at': votingEndsAt?.toIso8601String(),
      'countdown_ends_at': countdownEndsAt?.toIso8601String(),
      'results': results,
      'is_owner': isOwner,
      'can_edit_list': canEditList,
      'can_start': canStart,
      'can_invite': canInvite,
      'can_lock_list': canLockList,
    };
  }

  @override
  List<Object?> get props => [
    id, ownerId, ownerName, status, mode, listLocked, currentList,
    participants, votingDuration, createdAt, votingEndsAt, countdownEndsAt, results,
    isOwner, canEditList, canStart, canInvite, canLockList
  ];
}

// ============= Request Models =============
class CreateLobbyRequest {
  final List<int> friendIds;
  final ListData listData;
  final SessionMode mode;
  final int votingDuration;

  CreateLobbyRequest({
    required this.friendIds,
    required this.listData,
    this.mode = SessionMode.ranking,
    this.votingDuration = 120,
  });

  Map<String, dynamic> toJson() {
    return {
      'friend_ids': friendIds,
      'list_data': listData.toJson(),
      'mode': mode.value,
      'voting_duration': votingDuration,
    };
  }
}

class ListData {
  final String name;
  final List<ListDataItem> items;

  ListData({
    required this.name,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class ListDataItem {
  final String name;
  final String? description;
  final String? imageUrl;
  final int orderIndex;

  ListDataItem({
    required this.name,
    this.description,
    this.imageUrl,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'order_index': orderIndex,
    };
  }
}

class CreateLobbyItem {
  final String name;
  final String? description;
  final String? imageUrl;

  CreateLobbyItem({
    required this.name,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
    };
  }
}

class InviteToLobbyRequest {
  final List<int> friendIds;

  InviteToLobbyRequest({required this.friendIds});

  Map<String, dynamic> toJson() {
    return {'friend_ids': friendIds};
  }
}

class ChangeListRequest {
  final int listId;

  ChangeListRequest({required this.listId});

  Map<String, dynamic> toJson() {
    return {'list_id': listId};
  }
}

class VoteRequest {
  final List<int>? rankedItemIds;
  final bool spin;

  VoteRequest({this.rankedItemIds, this.spin = false});

  Map<String, dynamic> toJson() {
    return {
      'ranked_item_ids': rankedItemIds,
      'spin': spin,
    };
  }
}

// ============= WebSocket Message Types =============
class WSMessageType {
  static const String lobbyInvitation = 'lobby_invitation';
  static const String participantJoined = 'participant_joined';
  static const String participantLeft = 'participant_left';
  static const String participantReady = 'participant_ready';
  static const String listChanged = 'list_changed';
  static const String listLocked = 'list_locked';
  static const String listUnlocked = 'list_unlocked';
  static const String listItemAdded = 'list_item_added';
  static const String listItemUpdated = 'list_item_updated';
  static const String listItemDeleted = 'list_item_deleted';
  static const String listOrderChanged = 'list_order_changed';
  static const String lobbyStarted = 'lobby_started';
  static const String startVoting = "start_voting"; 
  static const String votingStarted = "voting_started";  // ← подтверждение начала голосования
  static const String userVoted = 'user_voted';
  static const String resultsReady = 'results_ready';
  static const String lobbyClosed = 'lobby_closed';
  static const String stateChanged = 'state_changed';
  static const String timerExpired = 'timer_expired';
  static const String error = 'error';
  static const String pong = 'pong';
  

  static const String unready = 'unready';
  static const String participantKicked = 'participant_kicked';
  static const String itemLocked = 'item_locked';
  static const String itemUnlocked = 'item_unlocked';


  // От клиента
  static const String acceptInvite = 'accept_invite';
  static const String declineInvite = 'decline_invite';
  static const String ready = 'ready';
  static const String changeList = 'change_list';
  static const String lockList = 'lock_list';
  static const String unlockList = 'unlock_list';
  static const String addItem = 'add_item';
  static const String updateItem = 'update_item';
  static const String deleteItem = 'delete_item';
  static const String updateOrder = 'update_order';
  static const String vote = 'vote';
  static const String leaveLobby = 'leave_lobby';
  static const String closeLobby = 'close_lobby';
  static const String backToLobby = 'back_to_lobby';
  static const String ping = 'ping';


  static const String timerUpdated = 'timer_updated';

  // Глобальные навигационные сообщения
  static const String NAVIGATE_TO_LOBBY = "navigate_to_lobby";
  static const String NAVIGATE_TO_HOME = "navigate_to_home";
  static const String NAVIGATE_TO_RANKING = "navigate_to_ranking";
  static const String NAVIGATE_TO_RESULTS = "navigate_to_results";
}

class WSMessage {
  final String type;
  final Map<String, dynamic> payload;

  WSMessage({required this.type, this.payload = const {}});

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    return WSMessage(
      type: json['type'],
      payload: json['payload'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
    };
  }
}