import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../utils/troubleshooting_data.dart';
import 'main_nav_screen.dart';

/// "Basic Troubleshooting" — walks the customer through a few quick
/// checks for their chosen appliance before letting them submit an
/// actual repair request. Shown right after RepairRequestScreen.
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

  // Shows the "Great News!" success dialog when the customer says
  // the current step already fixed the issue.
  void _markResolved() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResolvedDialog(
        onBackToHome: () {
          Navigator.pop(ctx);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavScreen()),
            (route) => false,
          );
        },
      ),
    );
  }

  // Confirmation dialog shown after all troubleshooting steps are done,
  // asking whether to actually file the repair request.
  void _showSubmitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Repair Request?'),
        content: const Text(
          'We\'ve gone through all the troubleshooting steps. Would you like to submit a repair request? You will receive an SMS with a tracking link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Submit',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _trackingId = trackingId;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: _isSubmitted
            ? _buildSubmittedScreen()
            : _buildTroubleshootingStep(),
      ),
    );
  }

  // ── Header (shared black card used by the step screen) ──
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Troubleshooting',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Quick checks before we proceed with your request',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ── Troubleshooting Steps ──
  Widget _buildTroubleshootingStep() {
    final step = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

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
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.repairData['applianceType'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Step ${_currentStep + 1} of ${_steps.length}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Segmented progress bar — one filled block per step reached
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
                              ? Colors.black
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
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Step ${_currentStep + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4B5563),
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'This step resolve your issue?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
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
                      color: const Color(0xFF2563EB),
                    ),
                    label: Text(
                      _isLastStep
                          ? 'No, Submit repair request'
                          : 'No, Try next Step!',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
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

  // ── Submitted Screen ──
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
                border: Border.all(color: const Color(0xFF2563EB), width: 2),
              ),
              child: const Icon(Icons.check,
                  color: Color(0xFF2563EB), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Request Submitted!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
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
                          fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  Text(
                    _trackingId ?? '',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4338CA),
                        letterSpacing: 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'ve sent an SMS to your contact number with a link to track your repair status in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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

/// "Great News!" pop-up dialog shown when a troubleshooting step
/// already resolves the customer's issue (no repair request needed).
class _ResolvedDialog extends StatelessWidget {
  final VoidCallback onBackToHome;
  const _ResolvedDialog({required this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF16A34A), width: 2),
              ),
              child: const Icon(Icons.check,
                  color: Color(0xFF16A34A), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Great News !',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your issue has been resolved, no repair needed. If the same problem comes back, feel free to submit another repair request.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}