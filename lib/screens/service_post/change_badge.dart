import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/screens/interaction_widget/point_balance.dart';
import 'package:talabna/screens/profile/purchase_request_screen.dart';
import 'package:talabna/screens/widgets/premium_post_hint.dart'; // Import the premium post hint
import 'package:talabna/screens/widgets/success_widget.dart';

import '../../provider/language.dart';

class ChangeBadge extends StatefulWidget {
  const ChangeBadge(
      {super.key,
      required this.userId,
      required this.servicePostId,
      required this.haveBadge,
      required this.badgeDuration});

  final int userId;
  final int servicePostId;
  final String? haveBadge;
  final int? badgeDuration;

  @override
  State<ChangeBadge> createState() => _ChangeBadgeState();
}

class _ChangeBadgeState extends State<ChangeBadge> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedHaveBadge = widget.haveBadge ?? 'عادي';
  late int _selectedBadgeDuration =
      widget.badgeDuration ?? (_selectedHaveBadge == 'عادي' ? 0 : 1);
  late int _calculatedPoints = 0;
  late bool balanceOut = false;
  final Language _language = Language();

  @override
  void initState() {
    super.initState();
    // Initialize with the current badge and duration
    _selectedHaveBadge = widget.haveBadge ?? 'عادي';
    _selectedBadgeDuration =
        widget.badgeDuration ?? (_selectedHaveBadge == 'عادي' ? 0 : 1);
    _updateCalculatedPoints();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final servicePost = ServicePost(
        id: widget.servicePostId,
        haveBadge: _selectedHaveBadge,
        badgeDuration: _selectedBadgeDuration,
      );
      context.read<ServicePostBloc>().add(ServicePostBadgeUpdateEvent(
          servicePost: servicePost, servicePostID: widget.servicePostId));
    }
  }

  void _updateCalculatedPoints() {
    final int haveBadge = _selectedHaveBadge == 'ذهبي'
        ? 2
        : _selectedHaveBadge == 'ماسي'
            ? 10
            : 0;
    _calculatedPoints = _selectedBadgeDuration * haveBadge;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _language.getLanguage() == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(_language.tChangeBadgeText()),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PointBalance(
                  userId: widget.userId,
                  showBalance: true,
                  canClick: true,
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocListener<ServicePostBloc, ServicePostState>(
        listener: (context, state) {
          if (state is ServicePostOperationSuccess) {
            showCustomSnackBar(context, 'success', type: SnackBarType.success);
            Navigator.of(context).pop();
          } else if (state is ServicePostOperationFailure) {
            bool balance =
                state.errorMessage.contains('Your Balance Point not enough');
            if (balance) {
              setState(() {
                balanceOut = balance;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isArabic
                    ? 'خطأ: رصيد النقاط الخاص بك غير كافٍ'
                    : 'Error: Your Balance Point not enough'),
              ));
            } else {
              showCustomSnackBar(context, 'error', type: SnackBarType.error);
            }
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Badge Selection
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تحديث شارة المنشور' : 'Update Post Badge',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // Badge Type Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: _language.tFeaturedText(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _selectedHaveBadge,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedHaveBadge = newValue!;
                            if (_selectedHaveBadge == 'عادي') {
                              _selectedBadgeDuration = 0;
                            } else if (_selectedBadgeDuration == 0) {
                              _selectedBadgeDuration = 1;
                            }
                            _updateCalculatedPoints();
                          });
                        },
                        items: <String>['عادي', 'ذهبي', 'ماسي']
                            .map<DropdownMenuItem<String>>((String value) {
                          String displayText = value;
                          if (!isArabic) {
                            // Translate badge types for English
                            if (value == 'عادي')
                              displayText = 'Regular';
                            else if (value == 'ذهبي')
                              displayText = 'Golden';
                            else if (value == 'ماسي') displayText = 'Diamond';
                          }

                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(displayText),
                          );
                        }).toList(),
                      ),

                      // Duration Dropdown (only visible for premium badges)
                      if (_selectedHaveBadge != 'عادي') ...[
                        const SizedBox(height: 16.0),
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: isArabic ? 'المدة' : 'Duration',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: _selectedBadgeDuration,
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedBadgeDuration = newValue!;
                              _updateCalculatedPoints();
                            });
                          },
                          items: <int>[1, 2, 3, 4, 5, 6, 7]
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(isArabic
                                  ? '$value يوم'
                                  : '$value ${value == 1 ? 'day' : 'days'}'),
                            );
                          }).toList(),
                        ),

                        // Points information
                        const SizedBox(height: 16.0),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _calculatedPoints > 0
                                ? Colors.amber.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isArabic
                                ? 'ستخصم $_calculatedPoints من رصيد نقاطك عند تمييز النشر بـ $_selectedHaveBadge لمدة $_selectedBadgeDuration ${_selectedBadgeDuration == 1 ? 'يوم' : 'أيام'}'
                                : '$_calculatedPoints points will be deducted when featuring your post with ${_selectedHaveBadge == 'ذهبي' ? 'Golden' : 'Diamond'} badge for $_selectedBadgeDuration ${_selectedBadgeDuration == 1 ? 'day' : 'days'}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Premium Post Hint
              if (_selectedHaveBadge != 'عادي')
                PremiumPostHint(
                  selectedBadgeType: _selectedHaveBadge,
                  userID: widget.userId,
                ),

              // Submit Button
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _language.tChangeBadgeText(),
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              // Insufficient balance message and action
              if (balanceOut) ...[
                const SizedBox(height: 24.0),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isArabic
                            ? 'ليس لديك رصيد نقاط كافٍ، يمكنك شراء النقاط من هنا'
                            : 'You don\'t have enough points. You can purchase points here:',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PurchaseRequestScreen(
                                userID: widget.userId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(
                          isArabic ? 'إضافة نقاط' : 'Add Points',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
