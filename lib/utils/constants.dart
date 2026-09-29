class AppConstants {
  // Repair Status Labels
  static const String statusPending = 'Pending';
  static const String statusAccepted = 'Accepted';
  static const String statusInHome = 'In Home';
  static const String statusInShop = 'In Shop';
  // Technician has been assigned but is still busy with another job
  // in their queue — set automatically on assignment when the
  // technician isn't available yet (see technician_availability.dart).
  static const String statusQueued = 'Queued';
  static const String statusInProcess = 'In Process';
  static const String statusWaitingParts = 'Waiting for Parts';
  // Technician has finished the repair on their end, but Admin still
  // needs to confirm it and set warranty terms before it becomes
  // Completed — technician can no longer set Completed directly.
  static const String statusPendingReview = 'Pending Review';
  static const String statusCompleted = 'Completed';
  static const String statusDeclined = 'Declined';

  static const List<String> allStatuses = [
    statusPending,
    statusAccepted,
    statusInHome,
    statusInShop,
    statusQueued,
    statusInProcess,
    statusWaitingParts,
    statusPendingReview,
    statusCompleted,
  ];


  static String displayLabel(String status) =>
      status == statusQueued ? 'Waiting to Process' : status;

  // Waiting for Parts flow — who sources the part
  static const String partsDecisionAwaitingCustomer = 'awaiting_customer';
  static const String partsDecisionDecided = 'decided';
  static const String partsSourceShop = 'Shop Supplied';
  static const String partsSourceCustomer = 'Customer Supplied';
  static const Duration partsDecisionWindow = Duration(hours: 24);

  // Appliance Types
  static const List<String> applianceTypes = [
    'Refrigerator',
    'Air Conditioner',
    'Television',
    'Washing Machine',
    'Microwave',
    'Electric Fan',
    'Water Dispenser',
  ];
}