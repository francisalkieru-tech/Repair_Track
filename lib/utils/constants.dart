class AppConstants {
  // Repair Status Labels
  static const String statusPending = 'Pending';
  static const String statusAccepted = 'Accepted';
  static const String statusInHome = 'In Home';
  static const String statusInShop = 'In Shop';
  static const String statusInProcess = 'In Process';
  static const String statusWaitingParts = 'Waiting for Parts';
  static const String statusCompleted = 'Completed';
  static const String statusDeclined = 'Declined';

  static const List<String> allStatuses = [
    statusPending,
    statusAccepted,
    statusInHome,
    statusInShop,
    statusInProcess,
    statusWaitingParts,
    statusCompleted,
  ];

  // Appliance Types
  static const List<String> applianceTypes = [
    'Refrigerator',
    'Air Conditioner',
    'Television',
    'Washing Machine',
    'Microwave',
    'Electric Fan',
    'Water Dispenser',
    'Others',
  ];
}