import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/grammar_data_source.dart';
import '../../data/grammar_media_datasource.dart';
import '../../data/grammar_tts_service_impl.dart';
import '../../domain/entities/grammar_topic.dart';
import '../../domain/services/grammar_tts_service.dart';

final grammarDataSourceProvider = Provider<GrammarDataSource>((ref) => GrammarDataSource());

final grammarMediaDataSourceProvider = Provider<GrammarMediaDataSource>((ref) {
  return GrammarMediaDataSource(ref.watch(apiClientProvider));
});

/// On-device TTS for the "Audio Recap" media card
/// (`GrammarAudioPlayerSheet`) — see [GrammarTtsService]'s doc comment.
final grammarTtsServiceProvider = Provider<GrammarTtsService>((ref) => GrammarTtsServiceImpl());

final grammarTopicCardsProvider = FutureProvider<List<GrammarTopicSummary>>((ref) {
  return ref.watch(grammarDataSourceProvider).getTopicCards();
});

final grammarTopicDetailProvider = FutureProvider.family<GrammarTopicDetail, String>((ref, slug) {
  return ref.watch(grammarDataSourceProvider).getTopicDetail(slug);
});

/// The "Lesson slides" section's small per-slide illustration
/// (`ApiEndpoints.subjectIllustration`) — generated fresh server-side on
/// every request, so fetched live rather than bundled like the rest of
/// Grammar's (static) text content.
typedef GrammarIllustrationKey = ({String slug, int index});

final grammarIllustrationSvgProvider = FutureProvider.family<String, GrammarIllustrationKey>(
  (ref, key) => ref.watch(grammarMediaDataSourceProvider).fetchIllustrationSvg(key.slug, key.index),
  // Purely decorative and already degrades gracefully to "not shown" on
  // any failure (see `_SlideIllustration`) — an automatic retry would add
  // a background request with no user-visible benefit.
  retry: (retryCount, error) => null,
);
