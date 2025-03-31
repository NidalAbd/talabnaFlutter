import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_bloc.dart';
import 'package:talabna/blocs/point_transaction/point_transaction_event.dart';
import 'package:talabna/blocs/purchase_request/purchase_request_bloc.dart';
import 'package:talabna/blocs/purchase_request/purchase_request_event.dart';
import 'package:talabna/blocs/purchase_request/purchase_request_state.dart';
import 'package:talabna/data/models/purchase_request.dart';
import 'package:talabna/screens/interaction_widget/point_balance.dart';
import 'package:talabna/screens/transactions/transaction_list_widget.dart';
import 'package:talabna/screens/transactions/transactions_screen.dart';
import 'package:intl/intl.dart';
import '../../blocs/point_transaction/point_transaction_state.dart';
import '../../provider/language.dart';

class AddPointScreen extends StatefulWidget {
  final int fromUserID;
  final int toUserId;

  const AddPointScreen(
      {Key? key, required this.fromUserID, required this.toUserId})
      : super(key: key);

  @override
  _AddPointScreenState createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final _formKey = GlobalKey<FormState>();
  final Language _language = Language();
  final _pointsController = TextEditingController();
  late PurchaseRequestBloc _purchaseRequestBloc;
  late int? currentUserId = 0;
  bool _isLoading = false;
  PurchaseRequest? _lastTransfer;
  int? _lastTransactionId;
  bool _hasRefreshedAfterSuccess = false;

  // Quick selection points
  final List<int> _quickPoints = [50, 100, 200, 500];

  // Tab controller for transactions
  bool _showUserTransactions = false; // Start with transactions between users

  @override
  void initState() {
    super.initState();
    _purchaseRequestBloc = context.read<PurchaseRequestBloc>();
    _hasRefreshedAfterSuccess = false;
    initializeUserId();

    // Load initial transactions with a slight delay to ensure widgets are built
    Future.microtask(() {
      _loadTransactions();
    });
    print('fromUserID ${widget.fromUserID}');
  }

  void initializeUserId() {
    getUserId().then((userId) {
      setState(() {
        currentUserId = userId;
      });
    });
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  void _selectPoints(int points) {
    setState(() {
      _pointsController.text = points.toString();
    });
  }

  // Simplified toggle function
  void _toggleTransactionsView() {
    setState(() {
      _showUserTransactions = !_showUserTransactions;
    });
    // Clear the current state before loading new data

    context.read<PointTransactionBloc>().add(ClearTransactions());
    // Load the appropriate transactions after state update
    _loadTransactions();
  }

  // Separate method for loading transactions
  void _loadTransactions() {
    if (!mounted) return;

    print(
        'Loading transactions - View mode: ${_showUserTransactions ? "User transactions" : "Between users"}');

    if (_showUserTransactions) {
      context.read<PointTransactionBloc>().add(
            FetchLastTransactions(userId: widget.fromUserID, limit: 5),
          );
    } else {
      // Always force a refresh when viewing transactions between users
      context.read<PointTransactionBloc>().add(
            FetchTransactionsBetweenUsers(
              fromUserId: widget.fromUserID,
              toUserId: widget.toUserId,
            ),
          );
    }
  }

  Widget _buildTransactionsHeader() {
    final currentLang = _language.getLanguage();
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _showUserTransactions
                      ? (currentLang == "ar"
                          ? 'آخر معاملاتك'
                          : 'Your Recent Transactions')
                      : (currentLang == "ar"
                          ? 'المعاملات بينك وبين المستخدم ${widget.toUserId}'
                          : 'Transactions with User ${widget.toUserId}'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: currentLang == "ar"
                    ? 'عرض كل المعاملات'
                    : 'View all transactions',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TransactionsScreen(userId: widget.fromUserID),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Toggle option with better UI
          InkWell(
            onTap: _toggleTransactionsView,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showUserTransactions ? Icons.people_alt : Icons.person,
                    size: 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _showUserTransactions
                        ? (currentLang == "ar"
                            ? 'عرض المعاملات بينكما فقط'
                            : 'Show transactions between us')
                        : (currentLang == "ar"
                            ? 'عرض كل معاملاتك'
                            : 'Show all your transactions'),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return BlocBuilder<PointTransactionBloc, PointTransactionState>(
      builder: (context, state) {
        final currentLang = _language.getLanguage();

        // Create empty placeholder widget
        Widget emptyPlaceholder = Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showUserTransactions ? Icons.history : Icons.swap_horiz,
                size: 64,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 16),
              Text(
                _showUserTransactions
                    ? (currentLang == "ar"
                        ? 'لا توجد معاملات سابقة'
                        : 'No previous transactions')
                    : (currentLang == "ar"
                        ? 'لم تقم بأي معاملات مع هذا المستخدم بعد'
                        : 'No transactions with this user yet'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _showUserTransactions
                    ? (currentLang == "ar"
                        ? 'ستظهر معاملاتك هنا بعد إجراء تحويلات النقاط'
                        : 'Your transactions will appear here after point transfers')
                    : (currentLang == "ar"
                        ? 'حول بعض النقاط لبدء المعاملات مع هذا المستخدم'
                        : 'Transfer some points to start transactions with this user'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );

        // Loading widget
        if (state is PointTransactionLoading) {
          return Container(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionsHeader(),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              constraints: BoxConstraints(
                minHeight: 200,
                maxHeight: 350,
              ),
              child: _showUserTransactions
                  ? TransactionListWidget(
                      userId: widget.fromUserID,
                      limit: 5,
                      emptyWidget: emptyPlaceholder,
                      highlightTransactionId: _lastTransactionId,
                    )
                  : TransactionListWidget(
                      userId: widget.fromUserID,
                      otherUserId: widget.toUserId,
                      showBetweenUsers: true,
                      emptyWidget: emptyPlaceholder,
                      highlightTransactionId: _lastTransactionId,
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_language.tConvertPointsText()),
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PointBalance(
              userId: widget.fromUserID,
              showBalance: false,
              canClick: false,
            ),
          ),
        ],
      ),
      body: BlocListener<PurchaseRequestBloc, PurchaseRequestState>(
        bloc: _purchaseRequestBloc,
        listenWhen: (previous, current) {
          return previous != current;
        },
        listener: (context, state) {
          if (state is PurchaseRequestLoading) {
            setState(() {
              _isLoading = true;
            });
          } else {
            setState(() {
              _isLoading = false;
            });

            if (state is PurchaseRequestSuccess) {
              final currentLang = _language.getLanguage();
              final pointsTransferred = _pointsController.text;

              // Save the purchase request if it exists
              if (state.purchaseRequest != null) {
                setState(() {
                  _lastTransfer = state.purchaseRequest;

                  // Set the transaction ID for highlighting
                  if (state.purchaseRequest?.id != null) {
                    _lastTransactionId = state.purchaseRequest?.id;
                  }
                });
              }

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    currentLang == "ar"
                        ? 'تم تحويل $pointsTransferred نقطة إلى المستخدم ${widget.toUserId}'
                        : 'Successfully transferred $pointsTransferred points to user ${widget.toUserId}',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
              );

              // Store the points value before clearing the controller
              final pointsAmount = pointsTransferred;
              _pointsController.clear();

              // Only refresh transactions once after success
              if (!_hasRefreshedAfterSuccess) {
                _hasRefreshedAfterSuccess = true;

                // Switch to showing transactions between users after a transfer
                setState(() {
                  _showUserTransactions =
                      false; // Show transactions between users
                });

                // Small delay to ensure backend has processed the transaction
                Future.delayed(Duration(milliseconds: 300), () {
                  if (mounted) {
                    // Force refresh transactions between users
                    context.read<PointTransactionBloc>().add(
                          FetchTransactionsBetweenUsers(
                            fromUserId: widget.fromUserID,
                            toUserId: widget.toUserId,
                          ),
                        );
                  }
                });
              }
            } else if (state is PurchaseRequestError) {
              final currentLang = _language.getLanguage();
              final message = currentLang == "ar"
                  ? 'ليس لديك رصيد كافٍ في حسابك'
                  : 'You don\'t have enough balance in your account';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.red.shade700,
                ),
              );

              _pointsController.clear();
            }
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and explanation
                      Text(
                        _language.getLanguage() == "ar"
                            ? 'تحويل النقاط'
                            : 'Transfer Points',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _language.getLanguage() == "ar"
                            ? 'أدخل عدد النقاط التي تريد تحويلها إلى المستخدم.'
                            : 'Enter the number of points you want to transfer to the user.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick selection buttons
                      Text(
                        _language.getLanguage() == "ar"
                            ? 'اختيار سريع:'
                            : 'Quick selection:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _quickPoints
                            .map((points) => ElevatedButton(
                                  onPressed: () => _selectPoints(points),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  child: Text(points.toString()),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),

                      // Points input field
                      TextFormField(
                        controller: _pointsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _language.getLanguage() == "ar"
                              ? 'عدد النقاط'
                              : 'Number of Points',
                          hintText: _language.getLanguage() == "ar"
                              ? 'أدخل عدد النقاط'
                              : 'Enter points amount',
                          prefixIcon: const Icon(Icons.star_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              width: 2,
                            ),
                          ),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _language.getLanguage() == "ar"
                                ? 'يرجى إدخال عدد النقاط'
                                : 'Please enter the number of points';
                          }
                          if (int.tryParse(value) == null) {
                            return _language.getLanguage() == "ar"
                                ? 'يجب إدخال رقم صحيح'
                                : 'Please enter a valid number';
                          }
                          if (int.parse(value) <= 0) {
                            return _language.getLanguage() == "ar"
                                ? 'يجب أن تكون النقاط أكبر من صفر'
                                : 'Points must be greater than zero';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Theme.of(context).primaryColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    // Reset refresh flag before submitting
                                    _hasRefreshedAfterSuccess = false;

                                    final points =
                                        int.parse(_pointsController.text);
                                    context.read<PurchaseRequestBloc>().add(
                                          AddPointsForUser(
                                            request: points,
                                            fromUser: widget.fromUserID,
                                            toUser: widget.toUserId,
                                          ),
                                        );
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _language.getLanguage() == "ar"
                                      ? 'تحويل النقاط'
                                      : 'Transfer Points',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Transactions list section
              _buildTransactionsList(),
            ],
          ),
        ),
      ),
    );
  }
}
