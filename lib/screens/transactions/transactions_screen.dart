import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_bloc.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_event.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_state.dart';
import 'package:talabna/data/models/point_transaction.dart';
import 'package:talabna/provider/language.dart';

class TransactionsScreen extends StatefulWidget {
  final int userId;

  const TransactionsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Language _language = Language();
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load transactions when screen opens
    _loadTransactions();
  }

  void _loadTransactions() {
    // Fetch user transactions
    print('load Transactions user Id ${widget.userId}');

    context.read<PointTransactionBloc>().add(
      FetchUserTransactions(userId: widget.userId),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = _language.getLanguage();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.teal : Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentLang == 'ar' ? 'سجل المعاملات' : 'Transactions History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: currentLang == 'ar' ? 'الكل' : 'All'),
            Tab(text: currentLang == 'ar' ? 'مستلمة' : 'Received'),
            Tab(text: currentLang == 'ar' ? 'مرسلة' : 'Sent'),
          ],
        ),
      ),
      body: BlocBuilder<PointTransactionBloc, PointTransactionState>(
        buildWhen: (previous, current) {
          // Only rebuild if state type changes or if we have new data
          if (previous.runtimeType != current.runtimeType) {
            return true;
          }

          if (current is PointTransactionLoaded && previous is PointTransactionLoaded) {
            return current.transactions != previous.transactions;
          }

          if (current is TransactionsBetweenUsersLoaded && previous is TransactionsBetweenUsersLoaded) {
            return current.transactions != previous.transactions;
          }

          return true;
        },
        builder: (context, state) {
          print('Current BlocBuilder state: ${state.runtimeType}');

          // Handle error state
          if (state is PointTransactionError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    currentLang == 'ar'
                        ? 'حدث خطأ أثناء تحميل المعاملات'
                        : 'Error loading transactions',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadTransactions();
                    },
                    child: Text(
                      currentLang == 'ar' ? 'إعادة المحاولة' : 'Retry',
                    ),
                  ),
                ],
              ),
            );
          }

          // Handle loaded state with transactions (both types of loaded states)
          if (state is PointTransactionLoaded || state is TransactionsBetweenUsersLoaded) {
            _isInitialLoad = false;

            // Get transactions from the appropriate state
            final List<PointTransaction> transactions;
            if (state is PointTransactionLoaded) {
              transactions = state.transactions;
            } else if (state is TransactionsBetweenUsersLoaded) {
              transactions = (state).transactions;
            } else {
              transactions = [];
            }

            // If transactions exist, display them
            if (transactions.isNotEmpty) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // All transactions
                  _buildTransactionList(transactions, null),

                  // Received transactions
                  _buildTransactionList(
                      transactions.where((t) => t.isIncoming(widget.userId)).toList(),
                      'received'
                  ),

                  // Sent transactions
                  _buildTransactionList(
                      transactions.where((t) => t.isOutgoing(widget.userId)).toList(),
                      'sent'
                  ),
                ],
              );
            } else {
              // If no transactions, show empty state
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      currentLang == 'ar'
                          ? 'لا توجد معاملات بعد'
                          : 'No transactions yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          // Handle loading state
          if (state is PointTransactionLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Handle other states, including Initial state
          // Force load transactions if needed
          if (_isInitialLoad) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadTransactions();
            });
          }

          // Show a temporary UI while initial data loads
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  currentLang == 'ar'
                      ? 'جارٍ تحميل المعاملات...'
                      : 'Loading transactions...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<PointTransaction> transactions, String? type) {
    final currentLang = _language.getLanguage();

    if (transactions.isEmpty) {
      String message;
      if (type == 'received') {
        message = currentLang == 'ar'
            ? 'لا توجد معاملات مستلمة'
            : 'No received transactions';
      } else if (type == 'sent') {
        message = currentLang == 'ar'
            ? 'لا توجد معاملات مرسلة'
            : 'No sent transactions';
      } else {
        message = currentLang == 'ar'
            ? 'لا توجد معاملات'
            : 'No transactions';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadTransactions();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionCard(transactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionCard(PointTransaction transaction) {
    final currentLang = _language.getLanguage();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.teal : Theme.of(context).primaryColor;
    final surfaceColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    // Determine if this transaction is incoming or outgoing for the current user
    final isIncoming = transaction.isIncoming(widget.userId);
    final isOutgoing = transaction.isOutgoing(widget.userId);

    // Format date and time
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final formattedDate = transaction.createdAt != null
        ? dateFormat.format(transaction.createdAt!)
        : '';

    // Determine icon, color, and sign based on transaction type and direction
    IconData transactionIcon;
    Color transactionColor;
    String transactionTitle;
    bool showPositiveAmount = false;

    if (transaction.type == 'transfer') {
      if (isIncoming) {
        transactionIcon = Icons.arrow_circle_down_rounded;
        transactionColor = Colors.green;
        transactionTitle = currentLang == 'ar'
            ? 'تم استلام نقاط'
            : 'Points Received';
        showPositiveAmount = true;
      } else {
        transactionIcon = Icons.arrow_circle_up_rounded;
        transactionColor = Colors.orange;
        transactionTitle = currentLang == 'ar'
            ? 'تم إرسال نقاط'
            : 'Points Sent';
        showPositiveAmount = false;
      }
    } else if (transaction.type == 'purchase') {
      transactionIcon = Icons.shopping_bag_rounded;
      transactionColor = primaryColor;
      transactionTitle = currentLang == 'ar'
          ? 'شراء نقاط'
          : 'Points Purchase';
      showPositiveAmount = true;
    } else if (transaction.type == 'admin_grant') {
      transactionIcon = Icons.card_giftcard_rounded;
      transactionColor = Colors.purple;
      transactionTitle = currentLang == 'ar'
          ? 'منحة من الإدارة'
          : 'Admin Grant';
      showPositiveAmount = true;
    } else {
      // For 'used' type and any other types
      transactionIcon = Icons.remove_circle_rounded;
      transactionColor = Colors.red;
      transactionTitle = currentLang == 'ar'
          ? 'استخدام نقاط'
          : 'Points Used';
      showPositiveAmount = false;
    }

    // Determine other user name for display
    String otherUserName = '';
    if (isIncoming && transaction.fromUser != null) {
      otherUserName = transaction.fromUser!.name ?? '';
    } else if (isOutgoing && transaction.toUser != null) {
      otherUserName = transaction.toUser!.name ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Optional: Handle card tap to show more details
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Left side - Icon and title
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: transactionColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                            transactionIcon,
                            color: transactionColor,
                            size: 24
                        ),
                      ),
                      SizedBox(width: 16),

                      // Middle - Transaction info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transactionTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            if (otherUserName.isNotEmpty)
                              Text(
                                otherUserName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Right side - Amount
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: showPositiveAmount
                              ? Colors.green.withOpacity(0.12)
                              : Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${showPositiveAmount ? '+' : '-'}${transaction.point}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: showPositiveAmount ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom info section
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date with small icon
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),

                        // Transaction type badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: transactionColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            transaction.getTypeDisplayName(),
                            style: TextStyle(
                              color: transactionColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}