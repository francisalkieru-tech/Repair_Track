class SmsService {
  static const String _apiKey = 'YOUR_SEMAPHORE_API_KEY';
  static const String _senderName = 'REPAIRAPP';

  Future<void> sendStatusUpdateSms({
    required String shopName, 
    required String contactNumber,
    required String trackingId,
    required String applianceType,
    required String newStatus,
    String? note,
    String? technician,
    DateTime? scheduledDate,
  }) async {
    final message = _buildMessage(
      shopName: shopName,
      trackingId: trackingId,
      applianceType: applianceType,
      newStatus: newStatus,
      note: note,
      technician: technician,
      scheduledDate: scheduledDate,
    );

    print('Alert Sms');
    print('[SMS SIMULATED] Status Update Notification');
    print('TO: $contactNumber');
    print('MESSAGE: $message');
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
        ? '$who chose to supply their own part for $applianceType '
            '(ID: $trackingId). Follow up with them on when they\'ll '
            'bring it in, then move the job back to "In Process" once '
            'it arrives.'
        : '$who confirmed the shop will supply the part for '
            '$applianceType (ID: $trackingId). Source the part and '
            'move the job back to "In Process" once it\'s ready.';

    print('Alert Sms');
    print('[SMS SIMULATED] Parts Decision Notification (to shop)');
    print('TO: $shopContactNumber');
    print('MESSAGE: $message');
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
      print('Alert Sms');
      print('[SMS SIMULATED] Job Assigned Notification — SKIPPED');
      print('REASON: no phone number on file for $technicianName');
      return;
    }

    final buffer = StringBuffer(
      'Hi $technicianName, a new job has been assigned to you: '
      '$applianceType (ID: $trackingId).',
    );
    if (scheduledNote != null && scheduledNote.isNotEmpty) {
      buffer.write(' $scheduledNote');
    }
    buffer.write(' Open the app to see the details.');

    print('Alert Sms');
    print('[SMS SIMULATED] Job Assigned Notification (to technician)');
    print('TO: $technicianPhoneNumber');
    print('MESSAGE: ${buffer.toString()}');
  }

  String _buildMessage({
    required String shopName, 
    required String trackingId,
    required String applianceType,
    required String newStatus,
    String? note,
    String? technician,
    DateTime? scheduledDate,
  }) {
    final buffer = StringBuffer();
    final hasTechnician = technician != null && technician.trim().isNotEmpty;

    switch (newStatus) {
      case 'Accepted':
        buffer.write(
          '$shopName: Your repair request (ID: $trackingId) for your '
          '$applianceType has been ACCEPTED.',
        );
        if (hasTechnician) {
          buffer.write(' Technician $technician will be assisting you.');
        }
        break;

      case 'In Home':
        buffer.write('$shopName: ');
        buffer.write(hasTechnician ? 'Technician $technician ' : 'A technician ');
        if (scheduledDate != null) {
          buffer.write(
            'will visit your home on ${_formatSchedule(scheduledDate)} to '
            'repair your $applianceType. Please be available at that time.',
          );
        } else {
          buffer.write('will visit your home to repair your $applianceType.');
        }
        break;

      case 'In Shop':
        buffer.write(
          '$shopName: Your $applianceType (ID: $trackingId) has been '
          'brought to our shop for repair.',
        );
        if (hasTechnician) {
          buffer.write(' Assigned to technician $technician.');
        }
        buffer.write(' We will notify you once it is ready for pickup.');
        break;

      case 'In Process':
        buffer.write(
          '$shopName: Your $applianceType repair (ID: $trackingId) is '
          'now IN PROCESS.',
        );
        break;

      case 'Waiting for Parts':
        buffer.write(
          '$shopName: Your $applianceType repair (ID: $trackingId) is '
          'currently waiting for parts.',
        );
        break;

      case 'Completed':
        buffer.write(
          '$shopName: Great news! Your $applianceType repair '
          '(ID: $trackingId) is now COMPLETE and ready for pickup. '
          'Thank you for trusting $shopName!',
        );
        break;

      case 'Declined':
        buffer.write(
          '$shopName: We\'re sorry, your repair request (ID: $trackingId) '
          'for your $applianceType has been DECLINED.',
        );
        break;

      default:
        buffer.write(
          '$shopName: Your repair (ID: $trackingId) status is now '
          '"$newStatus".',
        );
    }

    if (note != null && note.trim().isNotEmpty) {
      buffer.write(' Note: ${note.trim()}.');
    }

    buffer.write(' Track: repairtrack://track/$trackingId');
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