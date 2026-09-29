import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tracking_screen.dart';
import '../../utils/colors.dart';

class TrackingInputScreen extends StatefulWidget {
  const TrackingInputScreen({super.key});

  @override
  State<TrackingInputScreen> createState() => _TrackingInputScreenState();
}

class _TrackingInputScreenState extends State<TrackingInputScreen> {
  final _trackingController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  void _track() {
    final id = _trackingController.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() => _error = 'Please enter your tracking ID.');
      return;
    }
    if (id.length != 8) {
      setState(() => _error = 'Tracking ID must be 8 characters.');
      return;
    }
    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackingScreen(trackingId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Your Repair'),
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.darkGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.track_changes,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),

              const Text(
                'Track Your Repair',
                style: TextStyle(
                    fontSize: AppColors.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the tracking ID from the SMS we sent you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppColors.fontSubtitle, color: AppColors.textGray),
              ),
              const SizedBox(height: 32),

              // Input
              TextField(
                controller: _trackingController,
                textCapitalization: TextCapitalization.characters,
                // Tracking IDs are 8 letters/numbers only — block anything else
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  hintStyle: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 6,
                      color: Color(0xFFD1D5DB)),
                  errorText: _error,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.dark, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
                onSubmitted: (_) => _track(),
              ),
              const SizedBox(height: 20),

              // Track Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _track,
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text(
                    'Track Repair',
                    style: TextStyle(
                        fontSize: AppColors.fontBody,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your tracking ID was sent via SMS after you submitted your repair request.',
                        style:
                            TextStyle(fontSize: AppColors.fontCaption, color: Color(0xFF92400E)),
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
}