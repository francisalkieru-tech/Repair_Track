import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../utils/troubleshooting_data.dart';
import 'home_screen.dart';

class TroubleshootingScreen extends StatefulWidget {
  final Map<String, dynamic> repairData;
  const TroubleshootingScreen({super.key, required this.repairData});

  @override
  State<TroubleshootingScreen> createState() => _TroubleshootingScreenState();
}

class _TroubleshootingScreenState extends State<TroubleshootingScreen> {
  int _currentStep = 0;
  bool _isResolved = false;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _trackingId;

  List<TroubleshootingStep> get _steps =>
      TroubleshootingData.steps[widget.repairData['applianceType']] ?? [];

  bool get _isLastStep => _currentStep >= _steps.length - 1;

  void _nextStep() {
    if (_isLastStep) {
      _showSubmitConfirmation();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _markResolved() {
    setState(() => _isResolved = true);
  }

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

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final trackingId = const Uuid().v4().substring(0, 8).toUpperCase();
      final db = FirebaseFirestore.instance;

      // Save to Firestore
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

      // TEMPORARY — para sa testing sa emulator
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
          //'apikey': 'YOUR_SEMAPHORE_API_KEY', // ← palitan ng actual API key
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
      appBar: AppBar(
        title: const Text('Troubleshooting Guide'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isSubmitted
          ? _buildSubmittedScreen()
          : _isResolved
              ? _buildResolvedScreen()
              : _buildTroubleshootingStep(),
    );
  }

  // ── Troubleshooting Steps ──
  Widget _buildTroubleshootingStep() {
    final step = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Appliance + progress header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_applianceIcon(widget.repairData['applianceType']),
                        size: 14, color: const Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      widget.repairData['applianceType'],
                      style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2563EB)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),

          // Step Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
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
                      color: Color(0xFF111827)),
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
            'Did this step resolve your issue?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),

          // Yes
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _markResolved,
              icon: const Icon(Icons.check_circle_outline,
                  color: Colors.white),
              label: const Text(
                'Yes, issue is resolved!',
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

          // No
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
                    ? 'No — Submit Repair Request'
                    : 'No — Try Next Step',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF2563EB), width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resolved Screen ──
  Widget _buildResolvedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF16A34A), size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Great news!',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your issue has been resolved. No repair request needed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
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

  // ── Submitted Screen ──
  Widget _buildSubmittedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF2563EB), size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Request Submitted!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 12),

            // Tracking ID
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                children: [
                  const Text('Your Tracking ID',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  Text(
                    _trackingId ?? '',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                        letterSpacing: 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'ve sent an SMS to your contact number with a link to track your repair status in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
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

  IconData _applianceIcon(String appliance) {
    switch (appliance) {
      case 'Refrigerator': return Icons.kitchen;
      case 'Air Conditioner': return Icons.ac_unit;
      case 'Television': return Icons.tv;
      case 'Washing Machine': return Icons.local_laundry_service;
      case 'Microwave': return Icons.microwave;
      case 'Electric Fan': return Icons.wind_power;
      case 'Water Dispenser': return Icons.water_drop;
      default: return Icons.devices_other;
    }
  }
}