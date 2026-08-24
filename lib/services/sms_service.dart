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