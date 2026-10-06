import 'package:career_buddy_lms/features/activities/data/models/activity_detail_model.dart';
import 'package:career_buddy_lms/features/activities/data/models/activity_list_data_model.dart';
import 'package:career_buddy_lms/features/activities/data/models/sub_activity_detail_model.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validListJson({bool includeActivity = true}) => {
  'activities': [
    if (includeActivity)
      {
        'id': 12,
        'title': 'Business Vocabulary Building Games',
        'description': 'Learn and practice essential business vocabulary.',
        'category': 'vocabulary',
        'category_display': 'Vocabulary & Idioms',
        'level': 'Intermediate',
        'duration': '30 min',
        'is_locked': false,
        'completion_rate': 60,
        'is_completed': false,
      },
  ],
  'categories': [
    {'value': 'speaking', 'label': 'Speaking & Presentation'},
  ],
  'selected_category': '',
  'is_free_preview': false,
  'total_activities': 20,
};

void main() {
  group('ActivityListDataParsing.fromJson', () {
    test('parses a full valid response', () {
      final data = ActivityListDataParsing.fromJson(_validListJson());

      expect(data.activities.single.title, 'Business Vocabulary Building Games');
      expect(data.activities.single.isLocked, isFalse);
      expect(data.categories.single.value, 'speaking');
      expect(data.totalActivities, 20);
    });

    test('parses an empty activities list (category filter with no matches)', () {
      final data = ActivityListDataParsing.fromJson(_validListJson(includeActivity: false));
      expect(data.activities, isEmpty);
    });

    test('throws on a malformed required field', () {
      final json = _validListJson();
      (json['activities'] as List)[0] = {'id': 'not-an-int'};
      expect(() => ActivityListDataParsing.fromJson(json), throwsFormatException);
    });
  });

  group('ActivityDetailParsing.fromJson', () {
    Map<String, dynamic> validJson() => {
      'id': 12,
      'title': 'Business Vocabulary Building Games',
      'description': 'Learn and practice essential business vocabulary.',
      'category': 'vocabulary',
      'category_display': 'Vocabulary & Idioms',
      'level': 'Intermediate',
      'duration': '30 min',
      'is_workshop': false,
      'is_module': false,
      'completion_rate': 50,
      'sub_activities': [
        {
          'id': 34,
          'title': 'Common Business Terms',
          'description': 'desc',
          'order': 1,
          'status': 'in_progress',
          'exercise_count': 2,
          'started_at': '2026-09-01T10:00:00Z',
          'completed_at': null,
        },
      ],
    };

    test('parses a full valid response', () {
      final data = ActivityDetailParsing.fromJson(validJson());

      expect(data.title, 'Business Vocabulary Building Games');
      expect(data.subActivities.single.status, SubActivityStatus.inProgress);
      expect(data.subActivities.single.completedAt, isNull);
    });

    test('parses an activity with no sub-activities', () {
      final json = validJson()..['sub_activities'] = <Map<String, dynamic>>[];
      final data = ActivityDetailParsing.fromJson(json);
      expect(data.subActivities, isEmpty);
    });

    test('throws when a required field is missing', () {
      final json = validJson()..remove('completion_rate');
      expect(() => ActivityDetailParsing.fromJson(json), throwsFormatException);
    });
  });

  group('SubActivityDetailParsing.fromJson', () {
    Map<String, dynamic> validJson() => {
      'id': 34,
      'title': 'Common Business Terms',
      'description': 'desc',
      'instructions': 'instr',
      'order': 1,
      'activity': {'id': 12, 'title': 'Business Vocabulary Building Games'},
      'status': 'in_progress',
      'started_at': '2026-09-01T10:00:00Z',
      'completed_at': null,
      'all_exercises_done': false,
      'exercises': [
        {
          'id': 56,
          'title': 'Vocabulary Quiz',
          'exercise_type': 'mcq',
          'exercise_type_display': 'Multiple Choice',
          'order': 1,
          'last_attempt': {
            'score': 8,
            'max_score': 10,
            'percentage': 80,
            'attempt_number': 1,
            'completed_at': '2026-09-05T09:00:00Z',
          },
        },
        {
          'id': 57,
          'title': 'Fill in the Blanks',
          'exercise_type': 'fill_blank',
          'exercise_type_display': 'Fill in the Blank',
          'order': 2,
          'last_attempt': null,
        },
      ],
    };

    test('parses a full valid response, including a null last_attempt', () {
      final data = SubActivityDetailParsing.fromJson(validJson());

      expect(data.activityId, 12);
      expect(data.activityTitle, 'Business Vocabulary Building Games');
      expect(data.exercises, hasLength(2));
      expect(data.exercises.first.lastAttempt!.score, 8);
      expect(data.exercises.last.lastAttempt, isNull);
    });

    test('parses a sub-activity with no exercises', () {
      final json = validJson()..['exercises'] = <Map<String, dynamic>>[];
      final data = SubActivityDetailParsing.fromJson(json);
      expect(data.exercises, isEmpty);
    });

    test('throws when the nested activity object is missing a required field', () {
      final json = validJson();
      (json['activity'] as Map<String, dynamic>).remove('title');
      expect(() => SubActivityDetailParsing.fromJson(json), throwsFormatException);
    });
  });
}
