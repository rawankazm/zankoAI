class FlashcardModel {
  final String id;
  final String front;
  final String back;

  FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
    };
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map) {
    return FlashcardModel(
      id: map['id'] ?? '',
      front: map['front'] ?? '',
      back: map['back'] ?? '',
    );
  }
}
