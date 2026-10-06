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
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Track Your Repair'),
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    gradient: AppColors.darkGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.track_changes,
                      size: 44, color: Colors.white),
                ),
                const SizedBox(height: 20),

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
                      fontSize: AppColors.fontLabel,
                      color: AppColors.textGray),
                ),
                const SizedBox(height: 24),

                // Input + button grouped in one card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tracking ID',
                        style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _trackingController,
                        textCapitalization: TextCapitalization.characters,
                        // Tracking IDs are 8 letters/numbers only
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')),
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
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE1E6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE1E6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.dark, width: 1.6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                        ),
                        onSubmitted: (_) => _track(),
                      ),
                      const SizedBox(height: 18),

                      // Track button (main action)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _track,
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text(
                            'Track Repair',
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
                const SizedBox(height: 14),

                // Info note (neutral style like the other banners)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sms_outlined,
                          color: Color(0xFF4B5563), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your tracking ID was sent via SMS after you submitted your repair request.',
                          style: TextStyle(
                              fontSize: AppColors.fontCaption + 1,
                              height: 1.35,
                              color: Color(0xFF4B5563)),
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
    );
  }
}
