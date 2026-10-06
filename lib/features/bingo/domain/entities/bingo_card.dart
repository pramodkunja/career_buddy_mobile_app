/// One `BingoCard` row (`activities/models.py`) — a `word`/`definition`
/// pair. Deliberately just these two fields: the real Django model has no
/// others (`exercise` FK aside), and no `order` field — board order is
/// whatever `bingo_cards.all()`'s default (insertion/pk) order is.
class BingoCard {
  const BingoCard({required this.word, required this.definition});

  final String word;
  final String definition;
}
