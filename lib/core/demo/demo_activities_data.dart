/// Fixed, in-memory Activity → SubActivity → Exercise hierarchy used by
/// [DemoActivitiesRepository] and [DemoMcqExerciseRepository] to make the
/// existing navigation/exercise screens exercisable while the real database
/// has zero Activity/SubActivity/Exercise rows. IDs are all in the 9000+
/// range to make it obvious they are demo-only, never real backend ids.
///
/// Only fields that already exist on the real Flutter domain models
/// ([ActivitySummary]/[ActivityDetail]/[SubActivityDetail]/[ExerciseSummary])
/// are populated here — nothing invented.
///
/// Titles/levels/durations/descriptions for the four AI-module demo
/// activities are copied verbatim from the real seed data
/// (`activities/management/commands/setup_professional_modules.py:17-61`
/// — `title`/`level`/`duration`/`objective`, the latter mapped to
/// [DemoActivityFixture.description] the same way `activity_list_api`/
/// `activity_detail_api` map `objective` to their own `description` field,
/// `activities/views.py:799,996`) — **not invented**. Two of the four
/// titles were previously wrong in this fixture ("Professional Writing"
/// instead of the real "Professional Passage Writing", "Professional
/// Listening" instead of the real "Listen & Write") — both still happened
/// to route correctly through `isWritingModuleActivity`/
/// `isListeningModuleActivity`'s substring checks, but displayed a title
/// the production app would never actually show. Corrected here to match
/// the real seed data exactly, per the W012 data-parity audit.
class DemoExerciseFixture {
  const DemoExerciseFixture({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.exerciseTypeDisplay,
    required this.order,
  });

  final int id;
  final String title;
  final String exerciseType;
  final String exerciseTypeDisplay;
  final int order;
}

class DemoSubActivityFixture {
  const DemoSubActivityFixture({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.order,
    required this.exercises,
  });

  final int id;
  final String title;
  final String description;
  final String instructions;
  final int order;
  final List<DemoExerciseFixture> exercises;
}

class DemoActivityFixture {
  const DemoActivityFixture({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryDisplay,
    required this.level,
    required this.duration,
    required this.isWorkshop,
    required this.isModule,
    required this.subActivities,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String categoryDisplay;
  final String level;
  final String duration;
  final bool isWorkshop;
  final bool isModule;
  final List<DemoSubActivityFixture> subActivities;
}

final List<DemoActivityFixture> kDemoActivities = [
  DemoActivityFixture(
    id: 9001,
    title: 'Professional Speaking',
    description: 'Master professional fluency and pronunciation through AI-driven speaking practice.',
    category: 'speaking',
    categoryDisplay: 'Speaking',
    level: 'Intermediate to Advanced',
    duration: '60-90 min',
    isWorkshop: false,
    isModule: true,
    subActivities: [
      DemoSubActivityFixture(
        id: 9101,
        title: 'Speaking Practice',
        description:
            'Record yourself speaking on a given topic and get instant AI feedback on fluency, pronunciation, and grammar.',
        instructions: 'Tap the microphone, speak for at least 20 seconds on the given topic, then submit for analysis.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9201,
            title: 'AI Speaking Exercise',
            exerciseType: 'speaking',
            exerciseTypeDisplay: 'Speaking Practice',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9002,
    title: 'Professional Passage Writing',
    description: 'Improve professional writing skills with real-time AI feedback on grammar, tone, and structure.',
    category: 'writing',
    categoryDisplay: 'Writing',
    level: 'Intermediate to Advanced',
    duration: '45 mins',
    isWorkshop: false,
    isModule: true,
    subActivities: [
      DemoSubActivityFixture(
        id: 9102,
        title: 'Writing Practice',
        description: 'Write a short passage on a given topic and get instant AI feedback on grammar, clarity, and structure.',
        instructions: 'Type at least a few sentences on the given topic, then submit for analysis.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9202,
            title: 'AI Writing Exercise',
            exerciseType: 'writing',
            exerciseTypeDisplay: 'Writing Practice',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9003,
    title: 'Listen & Write',
    description: 'Enhance listening comprehension and transcription accuracy with AI-powered feedback.',
    category: 'listening',
    categoryDisplay: 'Listening',
    level: 'Intermediate',
    duration: '30-45 min',
    isWorkshop: false,
    isModule: true,
    subActivities: [
      DemoSubActivityFixture(
        id: 9103,
        title: 'Listening Practice',
        description: 'Listen to a short story read aloud, then summarize what you heard.',
        instructions: 'Tap play to hear the story, then type a short summary and submit for analysis.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9203,
            title: 'AI Listening Exercise',
            exerciseType: 'listening',
            exerciseTypeDisplay: 'Listening Practice',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9004,
    title: 'Professional Reading',
    description: 'Practice reading aloud and improve pronunciation and pace with AI analysis.',
    category: 'reading',
    categoryDisplay: 'Reading',
    level: 'Beginner',
    duration: '20-30 min',
    isWorkshop: false,
    isModule: true,
    subActivities: [
      DemoSubActivityFixture(
        id: 9104,
        title: 'Reading Practice',
        description: 'Read the given passage aloud and get instant AI feedback on pronunciation and accuracy.',
        instructions: 'Tap the microphone, read the passage aloud, then submit for analysis.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9204,
            title: 'AI Reading Exercise',
            exerciseType: 'reading',
            exerciseTypeDisplay: 'Reading Practice',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9005,
    title: 'Group Discussion',
    description: 'Practice structured group discussion skills on common workplace topics.',
    category: 'workshop',
    categoryDisplay: 'Workshop',
    level: 'Intermediate',
    duration: '20 mins',
    isWorkshop: true,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9105,
        title: 'Group Discussion Session',
        description: 'A guided group discussion practice session.',
        instructions: 'Join a live or simulated group discussion session.',
        order: 1,
        exercises: [],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9006,
    title: 'JAM',
    description: 'Just A Minute — practice speaking spontaneously on a topic for one minute without hesitation.',
    category: 'workshop',
    categoryDisplay: 'Workshop',
    level: 'Intermediate',
    duration: '10 mins',
    isWorkshop: true,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9106,
        title: 'JAM Session',
        description: 'A one-minute impromptu speaking session.',
        instructions: 'Speak for one minute on the given topic without stopping.',
        order: 1,
        exercises: [],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9007,
    title: 'Role Play',
    description: 'Practice real-world workplace scenarios through guided role play.',
    category: 'workshop',
    categoryDisplay: 'Workshop',
    level: 'Intermediate',
    duration: '15 mins',
    isWorkshop: true,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9107,
        title: 'Role Play Session',
        description: 'A guided workplace role-play scenario.',
        instructions: 'Play your assigned role in the given workplace scenario.',
        order: 1,
        exercises: [],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9008,
    title: 'Vocabulary Quiz',
    description: 'Test your professional vocabulary with a short multiple-choice quiz.',
    category: 'vocabulary',
    categoryDisplay: 'Vocabulary',
    level: 'Beginner',
    duration: '5 mins',
    isWorkshop: false,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9108,
        title: 'Vocabulary Practice',
        description: 'A short multiple-choice quiz covering common workplace vocabulary.',
        instructions: 'Answer every question, then submit to see your score.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9205,
            title: 'Vocabulary Quiz Exercise',
            exerciseType: 'mcq',
            exerciseTypeDisplay: 'Multiple Choice',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9009,
    title: 'Vocabulary Matching',
    description: 'Match common workplace abbreviations and idioms to their meanings.',
    category: 'vocabulary',
    categoryDisplay: 'Vocabulary',
    level: 'Beginner',
    duration: '5 mins',
    isWorkshop: false,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9109,
        title: 'Matching Practice',
        description: 'Match each term on the left to its correct definition on the right.',
        instructions: 'Tap a term, then tap its matching definition. Submit once every term is paired.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9206,
            title: 'Workplace Abbreviations Matching',
            exerciseType: 'matching',
            exerciseTypeDisplay: 'Matching',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9010,
    title: 'Vocabulary Bingo',
    description: 'Listen to a definition and click the matching word on your bingo board.',
    category: 'vocabulary',
    categoryDisplay: 'Vocabulary',
    level: 'Beginner',
    duration: '10 mins',
    isWorkshop: false,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9110,
        title: 'Bingo Practice',
        description: 'Press Start, then click the word on your board that matches each definition.',
        instructions: 'Read (or listen to) each definition and click the matching word before moving to the next one.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9207,
            title: 'Workplace Vocabulary Bingo',
            exerciseType: 'bingo',
            exerciseTypeDisplay: 'Vocabulary Bingo',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  DemoActivityFixture(
    id: 9011,
    title: 'Vocabulary Fill in the Blank',
    description: 'Complete each workplace sentence with the correct missing word.',
    category: 'vocabulary',
    categoryDisplay: 'Vocabulary',
    level: 'Beginner',
    duration: '5 mins',
    isWorkshop: false,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9111,
        title: 'Fill in the Blank Practice',
        description: 'Type the missing word for each sentence, then submit once every question has been checked.',
        instructions: 'Type your answer for each question and tap Check. Submit once every question has been checked.',
        order: 1,
        exercises: [
          DemoExerciseFixture(
            id: 9208,
            title: 'Workplace Vocabulary Fill in the Blank',
            exerciseType: 'fill_blank',
            exerciseTypeDisplay: 'Fill in the Blank',
            order: 1,
          ),
        ],
      ),
    ],
  ),
  // W013 — Generic Writing. Copied verbatim from the real seed data
  // (`populate_activities.py`, Activity #2 "Business Negotiation
  // Simulation" → sub-activity #3 "Live Negotiation and Debrief" →
  // exercise "Negotiation Outcome Reflection", `exercise_type: 'writing'`)
  // — not invented, per the W012 data-parity standard.
  DemoActivityFixture(
    id: 9012,
    title: 'Business Negotiation Simulation',
    description:
        'Students practice negotiation strategies, persuasive language, conditional structures, and compromise '
        'techniques in realistic business contexts.',
    category: 'negotiation',
    categoryDisplay: 'Negotiation',
    level: 'Intermediate to Advanced',
    duration: '90–120 min',
    isWorkshop: false,
    isModule: false,
    subActivities: [
      DemoSubActivityFixture(
        id: 9112,
        title: 'Live Negotiation and Debrief',
        description: 'Pairs or groups conduct their negotiation while the instructor circulates.',
        instructions: 'Reflect on your negotiation, covering both writing prompts within their required word count.',
        order: 3,
        exercises: [
          DemoExerciseFixture(
            id: 9209,
            title: 'Negotiation Outcome Reflection',
            exerciseType: 'writing',
            // `EXERCISE_TYPE_CHOICES`'s exact display label
            // (`activities/models.py:26`) — `get_exercise_type_display()`.
            exerciseTypeDisplay: 'Writing Submission',
            order: 1,
          ),
        ],
      ),
    ],
  ),
];
