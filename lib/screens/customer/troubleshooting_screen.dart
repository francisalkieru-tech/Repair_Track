import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../utils/troubleshooting_data.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import 'main_nav_screen.dart';

class TroubleshootingScreen extends StatefulWidget {
  final Map<String, dynamic> repairData;
  const TroubleshootingScreen({super.key, required this.repairData});

  @override
  State<TroubleshootingScreen> createState() => _TroubleshootingScreenState();
}

class _TroubleshootingScreenState extends State<TroubleshootingScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _trackingId;

  List<TroubleshootingStep> get _steps =>
      TroubleshootingData.steps[widget.repairData['applianceType']] ?? [];

  bool get _isLastStep => _currentStep >= _steps.length - 1;

  // Advances to the next step, or opens the submit-confirm dialog
  // once the last step has been reached.
  void _nextStep() {
    if (_isLastStep) {
      _showSubmitConfirmation();
    } else {
      setState(() => _currentStep++);
    }
  }

 
  void _markResolved() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Great News',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * anim1.value,
            sigmaY: 6 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              ),
              child: _ResolvedDialog(
                onBackToHome: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Confirmation dialog shown after all troubleshooting steps are done,
  // asking whether to actually file the repair request.
  void _showSubmitConfirmation() {
    showAppDialog(
      context: context,
      title: 'Submit Repair Request?',
      content: const Text(
        'We\'ve gone through all the troubleshooting steps. Would you like to submit a repair request? You will receive an SMS with a tracking link.',
        style: TextStyle(fontSize: AppColors.fontLabel, color: AppColors.textGray),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Yes, Submit',
          isPrimary: true,
          onPressed: () {
            Navigator.pop(context);
            _submitRequest();
          },
        ),
      ],
    );
  }

  // Writes the repair request to Firestore and generates its tracking ID.
  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final trackingId = const Uuid().v4().substring(0, 8).toUpperCase();
      final db = FirebaseFirestore.instance;

      final docData = <String, dynamic>{
        'customerId': uid,
        'trackingId': trackingId,
        'name': widget.repairData['name'],
        'contactNumber': widget.repairData['contactNumber'],
        'address': widget.repairData['address'],
        'applianceType': widget.repairData['applianceType'],
        'problemDescription': widget.repairData['problemDescription'],
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final model = widget.repairData['applianceModel'];
      if (model != null && (model as String).trim().isNotEmpty) {
        docData['applianceModel'] = model.trim();
      }
      if (widget.repairData['photoUrl'] != null) {
        docData['initialPhotoUrl'] = widget.repairData['photoUrl'];
      }
      await db.collection('repairRequests').add(docData);

      // TEMPORARY — for emulator testing only
// ignore: avoid_print
print('=============================');
// ignore: avoid_print
print('TRACKING ID: $trackingId');
// ignore: avoid_print
print('DEEP LINK: repairtrack://track/$trackingId');
// ignore: avoid_print
print('=============================');

      // Send SMS via Semaphore
      //final contact = widget.repairData['contactNumber'];
      //final message =
        //  'Your repair request has been received! Tracking ID: $trackingId. Track your repair status here: https://repairtrack.app/track/$trackingId';

      //await http.post(
        //Uri.parse('https://api.semaphore.co/api/v4/messages'),
        //body: {
          //'apikey': 'YOUR_SEMAPHORE_API_KEY', // ← replace with actual API key
          //'number': contact,
          //'message': message,
          //'sendername': 'REPAIRAPP',
        //},
      //);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _trackingId = trackingId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isSubmitting
            ? const AppLoadingIndicator(message: 'Submitting your request...')
            : (_isSubmitted
                ? _buildSubmittedScreen()
                : _buildTroubleshootingStep()),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Troubleshooting',
            style: TextStyle(
              fontSize: AppColors.fontTitle,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Quick checks before we proceed with your request',
            style: TextStyle(fontSize: AppColors.fontCaption, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Troubleshooting Steps
  Widget _buildTroubleshootingStep() {
    final step = _steps[_currentStep];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appliance type + step counter
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.repairData['applianceType'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Step ${_currentStep + 1} of ${_steps.length}',
                      style: const TextStyle(
                          fontSize: AppColors.fontCaption, color: AppColors.textGray),
                    ),
                  ],
                ),
                if ((widget.repairData['applianceModel'] as String?)
                        ?.trim()
                        .isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Model: ${widget.repairData['applianceModel']}',
                    style: const TextStyle(
                        fontSize: AppColors.fontCaption, color: AppColors.textGray),
                  ),
                ],
                const SizedBox(height: 12),

                Row(
                  children: List.generate(_steps.length, (i) {
                    final filled = i <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(
                            right: i == _steps.length - 1 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: filled
                              ? AppColors.dark
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Step card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Step ${_currentStep + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppColors.fontCaption,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.title,
                        style: const TextStyle(
                            fontSize: AppColors.fontTitle,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: const TextStyle(
                            fontSize: AppColors.fontBody,
                            color: AppColors.textGray,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'This step resolve your issue?',
                  style: TextStyle(
                      fontSize: AppColors.fontBody,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 12),

                // Yes — the step already fixed it
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _markResolved,
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                    label: const Text(
                      'Yes, issue resolved!',
                      style: TextStyle(
                          fontSize: AppColors.fontLabel,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // No — go to the next step, or submit once steps are done
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _nextStep,
                    icon: Icon(
                      _isLastStep ? Icons.send : Icons.arrow_forward,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _isLastStep
                          ? 'No, Submit repair request'
                          : 'No, Try next Step!',
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Submitted Screen
  void _copyTrackingId(BuildContext context) {
    if (_trackingId == null) return;
    Clipboard.setData(ClipboardData(text: _trackingId!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking ID copied!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSubmittedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dark, width: 2),
              ),
              child: const Icon(Icons.check,
                  color: AppColors.dark, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Request Submitted!',
              style: TextStyle(
                  fontSize: AppColors.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 20),

            // Tracking ID card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Your tracking ID',
                      style: TextStyle(
                          fontSize: AppColors.fontCaption, color: AppColors.textGray)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _trackingId ?? '',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4338CA),
                            letterSpacing: 3),
                      ),
                      const SizedBox(width: 8),
                      // Copy button — para madaling i-share/i-save ng
                      // customer ang tracking ID sa ibang app (hal.
                      // Messenger, Notes) nang hindi mag-tatype manually.
                      GestureDetector(
                        onTap: () => _copyTrackingId(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFD1D5DB)),
                          ),
                          child: const Icon(Icons.copy,
                              size: 16, color: Color(0xFF4338CA)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'ve sent an SMS to your contact number with a link to track your repair status in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppColors.fontLabel, color: AppColors.textGray),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavScreen()),
                  (route) => false,
                ),
                icon: const Icon(Icons.home_outlined, color: Colors.white),
                label: const Text(
                  'Back to Home',
                  style: TextStyle(
                      fontSize: AppColors.fontLabel,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedDialog extends StatelessWidget {
  final VoidCallback onBackToHome;
  const _ResolvedDialog({required this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: const Icon(Icons.check,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Great News !',
              style: TextStyle(
                  fontSize: AppColors.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your issue has been resolved, no repair needed. If the same problem comes back, feel free to submit another repair request.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppColors.fontLabel, color: AppColors.textGray),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBackToHome,
                icon: const Icon(Icons.home_outlined, color: Colors.white),
                label: const Text(
                  'Back to Home',
                  style: TextStyle(
                      fontSize: AppColors.fontLabel,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}