class BlockModel {
  final String blockerId; // yg ngeblock
  final String blockedId; // yg diblock
  final DateTime? createdAt;

  BlockModel({
    required this.blockerId,
    required this.blockedId,
    this.createdAt,
  });

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      blockerId: map['blocker_id'] as String,
      blockedId: map['blocked_id'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    };
  }
}