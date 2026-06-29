
class SmsService {
  // TODO: Palitan ng actual Semaphore API key mo kapag meron ka na.
  static const String _apiKey = 'YOUR_SEMAPHORE_API_KEY';
  static const String _senderName = 'REPAIRAPP';

  Future<void> sendStatusUpdateSms({
    required String contactNumber,
    required String trackingId,
    required String applianceType,
    required String newStatus,
    String? note,
    String? technician,
    DateTime? scheduledDate,
  }) async {
    final message = _buildMessage(
      trackingId: trackingId,
      applianceType: applianceType,
      newStatus: newStatus,
      note: note,
      technician: technician,
      scheduledDate: scheduledDate,
    );

    //TEMPORARY: print muna sa terminal para sa testing
    print('=============================');
    print('[SMS SIMULATED] Status Update Notification');
    print('TO: $contactNumber');
    print('MESSAGE: $message');
    print('=============================');

    //uncomment kapag may actual Semaphore API key na
    // final response = await http.post(
    //   Uri.parse('https://api.semaphore.co/api/v4/messages'),
    //   body: {
    //     'apikey': _apiKey,
    //     'number': contactNumber,
    //     'message': message,
    //     'sendername': _senderName,
    //   },
    // );
    // if (response.statusCode != 200) {
    //   throw Exception('Hindi na-send ang SMS: ${response.body}');
    // }
  }

  String _buildMessage({
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
          'RepairTrack: Your repair request (ID: $trackingId) for your '
          '$applianceType has been ACCEPTED.',
        );
        if (hasTechnician) {
          buffer.write(' Technician $technician will be assisting you.');
        }
        break;

      case 'In Home':
        buffer.write('RepairTrack: ');
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
          'RepairTrack: Your $applianceType (ID: $trackingId) has been '
          'brought to our shop for repair.',
        );
        if (hasTechnician) {
          buffer.write(' Assigned to technician $technician.');
        }
        buffer.write(' We will notify you once it is ready for pickup.');
        break;

      case 'In Process':
        buffer.write(
          'RepairTrack: Your $applianceType repair (ID: $trackingId) is '
          'now IN PROCESS.',
        );
        break;

      case 'Waiting for Parts':
        buffer.write(
          'RepairTrack: Your $applianceType repair (ID: $trackingId) is '
          'currently waiting for parts.',
        );
        break;

      case 'Completed':
        buffer.write(
          'RepairTrack: Great news! Your $applianceType repair '
          '(ID: $trackingId) is now COMPLETE and ready for pickup. '
          'Thank you for trusting RepairTrack!',
        );
        break;

      case 'Declined':
        buffer.write(
          'RepairTrack: We\'re sorry, your repair request (ID: $trackingId) '
          'for your $applianceType has been DECLINED.',
        );
        break;

      default:
        buffer.write(
          'RepairTrack: Your repair (ID: $trackingId) status is now '
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