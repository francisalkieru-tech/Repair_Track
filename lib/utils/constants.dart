class AppConstants {
  // Repair Status Labels
  static const String statusPending = 'Pending';
  static const String statusAccepted = 'Accepted';
  // Technician goes to the customer's address (was "In Home").
  static const String statusTechVisit = 'Tech Visit';
  // Customer brings the appliance to the shop (was "In Shop").
  static const String statusOnSite = 'On-Site';
  // Old stored values. Existing Firestore documents may still contain
  // them until the migration (see MIGRATION_NOTE.md) is run; the helpers
  // below treat them as the new statuses so nothing breaks in between.
  static const String legacyInHome = 'In Home';
  static const String legacyInShop = 'In Shop';
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
    statusTechVisit,
    statusOnSite,
    statusQueued,
    statusInProcess,
    statusWaitingParts,
    statusPendingReview,
    statusCompleted,
  ];


  // Maps an old stored status ('In Home' / 'In Shop') to the new one.
  // Any other value is returned unchanged. Use this whenever a status read
  // from Firestore is compared or displayed, so un-migrated data still works.
  static String normalizeStatus(String status) {
    switch (status) {
      case legacyInHome:
        return statusTechVisit;
      case legacyInShop:
        return statusOnSite;
      default:
        return status;
    }
  }

  static bool isTechVisit(String? status) =>
      status != null && normalizeStatus(status) == statusTechVisit;

  static bool isOnSite(String? status) =>
      status != null && normalizeStatus(status) == statusOnSite;

  // Display-only labels ('Queued' is shown as "Waiting to Process").
  static String displayLabel(String status) {
    final s = normalizeStatus(status);
    return s == statusQueued ? 'Waiting to Process' : s;
  }

  // Ticket stage badge used in every dashboard list:
  // Open / In-Process / Waiting for Parts / Completed (+ Declined).
  //  - Open: new request, no technician yet
  //  - In-Process: accepted, assigned and being worked on
  //    (Accepted, Tech Visit, On-Site, Waiting to Process, In Process,
  //    Pending Review)
  static const String stageOpen = 'Open';
  static const String stageInProcess = 'In-Process';
  static const String stageWaitingParts = 'Waiting for Parts';
  static const String stageCompleted = 'Completed';

  static String ticketStage(String status) {
    switch (normalizeStatus(status)) {
      case statusPending:
        return stageOpen;
      case statusWaitingParts:
        return stageWaitingParts;
      case statusCompleted:
        return stageCompleted;
      case statusDeclined:
        return statusDeclined;
      default:
        return stageInProcess;
    }
  }

  // Technician duty status — set by the technician's own Clock In / Clock Out.
  static const String dutyOnDuty = 'on_duty';
  static const String dutyOffDuty = 'off_duty';

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
