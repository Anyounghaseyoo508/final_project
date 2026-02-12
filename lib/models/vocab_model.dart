class Vocabulary {
  final String headword;
  final String cefr;
  final String pos;
  final String translationTH;
  final String definitionTH;
  final String definitionEN;
  final String exampleSentence;
  final String toeicCategory;
  final String synonyms;

  Vocabulary({
    required this.headword,
    required this.cefr,
    required this.pos,
    required this.translationTH,
    required this.definitionTH,
    required this.definitionEN,
    required this.exampleSentence,
    required this.toeicCategory,
    required this.synonyms,
  });

  factory Vocabulary.fromMap(Map<String, dynamic> data) {
    String s(dynamic v) => (v ?? '').toString();

    return Vocabulary(
      headword: s(data['headword']).isEmpty ? 'N/A' : s(data['headword']),
      cefr: s(data['CEFR']).isEmpty ? '-' : s(data['CEFR']),
      pos: s(data['POS']),
      translationTH: s(data['Translation_TH']),
      definitionTH: s(data['Definition_TH']),
      definitionEN: s(data['Definition_EN']),
      exampleSentence: s(data['Example_Sentence']),
      toeicCategory: s(data['TOEIC_Category']),
      synonyms: s(data['Synonyms']),
    );
  }
}
