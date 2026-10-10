import 'dart:async';
import 'dart:math' show Random;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:http/http.dart' as http;
import '../../utils/troubleshooting_data.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import 'main_nav_screen.dart';
import '../../services/sms_service.dart';


String _newTrackingId() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(8, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}

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
    // Guard against double taps / duplicate requests while still submitting.
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final trackingId = _newTrackingId();
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

      final brand = widget.repairData['brand'];
      if (brand is String && brand.trim().isNotEmpty) {
        docData['brand'] = brand.trim();
      }
      final model = widget.repairData['applianceModel'];
      if (model != null && (model as String).trim().isNotEmpty) {
        docData['applianceModel'] = model.trim();
      }
      if (widget.repairData['photoUrl'] != null) {
        docData['initialPhotoUrl'] = widget.repairData['photoUrl'];
      }
      // Fixed doc ref + set(): add() waits for the server ack, which can hang
      // on a slow network even though the write already reached Firestore
      // (admin sees it, customer stays stuck). We wait max 10s; if the server
      // has not confirmed by then, the SDK keeps the write queued locally and
      // syncs it later, and we tell the customer that instead of claiming
      // it was received.
      final docRef = db.collection('repairRequests').doc(trackingId);
      final writeFuture = docRef.set(docData);
      var confirmed = true;
      try {
        await writeFuture.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        confirmed = false;
      }

      // Best-effort "request received" SMS with the tracking ID. It is only
      // sent once the server has confirmed the write, so a customer never
      // gets a tracking ID by SMS for a request that was rejected. Not
      // awaited so a slow SMS worker can never keep the customer on the
      // loading screen.
      Future<void> sendReceivedSms() async {
        // sendRequestReceivedSms now requires the shop name. Read it from the
        // shop settings; if that fails, fall back so the SMS still goes out.
        var shopName = 'RepairTrack';
        try {
          final shopDoc = await db
              .collection('shopSettings')
              .doc('config')
              .get()
              .timeout(const Duration(seconds: 5));
          final name = (shopDoc.data()?['shopName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) shopName = name;
        } catch (_) {}
        await SmsService().sendRequestReceivedSms(
          shopName: shopName,
          contactNumber:
              (widget.repairData['contactNumber'] as String?) ?? '',
          trackingId: trackingId,
          applianceType:
              (widget.repairData['applianceType'] as String?) ?? 'appliance',
        );
      }
      if (confirmed) {
        unawaited(sendReceivedSms().catchError((_) {}));
      } else {
        // Slow network: send the SMS only after the queued write syncs.
        unawaited(
            writeFuture.then((_) => sendReceivedSms()).catchError((_) {}));
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _trackingId = trackingId;
      });

      if (!confirmed) {
        // Be honest: the server has not confirmed the request yet.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slow connection: your request is saved on this '
                'phone and will be sent automatically once you are online. '
                'Please do not submit it again.'),
            backgroundColor: AppColors.pending,
            duration: Duration(seconds: 8),
          ),
        );
      }
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
      backgroundColor: const Color(0xFFF6F7F9),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(18),
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
            style: TextStyle(
                fontSize: AppColors.fontLabel, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Same card look used across the app
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      );

  // Troubleshooting Steps
  Widget _buildTroubleshootingStep() {
    final step = _steps[_currentStep];
    final model = (widget.repairData['applianceModel'] as String?)?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),

              // Appliance (+ model) on the left, progress count on the right
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
                  if (model != null && model.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppColors.fontLabel,
                            color: AppColors.textGray),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: const TextStyle(
                        fontSize: AppColors.fontLabel,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGray),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar (one segment per step)
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
              const SizedBox(height: 20),

              // Step card: number + title, divider, then the instructions
              Container(
                width: double.infinity,
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.dark,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_currentStep + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppColors.fontBody,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                  fontSize: AppColors.fontSubtitle + 4,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        step.description,
                        style: const TextStyle(
                            fontSize: AppColors.fontBody,
                            color: Color(0xFF4B5563),
                            height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Decision card: did it work?
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Did this step fix your issue?',
                      style: TextStyle(
                          fontSize: AppColors.fontBody,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 14),

                    // Yes: the step already fixed it
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _markResolved,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 20),
                        label: const Text(
                          'Yes, issue resolved!',
                          style: TextStyle(
                              fontSize: AppColors.fontLabel,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // No: next step, or submit once the steps are done
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _nextStep,
                        icon: Icon(
                          _isLastStep ? Icons.send : Icons.arrow_forward,
                          size: 18,
                        ),
                        label: Text(
                          _isLastStep
                              ? 'No, submit repair request'
                              : 'No, try the next step',
                          style: const TextStyle(
                              fontSize: AppColors.fontLabel,
                              fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dark,
                          side: const BorderSide(
                              color: AppColors.dark, width: 1.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Icon(Icons.check,
                    color: AppColors.success, size: 46),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Submitted!',
                style: TextStyle(
                    fontSize: AppColors.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Save your tracking ID to follow your repair.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppColors.fontLabel,
                    color: AppColors.textGray),
              ),
              const SizedBox(height: 22),

              // Tracking ID card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    const Text('YOUR TRACKING ID',
                        style: TextStyle(
                            fontSize: AppColors.fontCaption,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                            color: AppColors.textGray)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _trackingId ?? '',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                              letterSpacing: 3),
                        ),
                        const SizedBox(width: 10),
                        // Copy button: easy to save or share the ID
                        InkWell(
                          onTap: () => _copyTrackingId(context),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Icon(Icons.copy,
                                size: 16, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // SMS note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sms_outlined,
                        size: 20, color: Color(0xFF4B5563)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'We\'ve sent an SMS to your contact number with a link to track your repair status in real time.',
                        style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            height: 1.4,
                            color: Color(0xFF4B5563)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavScreen()),
                    (route) => false,
                  ),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(
                        fontSize: AppColors.fontBody,
                        fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
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