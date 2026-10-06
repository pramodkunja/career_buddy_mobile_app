/// The three writing types `typeSelect` offers
/// (`templates/activities/modules/writing.html:139-143`) and the 10 fixed
/// prompts each cycles through (`static/activities/js/writing.js:8-45`'s
/// `topicsByType` — read verbatim, not reworded, generated, or reordered).
///
/// Unlike AI Speaking's initial topic (confirmed NOT a pool member),
/// Writing's hardcoded initial topic ("Write about one person who inspires
/// you.", `writing.html:137`) genuinely **is** `kWritingTopicsByType['general']`'s
/// first entry — the two features differ here, verified independently
/// rather than assumed identical.
const String kWritingInitialTopic = 'Write about one person who inspires you.';

const String kWritingDefaultType = 'general';

const Map<String, List<String>> kWritingTopicsByType = {
  'general': [
    'Write about one person who inspires you.',
    'Describe your favorite day of the week and why.',
    'Write about a place you want to visit someday.',
    'If you could have dinner with anyone, who would it be and why?',
    'Describe your ideal weekend.',
    'Write about a hobby you enjoy or would like to learn.',
    'Write about your best childhood memory.',
    'Describe the most delicious meal you have ever eaten.',
    'Write a letter to your future self.',
    'What is the best piece of advice you have ever received?',
  ],
  'story': [
    'Write a short story about a lost notebook that teaches a lesson.',
    'Imagine you wake up with a superpower. What happens first?',
    'Write a story where two strangers become best friends.',
    'A mysterious key is found in the garden. Tell the story of what it opens.',
    'You board a train and the train travels to the future.',
    'Write a story about a character who finds a map with no destination.',
    'Two friends discover a hidden room in their new school.',
    'A camping trip takes an unexpected turn when night falls.',
    'An old grandfather clock stops and something strange happens.',
    "Write a story ending with the line: 'And they never went back again.'",
  ],
  'opinion': [
    'Do you think homework should be shorter? Explain your view.',
    'Is learning online better than learning in class? Why?',
    'Should schools have more sports time? Give reasons.',
    'Do you think social media causes more harm than good?',
    'Should students be required to learn a second language?',
    'Is it better to read a book or watch a movie?',
    'Should junk food be banned in school cafeterias? Explain.',
    'Are exams an effective way to test learning?',
    'Do you think video games can be educational? Why or why not?',
    'Is exploring space important or a waste of money?',
  ],
};
