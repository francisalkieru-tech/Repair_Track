import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

// Tracking links in SMS use https so phones make them tappable (a custom
// repairtrack:// link shows as plain text in most SMS apps). With Android App
// Links set up (see hosting/README.md) tapping it opens the app directly; if
// the app is not installed it opens a small fallback page instead.
// To use your own domain later, change only this constant.
const String _kTrackBaseUrl = 'https://repair-tracker-app-e9ace.web.app/track';
String _trackLink(String trackingId) => '$_kTrackBaseUrl/$trackingId';

class SmsService {
  // SMS goes through a small Cloudflare Worker that holds the PhilSMS token
  // as a secret, so no token lives in this app. Paste your Worker URL below
  // (or pass --dart-define=SMS_WORKER_URL=https://...workers.dev).
  // While it's still the placeholder, SMS stays SIMULATED (console only),
  // so the app keeps working without it.
  static const String _workerUrl = String.fromEnvironment(
    'SMS_WORKER_URL',
    defaultValue: 'https://sms-proxy.francisalkieru.workers.dev/',
  );

  bool get _isConfigured =>
      _workerUrl.startsWith('https://') && !_workerUrl.contains('PASTE_');

  // 09171234567 / +639171234567 / 639171234567 -> 639171234567
  String _normalizePh(String raw) {
    var n = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('09') && n.length == 11) n = '63${n.substring(1)}';
    if (n.startsWith('9') && n.length == 10) n = '63$n';
    return n;
  }

  /// Sends one SMS via PhilSMS. Never throws: SMS is best-effort and
  /// must not block saving a status. Returns true if PhilSMS accepted it.
  Future<bool> _send({
    required String to,
    required String message,
    required String label,
  }) async {
    final number = _normalizePh(to);
    if (number.isEmpty) {
      debugPrint('[SMS SKIPPED] $label: no phone number');
      return false;
    }
    if (!_isConfigured) {
      debugPrint('[SMS SIMULATED] $label\nTO: $number\nMESSAGE: $message');
      return false;
    }
    try {
      // The Worker only accepts logged-in users, so send the Firebase token.
      // Timeout so a bad network can't hang here before the HTTP call.
      final idToken = await FirebaseAuth.instance.currentUser
          ?.getIdToken()
          .timeout(const Duration(seconds: 8));
      if (idToken == null) {
        debugPrint('[SMS SKIPPED] $label: not logged in');
        return false;
      }
      final res = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'recipient': number,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final text = utf8.decode(res.bodyBytes);
      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          !text.contains('"status":"error"');
      debugPrint('[SMS ${ok ? 'SENT' : 'FAILED ${res.statusCode}'}] $label '
          'TO: $number ${ok ? '' : text}');
      return ok;
    } catch (e) {
      debugPrint('[SMS ERROR] $label: $e');
      return false;
    }
  }

  // Sent to the CUSTOMER right after they submit a new repair request,
  // with their tracking ID.
  Future<void> sendRequestReceivedSms({
    required String shopName,
    required String contactNumber,
    required String trackingId,
    required String applianceType,
  }) async {
    await _send(
      to: contactNumber,
      message: 'Hello $shopName! We have received your repair request for your '
          '$applianceType. Your tracking ID is $trackingId. '
          'You can track it here: ${_trackLink(trackingId)}',
      label: 'Request Received (to customer)',
    );
  }

  Future<void> sendStatusUpdateSms({
    required String shopName, 
    required String contactNumber,
    required String trackingId,
    required String applianceType,
    required String newStatus,
    String? note,
    String? technician,
    DateTime? scheduledDate,
    String? serviceMode, // 'shop' = On-Site, 'home' = Tech Visit (Accepted text)
  }) async {
    final message = _buildMessage(
      shopName: shopName,
      trackingId: trackingId,
      applianceType: applianceType,
      newStatus: newStatus,
      note: note,
      technician: technician,
      scheduledDate: scheduledDate,
      serviceMode: serviceMode,
    );

    await _send(
      to: contactNumber,
      message: message,
      label: 'Status Update Notification',
    );
  }

  // Notifies the SHOP (not the customer) that a customer has just
  // resolved a pending parts-sourcing decision. Sent to the shop's
  // own contactNumber from shopSettings/config — there is currently
  // no separate "admin phone" field, so the shop's listed contact
  // number doubles as the notification target. Simulated the same
  // way as sendStatusUpdateSms above (no real SMS provider wired up
  // yet — API key is still a placeholder).
  Future<void> sendPartsDecisionAlertToShop({
    required String shopContactNumber,
    required String trackingId,
    required String applianceType,
    required String partsSource,
    String? customerName,
  }) async {
    final who = (customerName != null && customerName.trim().isNotEmpty)
        ? customerName.trim()
        : 'A customer';
    final message = partsSource == 'Customer Supplied'
        ? '$who will supply their own part for $applianceType '
            '(ID: $trackingId). Follow up on when they will bring it in, '
            'then move the job to "In Process" once it arrives.'
        : '$who agreed that the shop will supply the part for '
            '$applianceType (ID: $trackingId). Source the part and move '
            'the job to "In Process" once it is ready.';

    await _send(
      to: shopContactNumber,
      message: message,
      label: 'Parts Decision Notification (to shop)',
    );
  }

  // Notifies the TECHNICIAN that a job has just been assigned to
  // them — sent right after Admin accepts a request and picks a
  // technician in the same step (_ReviewRequestSheet._decide()).
  // Simulated the same way as the other methods here — no real SMS
  // provider wired up yet (API key is still a placeholder), and there
  // is no push-notification infrastructure (no FCM setup) in this
  // app, so this is the closest equivalent available: a message the
  // technician would see if Semaphore were actually connected.
  Future<void> sendJobAssignedSms({
    required String technicianPhoneNumber,
    required String technicianName,
    required String trackingId,
    required String applianceType,
    String? scheduledNote,
  }) async {
    if (technicianPhoneNumber.trim().isEmpty) {
      // No phone number on file for this technician (e.g. added via
      // the quick "Add New Technician" dialog, which doesn't collect
      // one) — nothing to send to, so skip rather than fail.
      debugPrint('[SMS SKIPPED] Job Assigned: no phone number on file '
          'for $technicianName');
      return;
    }

    final buffer = StringBuffer(
      'Hi $technicianName, you have a new job: '
      '$applianceType (ID: $trackingId).',
    );
    if (scheduledNote != null && scheduledNote.isNotEmpty) {
      buffer.write(' $scheduledNote');
    }
    buffer.write(' Open the app for the details.');

    await _send(
      to: technicianPhoneNumber,
      message: buffer.toString(),
      label: 'Job Assigned Notification (to technician)',
    );
  }

  // Notifies the CUSTOMER that Admin opened the 24-hour "who supplies
  // the part" window. This is the one that matters most: without it
  // the customer only finds out by opening the app.
  Future<void> sendPartsDecisionRequestSms({
    required String shopName,
    required String contactNumber,
    required String trackingId,
    required String applianceType,
    required String partDetails,
  }) async {
    await _send(
      to: contactNumber,
      message: '$shopName: Your $applianceType (ID: $trackingId) needs '
          '${partDetails.trim()}. Please open the app within 24 hours and '
          'choose who will supply the part: the shop or you. If we do not '
          'hear from you, the shop will supply it. '
          'Track: ${_trackLink(trackingId)}',
      label: 'Parts Decision Request (to customer)',
    );
  }

  String _buildMessage({
    required String shopName,
    required String trackingId,
    required String applianceType,
    required String newStatus,
    String? note,
    String? technician,
    DateTime? scheduledDate,
    String? serviceMode,
  }) {
    final buffer = StringBuffer();
    final hasTechnician = technician != null && technician.trim().isNotEmpty;
    final cleanNote = (note ?? '').trim();
    var noteUsed = false; // true when the note is already part of the text

    // Old 'In Home' / 'In Shop' values are treated as the new statuses.
    switch (AppConstants.normalizeStatus(newStatus)) {
      case 'Accepted':
        buffer.write(
          '$shopName: Good day! Your repair request (ID: $trackingId) for '
          'your $applianceType has been accepted.',
        );
        if (serviceMode == 'home') {
          buffer.write(
            hasTechnician
                ? ' Technician $technician will make a Tech Visit to your address.'
                : ' Our technician will make a Tech Visit to your address.',
          );
          buffer.write(' We will text you the schedule.');
        } else if (serviceMode == 'shop') {
          buffer.write(' Please bring your $applianceType to the shop (On-Site).');
          if (hasTechnician) {
            buffer.write(' Technician $technician will assist you.');
          }
        } else {
          if (hasTechnician) {
            buffer.write(' Technician $technician will assist you.');
          }
          buffer.write(' We will send you the next steps shortly.');
        }
        break;

      case 'Tech Visit':
        buffer.write('$shopName: Good day! ');
        buffer.write(hasTechnician
            ? 'Technician $technician '
            : 'Our technician ');
        if (scheduledDate != null) {
          buffer.write(
            'will make a Tech Visit to your address on ${_formatSchedule(scheduledDate)} to '
            'repair your $applianceType. Please make sure someone is '
            'available at that time.',
          );
        } else {
          buffer.write('will make a Tech Visit to your address to repair your $applianceType.');
        }
        buffer.write(' (ID: $trackingId)');
        break;

      case 'On-Site':
        buffer.write(
          '$shopName: We have received your $applianceType '
          '(ID: $trackingId) on-site at the shop.',
        );
        if (hasTechnician) {
          buffer.write(' Technician $technician will be checking it.');
        }
        buffer.write(' We will text you once it is ready.');
        break;

      case 'In Process':
        buffer.write(
          '$shopName: We have started repairing your $applianceType '
          '(ID: $trackingId).',
        );
        break;

      case 'Queued':
        buffer.write(
          '$shopName: Your $applianceType (ID: $trackingId) is in the '
          'queue. We will start on it as soon as possible.',
        );
        break;

      case 'Waiting for Parts':
        // The note is the part that is needed.
        final part = cleanNote.isNotEmpty ? cleanNote : 'a replacement part';
        buffer.write(
          '$shopName: Your $applianceType (ID: $trackingId) needs $part to '
          'continue the repair. Please open the app within 24 hours and '
          'choose who will supply the part: the shop or you. If we do not '
          'hear from you, the shop will supply it.',
        );
        noteUsed = true;
        break;

      case 'Completed':
        buffer.write(
          '$shopName: Good news! The repair of your $applianceType '
          '(ID: $trackingId) is complete and ready for pickup. '
          'Thank you for trusting $shopName!',
        );
        break;

      case 'Declined':
        buffer.write(
          '$shopName: We\'re sorry, we are unable to accept your repair '
          'request (ID: $trackingId) for your $applianceType.',
        );
        break;

      default:
        buffer.write(
          '$shopName: Update on your $applianceType (ID: $trackingId): '
          '"$newStatus".',
        );
    }

    if (!noteUsed && cleanNote.isNotEmpty) {
      buffer.write(' Note: $cleanNote.');
    }

    buffer.write(' Track: ${_trackLink(trackingId)}');
    return buffer.toString();
  }

  String _formatSchedule(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day} at $hour:$minute $period';
  }
}