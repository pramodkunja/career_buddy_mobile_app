import 'package:flutter/material.dart';

import '../domain/entities/featured_highlight.dart';
import '../domain/entities/skill_up_lesson.dart';
import '../domain/entities/skill_up_section.dart';
import '../domain/entities/skill_up_stat.dart';
import '../domain/entities/skill_up_subsection.dart';

/// Batch 7 — Skill Up hub content, hand-transcribed verbatim from the real
/// `static/001 Career Buddy/index.html` (~3965 lines, plain static HTML —
/// no Django template variables anywhere in it, so every value below is
/// the literal content of the live page, not a placeholder). Line numbers
/// in the comments are from the file as read during this transcription;
/// re-verify against the live file if it's since been edited.
///
/// This is pure constant Dart data (no JSON asset, no network call) —
/// appropriate for a fixed page being hand-transcribed once, unlike
/// Grammar's `GrammarDataSource`, which ports a much larger Python dict.
abstract final class SkillUpData {
  // ============ HERO (`<section class="hero">`, line ~2042) ============

  /// `<span class="pill">…Unified Learning Hub · v3.0</span>` (the
  /// "auto_awesome" icon glyph is dropped, only the visible text kept).
  static const String heroPill = 'Unified Learning Hub · v3.0';

  /// `<h1>One workspace for <span>language, aptitude &amp; tech.</span>
  /// </h1>` — [heroHeadlineHighlight] is the `<span>`-wrapped portion.
  static const String heroHeadline = 'One workspace for ';
  static const String heroHeadlineHighlight = 'language, aptitude & tech.';

  /// `<p class="lede">`.
  static const String heroLede =
      'CareerBuddy bundles 45+ guides, courses, and practice tracks into a single navigable hub — '
      'pick a section, drill three levels deep, open the lesson in place.';

  /// `<div class="hero-actions">` button labels.
  static const String heroPrimaryActionLabel = 'Explore the sitemap';
  static const String heroSecondaryActionLabel = 'Featured tracks';

  /// `<div class="stats">` — 4 tiles.
  static const List<SkillUpStat> heroStats = [
    SkillUpStat(value: '48', label: 'guides & lessons'),
    SkillUpStat(value: '3', label: 'main sections'),
    SkillUpStat(value: '3', label: 'drill-down levels'),
    SkillUpStat(value: '100%', label: 'in one workspace'),
  ];

  // ============ FEATURED (`#section-highlights`, line ~2190) ============

  static const String featuredEyebrow = 'Featured';
  static const String featuredHeadline = 'Start with the most-used tracks';
  static const String featuredSubtitle =
      'The fastest way in — open any of these directly in the in-page viewer below.';
  static const String featuredViewSitemapLabel = 'View full sitemap';

  static const List<FeaturedHighlight> featuredHighlights = [
    FeaturedHighlight(
      icon: Icons.menu_book,
      title: 'CEFR Guide · A1–C2',
      description: 'The Common European Framework, mapped to your CareerBuddy English path.',
      relativePath: '001 CEFR/003 CEFR Guide.html',
      displayTitle: 'CEFR Guide',
    ),
    FeaturedHighlight(
      icon: Icons.psychology,
      title: 'Aptitude · Assessment Syllabus',
      description: 'Recruitment-style coverage across quant, logic, verbal, SJT and cognitive speed.',
      relativePath: 'AptitudeReasoning/Questions/000 aptitude-assessment-syllabus.html',
      displayTitle: 'Aptitude Syllabus',
    ),
    FeaturedHighlight(
      icon: Icons.smart_toy,
      title: 'Tech · GenAI Course Guide',
      description: 'Prompt engineering, agents, RAG, vector DBs — the modern AI stack.',
      relativePath: 'TechCenter/010 genai-course-guide.html',
      displayTitle: 'GenAI Course Guide',
    ),
  ];

  // ======== SECTIONS IN DEPTH (`#section-depth`, line ~2228) ========

  static const String depthEyebrow = 'Sections in depth';
  static const String depthHeadline = 'Browse every lesson, one uniform layout';
  static const String depthSubtitle =
      'Each section, group, and lesson rendered in the CareerBuddy theme. Click any card to open the full '
      'original lesson in the in-page viewer.';
  static const String depthJumpToSitemapLabel = 'Jump to sitemap';

  /// The 3 major sections — identical content backs both the "Sections in
  /// depth" tab (cards) and the Sitemap tab (tree links).
  static const List<SkillUpSection> sections = [
    // ---- 1. ENGLISH & VOCABULARY (`#depth-english` / `#section-english`) ----
    SkillUpSection(
      id: 'depth-english',
      icon: Icons.menu_book,
      title: 'English & Vocabulary',
      tag: 'Language',
      depthDescription:
          'CEFR-aligned English from A1 to C2, a 10-step phonics ladder, vocabulary lexicons, and an '
          'interactive grammar set.',
      sitemapDescription:
          'CEFR-aligned English from A1 to C2, a ten-step phonics ladder, workplace vocabulary lexicons '
          'and an interactive grammar set.',
      subsections: [
        SkillUpSubsection(
          title: 'CEFR levels (A1 → C2)',
          countLabel: '7 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'A1',
              title: 'Elementary · A1',
              description: 'Basic phrases, present tense, everyday vocabulary for survival-level English.',
              relativePath: '001 CEFR/cefr_a1_english.html',
              displayTitle: 'CEFR A1 · Elementary',
            ),
            SkillUpLesson(
              chip: 'A2',
              title: 'Pre-intermediate · A2',
              description: 'Past and future tenses, routine conversations, simple opinions and preferences.',
              relativePath: '001 CEFR/cefr_a2_english.html',
              displayTitle: 'CEFR A2 · Pre-Intermediate',
            ),
            SkillUpLesson(
              chip: 'B1',
              title: 'Intermediate · B1',
              description: 'Workplace English, conditionals, narrative description, basic argumentation.',
              relativePath: '001 CEFR/cefr_b1_english.html',
              displayTitle: 'CEFR B1 · Intermediate',
            ),
            SkillUpLesson(
              chip: 'B2',
              title: 'Upper-intermediate · B2',
              description: 'Abstract topics, fluent discussion, idiomatic range — the interview-ready level.',
              relativePath: '001 CEFR/cefr_b2_english.html',
              displayTitle: 'CEFR B2 · Upper-Intermediate',
            ),
            SkillUpLesson(
              chip: 'C1',
              title: 'Advanced · C1',
              description: 'Nuanced expression, complex texts, professional and academic precision.',
              relativePath: '001 CEFR/cefr_c1_english.html',
              displayTitle: 'CEFR C1 · Advanced',
            ),
            SkillUpLesson(
              chip: 'C2',
              title: 'Mastery · C2',
              description: 'Near-native fluency, subtle register control, idiomatic and stylistic command.',
              relativePath: '001 CEFR/cefr_c2_english.html',
              displayTitle: 'CEFR C2 · Mastery',
            ),
            SkillUpLesson(
              chip: 'Reference',
              chipIsAlt: true,
              title: 'CEFR reference guide',
              description: 'The framework itself — what each level expects, mapped to your CareerBuddy path.',
              relativePath: '001 CEFR/003 CEFR Guide.html',
              displayTitle: 'CEFR Reference Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Phonics series',
          countLabel: '10 lessons',
          lessons: [
            SkillUpLesson(
              chip: '01',
              title: 'Letter sounds',
              description: 'The 44 sounds of English mapped to letters — the foundation of spelling.',
              relativePath: 'Vocabulary/phonics-01-letter-sounds.html',
              displayTitle: 'Phonics 01 · Letter Sounds',
            ),
            SkillUpLesson(
              chip: '02',
              title: 'CVC words',
              description: 'Consonant-vowel-consonant words — the first decodable patterns.',
              relativePath: 'Vocabulary/phonics-02-cvc-words.html',
              displayTitle: 'Phonics 02 · CVC Words',
            ),
            SkillUpLesson(
              chip: '03',
              title: 'Blends & digraphs',
              description: 'Two-letter clusters and the sounds they form together.',
              relativePath: 'Vocabulary/phonics-03-blends-digraphs.html',
              displayTitle: 'Phonics 03 · Blends & Digraphs',
            ),
            SkillUpLesson(
              chip: '04',
              title: 'Long vowels',
              description: 'Magic-e, vowel teams, and the "say-its-name" patterns.',
              relativePath: 'Vocabulary/phonics-04-long-vowels.html',
              displayTitle: 'Phonics 04 · Long Vowels',
            ),
            SkillUpLesson(
              chip: '05',
              title: 'R-controlled vowels',
              description: 'Bossy-R patterns — ar, er, ir, or, ur — that bend vowel sounds.',
              relativePath: 'Vocabulary/phonics-05-r-controlled.html',
              displayTitle: 'Phonics 05 · R-Controlled',
            ),
            SkillUpLesson(
              chip: '06',
              title: 'Compound words',
              description: 'Two short words combining into one — sunlight, notebook, classroom.',
              relativePath: 'Vocabulary/phonics-06-compound-words.html',
              displayTitle: 'Phonics 06 · Compound Words',
            ),
            SkillUpLesson(
              chip: '07',
              title: 'Prefixes',
              description: 'Word-starts that change meaning — un-, re-, dis-, pre-.',
              relativePath: 'Vocabulary/phonics-07-prefixes.html',
              displayTitle: 'Phonics 07 · Prefixes',
            ),
            SkillUpLesson(
              chip: '08',
              title: 'Suffixes',
              description: 'Word-ends that shift part of speech — -tion, -ness, -ful, -ly.',
              relativePath: 'Vocabulary/phonics-08-suffixes.html',
              displayTitle: 'Phonics 08 · Suffixes',
            ),
            SkillUpLesson(
              chip: '09',
              title: 'Greek & Latin roots',
              description: 'Decoding longer words by their classical root families.',
              relativePath: 'Vocabulary/phonics-09-roots.html',
              displayTitle: 'Phonics 09 · Roots',
            ),
            SkillUpLesson(
              chip: '10',
              title: 'Advanced phonics',
              description: 'Schwa, silent letters, and exception patterns for confident decoders.',
              relativePath: 'Vocabulary/phonics-10-advanced.html',
              displayTitle: 'Phonics 10 · Advanced',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Vocabulary & lexicons',
          countLabel: '7 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Drill',
              title: 'Vocabulary activity',
              description: 'Interactive flip-cards and recall drills across thematic topic books.',
              relativePath: 'Vocabulary/vocabulary-activity.html',
              displayTitle: 'Vocabulary Activity',
            ),
            SkillUpLesson(
              chip: 'B1',
              title: 'Vocabulary · CEFR B1',
              description: 'Intermediate word lists tied to B1 outcomes — work, study, travel.',
              relativePath: 'Vocabulary/vocabulary-cefr-b1.html',
              displayTitle: 'Vocabulary · CEFR B1',
            ),
            SkillUpLesson(
              chip: 'B2',
              title: 'Vocabulary · CEFR B2',
              description: 'Upper-intermediate vocabulary for opinion, argument, and abstract topics.',
              relativePath: 'Vocabulary/vocabulary-cefr-b2.html',
              displayTitle: 'Vocabulary · CEFR B2',
            ),
            SkillUpLesson(
              chip: 'C1',
              title: 'Lexicon · C1',
              description: 'Advanced workplace and academic lexicon with collocations and register notes.',
              relativePath: 'Vocabulary/lexicon-c1-vocabulary.html',
              displayTitle: 'Lexicon · C1',
            ),
            SkillUpLesson(
              chip: 'C2',
              title: 'Lexicon · C2',
              description: 'Mastery-level lexicon — nuance, irony, idiom, and stylistic shading.',
              relativePath: 'Vocabulary/lexicon-c2-vocabulary.html',
              displayTitle: 'Lexicon · C2',
            ),
            SkillUpLesson(
              chip: 'Index',
              chipIsAlt: true,
              title: 'Basic vocabulary index',
              description: 'The original starter index for the vocabulary path — kept for reference.',
              relativePath: 'Vocabulary/Basicindex.html',
              displayTitle: 'Vocabulary Basic Index',
            ),
            SkillUpLesson(
              chip: 'Hub',
              chipIsAlt: true,
              title: 'Vocabulary hub',
              description: 'The full vocabulary landing page — phonics, lexicons, and activities together.',
              relativePath: 'Vocabulary/index.html',
              displayTitle: 'Vocabulary Hub',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Grammar',
          countLabel: '1 lesson',
          lessons: [
            SkillUpLesson(
              chip: 'Interactive',
              title: 'Grammar activities',
              description: 'Fill-in-the-blank, reorder, and error-correction drills across levels.',
              relativePath: 'GrammerActivities/grammar-activities (1).html',
              displayTitle: 'Grammar Activities',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Mock test',
          countLabel: '1 assessment',
          lessons: [
            SkillUpLesson(
              chip: '50 questions',
              title: 'English & Vocab Mock Test',
              description: 'Timed English, grammar, vocabulary, and workplace language assessment.',
              relativePath: 'TechCenter/english_vocab_mock_test.html',
              displayTitle: 'English & Vocab Mock Test',
            ),
          ],
        ),
      ],
    ),

    // ---- 2. APTITUDE & REASONING (`#depth-aptitude` / `#section-aptitude`) ----
    SkillUpSection(
      id: 'depth-aptitude',
      icon: Icons.psychology,
      title: 'Aptitude & Reasoning',
      tag: 'Assessment',
      depthDescription:
          'Quant, logical reasoning, verbal ability, situational judgment, cognitive speed — coaching '
          'tracks plus question banks.',
      sitemapDescription:
          'Quant, logical reasoning, verbal ability, situational judgment and cognitive speed — full '
          'coaching tracks plus question banks.',
      subsections: [
        SkillUpSubsection(
          title: 'Quantitative aptitude',
          countLabel: '2 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Coach',
              title: 'Quant aptitude coach',
              description: 'Guided drills across arithmetic, ratios, percentages, and data interpretation.',
              relativePath: 'AptitudeReasoning/Questions/001 Quant Aptitude Coach.html',
              displayTitle: 'Quant Aptitude Coach',
            ),
            SkillUpLesson(
              chip: 'Course',
              title: 'Quantitative aptitude course',
              description: 'The structured course — number systems, geometry, probability and DI banks.',
              relativePath: 'AptitudeReasoning/Questions/002 quantitative-aptitude-course.html',
              displayTitle: 'Quantitative Aptitude Course',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Logical reasoning',
          countLabel: '3 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Course',
              title: 'Logical reasoning · course',
              description: 'Deductive syllogisms, blood relations, seating, and series patterns.',
              relativePath: 'AptitudeReasoning/Questions/001 logical-reasoning-course.html',
              displayTitle: 'Logical Reasoning Course',
            ),
            SkillUpLesson(
              chip: 'Coach',
              title: 'Logical reasoning · coach',
              description: 'Adaptive practice with hints and step-by-step explanations.',
              relativePath: 'AptitudeReasoning/Questions/002 logical_reasoning_coach.html',
              displayTitle: 'Logical Reasoning Coach',
            ),
            SkillUpLesson(
              chip: 'Guide',
              chipIsAlt: true,
              title: 'Logical reasoning · guide',
              description: 'Pattern catalogue and shortcut reference for fast solving.',
              relativePath: 'AptitudeReasoning/Questions/003 logical_reasoning_guide.html',
              displayTitle: 'Logical Reasoning Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Verbal ability',
          countLabel: '1 lesson',
          lessons: [
            SkillUpLesson(
              chip: 'Guide',
              title: 'Verbal ability guide',
              description: 'Comprehension passages, grammar/syntax, and vocabulary-in-context drills.',
              relativePath: 'AptitudeReasoning/Questions/003 verbal_ability_guide.html',
              displayTitle: 'Verbal Ability Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Specialised tests',
          countLabel: '4 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Speed',
              title: 'Cognitive speed ability',
              description: 'Reaction time, pattern matching, and rapid-fire decision drills.',
              relativePath: 'AptitudeReasoning/Questions/004 cognitive_speed_ability.html',
              displayTitle: 'Cognitive Speed Ability',
            ),
            SkillUpLesson(
              chip: 'SJT',
              title: 'Situational judgment test',
              description: 'Workplace scenarios with behavioural scoring — the corporate interview classic.',
              relativePath: 'AptitudeReasoning/Questions/005 sjt_guide.html',
              displayTitle: 'SJT Guide',
            ),
            SkillUpLesson(
              chip: 'AMCAT',
              title: 'AMCAT preparation guide',
              description: 'Adaptive employability test — aptitude, domains, Automata and SVAR, module by module.',
              relativePath: 'TechCenter/021 amcat-guide.html',
              displayTitle: 'AMCAT Guide',
            ),
            SkillUpLesson(
              chip: 'CoCubes',
              title: 'CoCubes preparation guide',
              description: "Aon's campus-hiring test — sectional aptitude, pseudocode, WriteX and SpeX explained.",
              relativePath: 'TechCenter/022 cocubes-guide.html',
              displayTitle: 'CoCubes Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Syllabus & index',
          countLabel: '2 pages',
          lessons: [
            SkillUpLesson(
              chip: 'Syllabus',
              chipIsAlt: true,
              title: 'Aptitude assessment syllabus',
              description: 'The full curriculum map — every topic, weightage, and exam format covered.',
              relativePath: 'AptitudeReasoning/Questions/000 aptitude-assessment-syllabus.html',
              displayTitle: 'Aptitude Assessment Syllabus',
            ),
            SkillUpLesson(
              chip: 'Hub',
              chipIsAlt: true,
              title: 'Aptitude hub landing',
              description: 'Original section landing page with stat ribbon and bento grid.',
              relativePath: 'AptitudeReasoning/index.html',
              displayTitle: 'Aptitude Hub',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Mock test',
          countLabel: '3 assessments',
          lessons: [
            SkillUpLesson(
              chip: '50 questions',
              title: 'Aptitude Mock Test',
              description: 'Timed quantitative aptitude, logical reasoning, and problem-solving assessment.',
              relativePath: 'TechCenter/aptitude_mock_test.html',
              displayTitle: 'Aptitude Mock Test',
            ),
            SkillUpLesson(
              chip: '153 questions',
              title: 'AMCAT Mock Test',
              description: 'Simulated AMCAT exam covering quant, logical, verbal, and domain-specific modules.',
              relativePath: 'TechCenter/amcat_mock_test.html',
              displayTitle: 'AMCAT Mock Test',
            ),
            SkillUpLesson(
              chip: '150 questions',
              title: 'CoCubes Mock Test',
              description: 'Full-length CoCubes practice test with aptitude, coding, and domain assessment sections.',
              relativePath: 'TechCenter/cocubes_mock_test.html',
              displayTitle: 'CoCubes Mock Test',
            ),
          ],
        ),
      ],
    ),

    // ---- 3. TECH CENTER (`#depth-tech` / `#section-tech`) ----
    SkillUpSection(
      id: 'depth-tech',
      icon: Icons.terminal,
      title: 'Tech Center',
      tag: 'Engineering',
      depthDescription:
          'Long-form technical guides — programming, DSA, OOP, databases, AI/ML, agents, vector search, '
          'and design.',
      sitemapDescription:
          'Long-form technical guides — programming foundations, DSA, OOP, databases, AI/ML, agents, '
          'vector search, and design.',
      subsections: [
        SkillUpSubsection(
          title: 'Programming foundations',
          countLabel: '4 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Python',
              title: 'Python learning',
              description: 'From syntax to web frameworks — the practical Python ramp for engineers.',
              relativePath: 'TechCenter/020 python_learning.html',
              displayTitle: 'Python Learning',
            ),
            SkillUpLesson(
              chip: 'DSA',
              title: 'DSA tutorial',
              description: 'Arrays, trees, graphs and algorithms — the interview canon, worked end to end.',
              relativePath: 'TechCenter/004 dsa-tutorial.html',
              displayTitle: 'DSA Tutorial',
            ),
            SkillUpLesson(
              chip: 'OOP',
              title: 'OOP mastery',
              description: 'Encapsulation, inheritance, polymorphism — designing maintainable object models.',
              relativePath: 'TechCenter/005 oop-mastery.html',
              displayTitle: 'OOP Mastery',
            ),
            SkillUpLesson(
              chip: 'Node.js',
              title: 'Node.js course',
              description: 'Server-side JavaScript — event loop, modules, npm, Express APIs and async patterns.',
              relativePath: 'TechCenter/025 nodejs_course.html',
              displayTitle: 'Node.js Course',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'AI · ML · agents',
          countLabel: '7 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'GenAI',
              title: 'GenAI course guide',
              description: 'The modern AI stack — LLMs, prompts, RAG, agents and vector retrieval.',
              relativePath: 'TechCenter/010 genai-course-guide.html',
              displayTitle: 'GenAI Course Guide',
            ),
            SkillUpLesson(
              chip: 'Prompting',
              title: 'Prompt engineering course',
              description: 'Patterns, anti-patterns, and evaluation methods for high-yield LLM prompts.',
              relativePath: 'TechCenter/006 prompt_engineering_course.html',
              displayTitle: 'Prompt Engineering Course',
            ),
            SkillUpLesson(
              chip: 'Agents',
              title: 'CrewAI guide',
              description: 'Multi-agent orchestration with CrewAI — roles, tools, and crews in practice.',
              relativePath: 'TechCenter/003 crewai-guide.html',
              displayTitle: 'CrewAI Guide',
            ),
            SkillUpLesson(
              chip: 'NLP',
              title: 'NLTK NLP tutorial',
              description: 'Classical NLP — tokenisation, POS tagging, parsing, and corpus analysis.',
              relativePath: 'TechCenter/002 nltk_nlp_tutorial.html',
              displayTitle: 'NLTK NLP Tutorial',
            ),
            SkillUpLesson(
              chip: 'Vectors',
              title: 'Vector database notion',
              description: 'Embeddings, similarity search, and the RAG retrieval layer demystified.',
              relativePath: 'TechCenter/001 vector_database_notion.html',
              displayTitle: 'Vector Database Notion',
            ),
            SkillUpLesson(
              chip: 'MLOps',
              title: 'MLOps course',
              description: 'ML lifecycle in production — CI/CD, model registry, serving, monitoring and drift.',
              relativePath: 'TechCenter/023 mlops_course.html',
              displayTitle: 'MLOps Course',
            ),
            SkillUpLesson(
              chip: 'Frameworks',
              title: 'TensorFlow & PyTorch',
              description: 'Deep-learning frameworks side by side — tensors, autograd, training loops and deployment.',
              relativePath: 'TechCenter/024 tensorflow_pytorch_learning.html',
              displayTitle: 'TensorFlow & PyTorch',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Data & systems',
          countLabel: '1 lesson',
          lessons: [
            SkillUpLesson(
              chip: 'DBMS',
              title: 'DBMS study guide',
              description: 'Relational modelling, normalisation, SQL, transactions and indexing.',
              relativePath: 'TechCenter/007 dbms_study_guide.html',
              displayTitle: 'DBMS Study Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Infrastructure & DevOps',
          countLabel: '1 lesson',
          lessons: [
            SkillUpLesson(
              chip: 'DevOps',
              title: 'DevOps guide',
              description: 'CI/CD pipelines, containers & Kubernetes, infrastructure as code, and observability.',
              relativePath: 'TechCenter/011 devops-guide.html',
              displayTitle: 'DevOps Guide',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Design',
          countLabel: '2 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'UI/UX',
              title: 'UI/UX principles · study guide',
              description: 'Hierarchy, contrast, rhythm, affordance — the visual-design fundamentals.',
              relativePath: 'TechCenter/008 UI_UX_Design_Principles_Study_Guide.html',
              displayTitle: 'UI/UX Principles · Study Guide',
            ),
            SkillUpLesson(
              chip: 'Reference',
              chipIsAlt: true,
              title: 'Design classification reference',
              description: 'Taxonomy of design styles, systems, and stylistic decisions across products.',
              relativePath: 'TechCenter/008 design-classification-reference.html',
              displayTitle: 'Design Classification Reference',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Emerging technologies',
          countLabel: '4 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Blockchain',
              title: 'Blockchain',
              description: 'Distributed ledgers, consensus, smart contracts and the Web3 stack.',
              relativePath: 'TechCenter/012 blockchain_learning.html',
              displayTitle: 'Blockchain',
            ),
            SkillUpLesson(
              chip: 'Quantum',
              title: 'Quantum computing',
              description: 'Qubits, superposition, entanglement and the algorithms that exploit them.',
              relativePath: 'TechCenter/013 quantum_computing_learning.html',
              displayTitle: 'Quantum Computing',
            ),
            SkillUpLesson(
              chip: 'VR',
              title: 'Virtual reality',
              description: 'Immersion, tracking, rendering pipelines and interaction design for XR.',
              relativePath: 'TechCenter/014 virtual_reality_learning.html',
              displayTitle: 'Virtual Reality',
            ),
            SkillUpLesson(
              chip: 'Robotics',
              title: 'Robotics',
              description: 'Sense–think–act, kinematics, control, sensors and actuators end to end.',
              relativePath: 'TechCenter/015 robotics_learning.html',
              displayTitle: 'Robotics',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Cybersecurity',
          countLabel: '3 lessons',
          lessons: [
            SkillUpLesson(
              chip: 'Security',
              title: 'Cybersecurity',
              description: 'CIA triad, threats, defence-in-depth, and the core security toolkit.',
              relativePath: 'TechCenter/016 cybersecurity_learning.html',
              displayTitle: 'Cybersecurity',
            ),
            SkillUpLesson(
              chip: 'Pentest',
              title: 'Ethical hacking',
              description: 'Penetration testing — recon, exploitation, and reporting, done legally.',
              relativePath: 'TechCenter/017 ethical_hacking_learning.html',
              displayTitle: 'Ethical Hacking',
            ),
            SkillUpLesson(
              chip: 'Crypto',
              title: 'Cryptography',
              description: 'Symmetric & asymmetric ciphers, hashing, key exchange and protocols.',
              relativePath: 'TechCenter/018 cryptography_course.html',
              displayTitle: 'Cryptography',
            ),
          ],
        ),
        SkillUpSubsection(
          title: 'Reference',
          countLabel: '1 lesson',
          lessons: [
            SkillUpLesson(
              chip: 'Tooling',
              title: 'Claude Code guide',
              description: 'Working with Claude Code — slash commands, hooks, MCP, and agent workflows.',
              relativePath: 'TechCenter/000 claude-code-guide.html',
              displayTitle: 'Claude Code Guide',
            ),
          ],
        ),
      ],
    ),
  ];

  // ============ SITEMAP (`#section-sitemap`, line ~2839) ============

  static const String sitemapEyebrow = 'Site architecture';
  static const String sitemapHeadline = 'Sitemap · 3 levels, fully clickable';
  static const String sitemapSubtitle =
      'Every page in the platform — section › group › lesson. Click any link to open it in the in-page viewer.';
  static const String sitemapSearchPlaceholder =
      "Filter the sitemap — try 'phonics', 'defence', 'python', 'CEFR B1'…";

  /// `<aside class="glance"><h3>Platform at a glance</h3>` — 6 rows.
  static const String glanceTitle = 'Platform at a glance';
  static const List<SkillUpStat> platformStats = [
    SkillUpStat(value: '3', label: 'Main sections'),
    SkillUpStat(value: '3', label: 'Sitemap levels'),
    SkillUpStat(value: '48', label: 'Guides & lessons'),
    SkillUpStat(value: '6', label: 'CEFR levels'),
    SkillUpStat(value: '10', label: 'Phonics lessons'),
    SkillUpStat(value: '23', label: 'Tech tracks'),
  ];
}
