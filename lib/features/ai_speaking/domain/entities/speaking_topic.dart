/// Shown before the user ever taps "New Topic" — hardcoded directly in the
/// Django template (`templates/activities/modules/speaking.html:337`,
/// `<h2 id="topicText">Describe your best experience at the workplace.</h2>`).
/// Confirmed this string is NOT a member of the 20-topic cycling pool below
/// (`static/activities/js/speaking.js`'s `topics` array has no "workplace"
/// entry at all) — so once "New Topic" is tapped even once, this exact
/// prompt can never come back; it is a one-time-only initial value, not
/// entry zero of the pool. Reproduced faithfully, not "fixed".
const String kSpeakingInitialTopic = 'Describe your best experience at the workplace.';

/// The 20 fixed prompts `newTopicBtn` cycles through
/// (`static/activities/js/speaking.js:82-103`, the `topics` array — read
/// verbatim, not reworded, generated, or reordered).
const List<String> kSpeakingTopics = [
  'Describe your best friend in simple words.',
  'Talk about your favourite place at home.',
  'What is your favourite food and why?',
  'Describe your perfect day from morning to night.',
  'What subject do you enjoy the most at school?',
  'Describe your favourite animal and why you like it.',
  'Talk about a game or hobby you love.',
  'Who is your hero and what makes them special?',
  'If you could travel anywhere, where would you go?',
  'Describe a time you helped someone or someone helped you.',
  'Talk about your favourite movie or television show.',
  'What is the best gift you have ever received?',
  'Describe your dream job and why you want it.',
  'Talk about a memorable family holiday.',
  'If you had a million dollars, what would you do first?',
  'Describe a book that you really enjoyed reading.',
  'What do you usually do on the weekends?',
  'Talk about an interesting dream you had recently.',
  'What are three things you cannot live without?',
  "Describe a historical event you'd like to witness.",
];
