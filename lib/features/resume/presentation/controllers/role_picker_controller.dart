import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/resume_role.dart';
import '../providers/resume_providers.dart';

/// `RolePickerScreen`'s own state — loading/filtering the catalog only.
/// Confirming a selection ("Resume Parsing & Interview") is a separate,
/// one-shot server call the screen makes directly (see that screen's own
/// doc comment) rather than something this controller tracks, since
/// nothing about the role list itself needs to react to it.
sealed class RolePickerState {
  const RolePickerState();
}

final class RolePickerLoading extends RolePickerState {
  const RolePickerLoading();
}

final class RolePickerLoadFailed extends RolePickerState {
  const RolePickerLoadFailed(this.failure);
  final Failure failure;
}

final class RolePickerLoaded extends RolePickerState {
  const RolePickerLoaded(this.roles, {this.query = '', this.category});
  final List<ResumeRole> roles;
  final String query;

  /// `null` means "every category" — one of [ResumeRole.category]'s real
  /// values (`'it'`/`'tech'`/`'nt'`) otherwise, never an invented one.
  final String? category;

  List<ResumeRole> get filtered {
    var result = roles;
    if (category != null) {
      final wanted = category;
      result = result.where((r) => r.category == wanted).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((r) => r.title.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  RolePickerLoaded copyWith({String? query, String? category, bool clearCategory = false}) {
    return RolePickerLoaded(
      roles,
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

class RolePickerController extends Notifier<RolePickerState> {
  @override
  RolePickerState build() => const RolePickerLoading();

  /// Called once by `RolePickerScreen`'s own `initState` (matching
  /// `ResumeBuilderScreen`'s established `loadParseQuota()`-from-`initState`
  /// pattern) — never self-triggered from [build], since mutating `state`
  /// synchronously within the same call stack as `build()` itself is
  /// unsafe with Riverpod.
  Future<void> load() async {
    state = const RolePickerLoading();
    final result = await ref.read(resumeRepositoryProvider).getRoles();
    state = switch (result) {
      Success(value: final roles) => RolePickerLoaded(roles),
      Failed(failure: final failure) => RolePickerLoadFailed(failure),
    };
  }

  Future<void> retryLoad() => load();

  void setQuery(String query) {
    final current = state;
    if (current is RolePickerLoaded) state = current.copyWith(query: query);
  }

  void setCategory(String? category) {
    final current = state;
    if (current is RolePickerLoaded) {
      state = category == null ? current.copyWith(clearCategory: true) : current.copyWith(category: category);
    }
  }
}
