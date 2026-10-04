class VerificationResult {
  final bool trashBagVisible;
  final bool collectedWasteVisible;
  final bool plasticWasteVisible;
  final bool cleanupEvidence;
  final bool accepted;
  final String reason;

  const VerificationResult({
    required this.trashBagVisible,
    required this.collectedWasteVisible,
    required this.plasticWasteVisible,
    required this.cleanupEvidence,
    required this.accepted,
    required this.reason,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      trashBagVisible: json['trash_bag_visible'] ?? false,
      collectedWasteVisible: json['collected_waste_visible'] ?? false,
      plasticWasteVisible: json['plastic_waste_visible'] ?? false,
      cleanupEvidence: json['cleanup_evidence'] ?? false,
      accepted: json['accepted'] ?? false,
      reason: json['reason'] ?? 'Açıklama belirtilmedi.',
    );
  }
}