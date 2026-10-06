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
