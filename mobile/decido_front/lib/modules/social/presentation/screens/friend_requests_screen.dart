import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../repository/friends_repository.dart';
import '../../models/friend_request_model.dart';
import '../../models/user_search_model.dart';

class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  final FriendsRepository _repository = FriendsRepository();
  
  List<FriendRequestModel> _incomingRequests = [];
  Map<int, UserSearchModel> _incomingUsers = {};
  List<Map<String, dynamic>> _outgoingRequests = [];
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadIncomingRequests();
      await _loadOutgoingRequests();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIncomingRequests() async {
    try {
      final requests = await _repository.getIncomingRequests();
      
      final Map<int, UserSearchModel> usersMap = {};
      for (final request in requests) {
        try {
          final user = await _repository.getUserById(request.userId);
          usersMap[request.userId] = user;
        } catch (e) {
          usersMap[request.userId] = UserSearchModel(
            id: request.userId,
            username: 'Пользователь #${request.userId}',
            email: '',
            isActive: true,
          );
        }
      }
      
      setState(() {
        _incomingRequests = requests;
        _incomingUsers = usersMap;
      });
    } catch (e) {
      print('Error loading incoming requests: $e');
    }
  }

  Future<void> _loadOutgoingRequests() async {
    try {
      final outgoing = await _repository.getOutgoingRequestsWithUsers();
      setState(() {
        _outgoingRequests = outgoing;
      });
    } catch (e) {
      print('Error loading outgoing requests: $e');
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    setState(() => _isLoading = true);
    try {
      await _repository.acceptRequest(request.id);
      await _loadAllRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка принята'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectRequest(FriendRequestModel request) async {
    setState(() => _isLoading = true);
    try {
      await _repository.rejectRequest(request.id);
      await _loadAllRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отклонена'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOutgoingRequest(FriendRequestModel request) async {
    setState(() => _isLoading = true);
    try {
      await _repository.rejectRequest(request.id);
      await _loadAllRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отменена'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: 412,
        height: 892,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            // Кнопка меню (три полоски) - заглушка
            Positioned(
              left: 10,
              top: 52,
              child: Container(
                width: 37,
                height: 37,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () {
                    // TODO: Открыть pop-up меню
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            
            // Заголовок "Заявки"
            Positioned(
              left: 82,
              top: 52,
              child: Text(
                'Заявки',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.67,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Индикатор (зеленый кружок) - показываем только если есть входящие запросы
            if (_incomingRequests.isNotEmpty)
              Positioned(
                left: 67,
                top: 67,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const ShapeDecoration(
                    color: AppColors.primary,
                    shape: CircleBorder(),
                  ),
                ),
              ),
            
            // Контент (входящие и исходящие заявки)
            Positioned(
              left: 41,
              top: 107,
              child: Container(
                width: 330,
                height: 680,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllRequests,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final hasIncoming = _incomingRequests.isNotEmpty;
    final hasOutgoing = _outgoingRequests.isNotEmpty;

    if (!hasIncoming && !hasOutgoing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Нет заявок',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Входящие заявки
          if (hasIncoming) ...[
            SizedBox(
              width: 330,
              child: Text(
                'Входящие',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 20,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w700,
                  height: 2,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _incomingRequests.map((request) => _buildRequestCard(
                user: _incomingUsers[request.userId],
                request: request,
                isIncoming: true,
                onAccept: () => _acceptRequest(request),
                onReject: () => _rejectRequest(request),
              )).toList(),
            ),
            if (hasOutgoing) const SizedBox(height: 24),
          ],
          
          // Исходящие заявки
          if (hasOutgoing) ...[
            SizedBox(
              width: 330,
              child: Text(
                'Исходящие',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 20,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w700,
                  height: 2,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _outgoingRequests.map((item) => _buildRequestCard(
                user: item['user'],
                request: item['request'],
                isIncoming: false,
                onReject: () => _cancelOutgoingRequest(item['request']),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required UserSearchModel? user,
    required FriendRequestModel request,
    required bool isIncoming,
    VoidCallback? onAccept,
    required VoidCallback onReject,
  }) {
    return Container(
      width: 330,
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар пользователя
          Container(
            width: 65,
            height: 65,
            decoration: ShapeDecoration(
              color: AppColors.tertiary,
              shape: const OvalBorder(),
            ),
            child: Center(
              child: Text(
                user != null && user.username.isNotEmpty && user.username != 'Пользователь #${user.id}'
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 15),
          
          // Информация о пользователе (растягивается)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? 'Пользователь #${request.userId}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontFamily: 'Instrument Sans',
                    fontWeight: FontWeight.w500,
                    height: 1.10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user?.email != null && user!.email.isNotEmpty)
                  Text(
                    user.email,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontFamily: 'Instrument Sans',
                      fontWeight: FontWeight.w500,
                      height: 1.38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  _formatDate(request.createdAt),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Instrument Sans',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Кнопки действий
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isIncoming) ...[
                // Кнопка принятия (SVG)
                GestureDetector(
                  onTap: onAccept,
                  child: SvgPicture.asset(
                    'assets/icons/add_plus_green_icon.svg',
                    width: 32,
                    height: 32,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Кнопка отклонения/отмены (SVG)
              GestureDetector(
                onTap: onReject,
                child: SvgPicture.asset(
                  'assets/icons/delete_cross_icon.svg',
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7} нед. назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'только что';
    }
  }
}