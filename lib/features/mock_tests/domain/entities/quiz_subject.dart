/// One entry of `_QUIZ_SUBJECTS` (`activities/views.py:2201-2206`), paired
/// with the exact display title its own web guide page uses for its exam
/// engine (e.g. `004 dsa-tutorial.html`'s `'<div class="et-title">DSA
/// Mastery — Mock Test</div>'`) — every title below was read directly from
/// its subject's own page, not guessed or derived from the slug.
class QuizSubject {
  const QuizSubject({required this.slug, required this.title});

  final String slug;
  final String title;
}

/// `oop` is deliberately excluded — W020 already covers it via its own
/// dedicated `/activities/oop-quiz/...` endpoint pair (see
/// `OopMasteryMockTestScreen`), not this generic subject family.
const List<QuizSubject> kQuizSubjects = [
  QuizSubject(slug: 'dsa', title: 'DSA Mastery'),
  QuizSubject(slug: 'python', title: 'Python Mastery'),
  QuizSubject(slug: 'claude', title: 'Claude Code'),
  QuizSubject(slug: 'vector', title: 'Vector Databases'),
  QuizSubject(slug: 'nltk', title: 'NLTK & NLP'),
  QuizSubject(slug: 'crewai', title: 'CrewAI'),
  QuizSubject(slug: 'prompt', title: 'Prompt Engineering'),
  QuizSubject(slug: 'dbms', title: 'DBMS'),
  QuizSubject(slug: 'uiux', title: 'UI/UX Mastery'),
  QuizSubject(slug: 'design', title: 'Design Systems Mastery'),
  QuizSubject(slug: 'genai', title: 'GenAI & Agentic AI'),
  QuizSubject(slug: 'devops', title: 'DevOps'),
  QuizSubject(slug: 'blockchain', title: 'Blockchain'),
  QuizSubject(slug: 'quantum', title: 'Quantum Computing'),
  QuizSubject(slug: 'vr', title: 'Virtual Reality'),
  QuizSubject(slug: 'robotics', title: 'Robotics'),
  QuizSubject(slug: 'cyber', title: 'Cybersecurity'),
  QuizSubject(slug: 'ethical', title: 'Ethical Hacking'),
  QuizSubject(slug: 'crypto', title: 'Cryptography'),
  QuizSubject(slug: 'mlops', title: 'MLOps'),
  QuizSubject(slug: 'tensorflow', title: 'TensorFlow & PyTorch'),
  QuizSubject(slug: 'nodejs', title: 'Node.js'),
  QuizSubject(slug: 'aptitude', title: 'Aptitude Mastery'),
  QuizSubject(slug: 'english', title: 'English & Vocab Mastery'),
];
