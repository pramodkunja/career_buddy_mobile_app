import '../../../../core/utils/exercise_hero_meta.dart';
import 'bingo_card.dart';

/// A Vocabulary Bingo exercise's full card set, extracted from the same
/// server-rendered `exercise_detail` HTML page a browser reads (the
/// `bingo-data` script tag, `bingo_json` — `activities/views.py:1404-1406`)
/// — there is no JSON API for this `exercise_type`.
///
/// [cards] is the **unsliced** full list — mirrors `bingo_json` exactly,
/// which is built from `exercise.bingo_cards.all()` with no `:25` slice
/// (that slice only applies to the on-page HTML board,
/// `templates/activities/exercise.html:269`, `bingo_cards|slice:":25"`).
/// The board shown to the player is the first 25 of [cards]; the *round
/// sequence* (`BingoExerciseController`) shuffles the **full**, unsliced
/// list — so if an exercise has more than 25 cards, some rounds' correct
/// word will not exist on the board at all and can never be answered
/// correctly. This is a genuine, verified quirk of the real web
/// implementation (`static/js/exercises.js:267-281`, `words =
/// BINGO_DATA.slice()`, unsliced), reproduced here rather than "fixed".
///
/// Deliberately carries no `instructions` field — `exercise.instructions`
/// is never rendered anywhere on the web's `exercise.html` page, for any
/// exercise type.
class BingoExercise {
  const BingoExercise({required this.id, required this.title, required this.order, required this.cards, this.heroMeta});

  final int id;
  final String title;
  final int order;
  final List<BingoCard> cards;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found.
  final ExerciseHeroMeta? heroMeta;

  static const boardSize = 25;

  /// The first 25 cards, in their original order — the actual playable
  /// board (`bingo_cards|slice:":25"`).
  List<BingoCard> get board => cards.length <= boardSize ? cards : cards.sublist(0, boardSize);
}
