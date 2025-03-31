import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_bloc.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_event.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_state.dart';
import 'package:talabna/data/models/point_transaction.dart';
import 'package:talabna/provider/language.dart';

class TransactionListWidget extends StatefulWidget {
  final int userId;
  final int? otherUserId;
  final int limit;
  final bool showBetweenUsers;
  final Widget? emptyWidget;
  final int? highlightTransactionId;

  const TransactionListWidget({
    Key? key,
    required this.userId,
    this.otherUserId,
    this.limit = 5,
    this.showBetweenUsers = false,
    this.emptyWidget,
    this.highlightTransactionId,
  }) : super(key: key);

  @override
  State<TransactionListWidget> createState() => _TransactionListWidgetState();
}

class _TransactionListWidgetState extends State<TransactionListWidget> {
  static final Language _language = Language();
  bool _isLoadingData = false;
  bool _hasInitiallyLoaded = false; // Track if we've loaded data initially

  @override
  void initState() {
    super.initState();
    // Only load data once during initialization
    if (!_hasInitiallyLoaded) {
      _hasInitiallyLoaded = true;
      _loadTransactions();
    }
  }

  @override
  void didUpdateWidget(TransactionListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only reload when critical props actually change
    if (oldWidget.showBetweenUsers != widget.showBetweenUsers ||
        oldWidget.otherUserId != widget.otherUserId ||
        oldWidget.userId != widget.userId) {

      // Load transactions only if there's a real change in the configuration
      print('Widget configuration changed, reloading transactions');
      _loadTransactions();
    } else if (oldWidget.highlightTransactionId != widget.highlightTransactionId &&
        widget.highlightTransactionId != null) {
      // If only the highlight ID changed, we don't need to reload data
      print('Only highlight ID changed, not reloading transactions');
    }
  }

  void _loadTransactions() {
    if (!mounted) return;

    // Prevent loading if we're already loading
    if (_isLoadingData) {
      print('Already loading transactions, skipping request');
      return;
    }

    setState(() {
      _isLoadingData = true;
    });

    print('-------------------------');
    print('Loading transactions:');
    print('- showBetweenUsers: ${widget.showBetweenUsers}');
    print('- userId: ${widget.userId}');
    print('- otherUserId: ${widget.otherUserId}');

    // Choose which transactions to load based on widget configuration
    if (widget.showBetweenUsers && widget.otherUserId != null) {
      // Check if we already have the correct data loaded
      final currentState = context.read<PointTransactionBloc>().state;
      if (currentState is TransactionsBetweenUsersLoaded) {
        if (currentState.fromUserId == widget.userId &&
            currentState.toUserId == widget.otherUserId) {
          print('Already have data for these users, not reloading');
          setState(() {
            _isLoadingData = false;
          });
          return;
        }
      }

      print('Fetching transactions between users ${widget.userId} and ${widget.otherUserId}');
      context.read<PointTransactionBloc>().add(
        FetchTransactionsBetweenUsers(
          fromUserId: widget.userId,
          toUserId: widget.otherUserId!,
        ),
      );
    } else {
      // Check if we already have the correct data loaded
      final currentState = context.read<PointTransactionBloc>().state;
      if (currentState is LastTransactionsLoaded) {
        print('Already have last transactions, not reloading');
        setState(() {
          _isLoadingData = false;
        });
        return;
      }

      print('Fetching last ${widget.limit} transactions for user ${widget.userId}');
      context.read<PointTransactionBloc>().add(
        FetchLastTransactions(
          userId: widget.userId,
          limit: widget.limit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PointTransactionBloc, PointTransactionState>(
      listener: (context, state) {
        // Update loading state based on bloc state
        if (state is PointTransactionLoading) {
          if (!_isLoadingData) {
            setState(() {
              _isLoadingData = true;
            });
          }
        } else {
          if (_isLoadingData) {
            setState(() {
              _isLoadingData = false;
            });
          }
        }
      },
      child: BlocBuilder<PointTransactionBloc, PointTransactionState>(
        buildWhen: (previous, current) {
          // Only rebuild if the state type changes or if we have new data
          if (previous.runtimeType != current.runtimeType) {
            return true;
          }

          // For between users view
          if (widget.showBetweenUsers) {
            if (current is TransactionsBetweenUsersLoaded && previous is TransactionsBetweenUsersLoaded) {
              // Only rebuild if the data is different
              return current.transactions != previous.transactions;
            }
          } else {
            if (current is LastTransactionsLoaded && previous is LastTransactionsLoaded) {
              // Only rebuild if the data is different
              return current.transactions != previous.transactions;
            }
          }

          return true;
        },
        builder: (context, state) {
          final currentLang = _language.getLanguage();

          // Show loading indicator while loading
          if (state is PointTransactionLoading || _isLoadingData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Process transactions based on state
          List<PointTransaction> transactions = [];

          if (widget.showBetweenUsers) {
            // For between users view, only use TransactionsBetweenUsersLoaded state
            if (state is TransactionsBetweenUsersLoaded) {
              transactions = state.transactions;
            }
          } else {
            // For all transactions view, only use LastTransactionsLoaded state
            if (state is LastTransactionsLoaded) {
              transactions = state.transactions;
            } else if (state is PointTransactionLoaded) {
              // Fallback for regular loaded state
              transactions = state.transactions;
            }
          }

          // Handle error state
          if (state is PointTransactionError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 8),
                    Text(
                      currentLang == 'ar'
                          ? 'حدث خطأ أثناء تحميل المعاملات'
                          : 'Error loading transactions',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _loadTransactions,
                      child: Text(
                        currentLang == 'ar' ? 'إعادة المحاولة' : 'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show empty state if no transactions
          if (transactions.isEmpty) {
            return widget.emptyWidget ?? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      currentLang == 'ar'
                          ? 'لا توجد معاملات'
                          : 'No transactions found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Log what we're displaying
          print('Displaying ${transactions.length} transactions');

          // Show transactions list
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final isHighlighted = widget.highlightTransactionId != null &&
                  transaction.id == widget.highlightTransactionId;
              return _buildTransactionItem(transaction, isHighlighted);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(PointTransaction transaction, bool isHighlighted) {
    final currentLang = _language.getLanguage();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // Format date and time
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final formattedDate = transaction.createdAt != null
        ? dateFormat.format(transaction.createdAt!)
        : '';

    // Determine if this transaction is incoming or outgoing for the current user
    final isIncoming = transaction.isIncoming(widget.userId);

    // Determine icon and color based on transaction type and direction
    IconData transactionIcon;
    Color transactionColor;

    if (transaction.type == 'transfer') {
      if (isIncoming) {
        transactionIcon = Icons.arrow_downward;
        transactionColor = Colors.green;
      } else {
        transactionIcon = Icons.arrow_upward;
        transactionColor = Colors.orange;
      }
    } else if (transaction.type == 'purchase') {
      transactionIcon = Icons.shopping_cart;
      transactionColor = primaryColor;
    } else if (transaction.type == 'admin_grant') {
      transactionIcon = Icons.card_giftcard;
      transactionColor = Colors.purple;
    } else {
      // For 'used' type and any other types
      transactionIcon = Icons.remove_circle_outline;
      transactionColor = Colors.red;
    }

    // Build user info for the transaction - emphasize the other user
    String userInfo = '';
    if (isIncoming && transaction.fromUserId != null) {
      // This transaction is FROM someone else TO the current user
      String fromUserName = transaction.fromUser?.name ?? transaction.fromUserId.toString();
      userInfo = currentLang == 'ar'
          ? 'من: $fromUserName'
          : 'From: $fromUserName';
    } else if (!isIncoming && transaction.toUserId != null) {
      // This transaction is FROM the current user TO someone else
      String toUserName = transaction.toUser?.name ?? transaction.toUserId.toString();
      userInfo = currentLang == 'ar'
          ? 'إلى: $toUserName'
          : 'To: $toUserName';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isHighlighted ? 3 : 1,
      color: isHighlighted ? primaryColor.withOpacity(0.05) : null,
      child: Container(
        decoration: isHighlighted
            ? BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor, width: 1.5),
        )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: transactionColor.withOpacity(0.1),
                child: Icon(transactionIcon, color: transactionColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isIncoming
                                ? (currentLang == 'ar' ? 'استلام نقاط' : 'Received Points')
                                : (currentLang == 'ar' ? 'إرسال نقاط' : 'Sent Points'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isHighlighted ? primaryColor : null,
                            ),
                          ),
                        ),
                        if (isHighlighted)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              currentLang == 'ar' ? 'جديد' : 'New',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (userInfo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        userInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncoming ? '+' : '-'}${transaction.point}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIncoming ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}