// GENERATED from live production's static/js/BOTscript.js — do not hand-edit.
// Source: SECTION_CONTEXT (per-page quick-action/recommendation question
// cards), WELCOME_CONTEXT (role-level fallback cards for guest/student/
// employer), and ACTION_DEFINITIONS' label/route/response fields.
import 'entities/aria_welcome_card.dart';

/// One real web page/section's "predefined question" cards — mirrors
/// `SECTION_CONTEXT`. Resolved from the current route by `ariaWelcomeSection()`
/// (`aria_welcome_section.dart`).
const kAriaWelcomeSectionContext = <String, AriaWelcomeCardGroup>{
  'home':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-home-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Which jobs match my profile?', description: 'See your recommended jobs', context: 'Job recommendations are matched to your resume and unlock after a 70 plus score in the AI mock interview.'),
      AriaWelcomeCard(id: 'sec-home-resume', actionKey: 'resume_builder', icon: 'resume', title: 'How good is my resume?', description: 'Get your ATS score', context: 'Upload your resume and Buddy\'s parser will give you an ATS score with clear improvement tips.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-home-rec1', actionKey: 'lessons', icon: 'book', title: 'Would you like to practise English?', description: 'Speaking, writing and listening', context: 'The activities cover speaking, writing, vocabulary and listening, each scored so you can track progress.'),
      AriaWelcomeCard(id: 'sec-home-rec2', actionKey: 'certifications', icon: 'cap', title: 'Interested in a certification?', description: 'Earn one in Skill Up', context: 'Skill Up certifications are earned by scoring 70 percent or more in English, Aptitude or Tech mock tests.'),
    ],
  ),
  'dashboard':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-dash-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Show my job recommendations', description: 'Jump to your matched opportunities', context: 'Your recommended jobs sit on this dashboard, matched to your experience and skills.'),
      AriaWelcomeCard(id: 'sec-dash-act', actionKey: 'lessons', icon: 'book', title: 'Which activity should I do next?', description: 'Continue your activities', context: 'Picking up where you left off in the activities is the fastest way to raise your scores.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-dash-rec1', actionKey: 'resume_builder', icon: 'resume', title: 'Would you like to check your resume score?', description: 'Parse and improve your resume', context: 'A higher ATS score makes your resume easier for recruiters\' systems to find.'),
      AriaWelcomeCard(id: 'sec-dash-rec2', actionKey: 'certifications', icon: 'cap', title: 'Interested in earning a certification?', description: 'Take a Skill Up assessment', context: 'A Skill Up certificate shows employers a verified score in English, Aptitude or Tech.'),
    ],
  ),
  'jobs':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-jobs-interview', actionKey: 'mock_interview', icon: 'interview', title: 'How do I unlock more matches?', description: 'Score 70+ in the AI mock interview', context: 'Scoring 70 or more in the AI mock interview unlocks more job matches for you.'),
      AriaWelcomeCard(id: 'sec-jobs-resume', actionKey: 'resume_builder', icon: 'resume', title: 'Can I improve my resume first?', description: 'Raise your ATS score', context: 'Improving your resume raises your ATS score and the quality of your matches.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-jobs-rec1', actionKey: 'communication', icon: 'users', title: 'Would you like to sharpen your communication?', description: 'Professional Communication activities', context: 'Clear professional communication helps you stand out in applications and interviews.'),
      AriaWelcomeCard(id: 'sec-jobs-rec2', actionKey: 'aptitude', icon: 'chart', title: 'Interested in aptitude practice?', description: 'Common in hiring tests', context: 'Many hiring tests include aptitude rounds, so practice here gives you an edge.'),
    ],
  ),
  'profile':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-prof-dash', actionKey: 'profile', icon: 'user', title: 'How is my progress?', description: 'Open your dashboard', context: 'Your dashboard shows completed activities, total score and recommended jobs.'),
      AriaWelcomeCard(id: 'sec-prof-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Which jobs fit my profile?', description: 'See your recommended jobs', context: 'Jobs are matched using your resume and your interview score.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-prof-rec1', actionKey: 'resume_builder', icon: 'resume', title: 'Would you like to update your resume?', description: 'Re-check your ATS score', context: 'Re-checking your resume after changes shows how your ATS score improves.'),
      AriaWelcomeCard(id: 'sec-prof-rec2', actionKey: 'pro', icon: 'sparkle', title: 'Interested in Pro features?', description: 'Mock interviews and job matches', context: 'Pro unlocks the AI technical interview and unlimited matched job recommendations.'),
    ],
  ),
  'pro':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-pro-interview', actionKey: 'mock_interview', icon: 'interview', title: 'What is the AI mock interview?', description: 'Practise and get scored', context: 'The AI mock interview asks questions based on your resume and scores every answer.'),
      AriaWelcomeCard(id: 'sec-pro-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'How do job recommendations work?', description: 'Matched after a 70+ interview score', context: 'After a 70 plus interview score, you get jobs matched to your experience and skills.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-pro-rec1', actionKey: 'profile', icon: 'user', title: 'Would you like to go back to your dashboard?', description: 'Track your progress', context: 'Your dashboard keeps track of everything you have done so far.'),
      AriaWelcomeCard(id: 'sec-pro-rec2', actionKey: 'lessons', icon: 'book', title: 'Interested in the free activities?', description: 'Practise English skills', context: 'The free plan still includes grammar lessons and an activity to get you started.'),
    ],
  ),
  'activities':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-act-speaking', actionKey: 'professional_speaking', icon: 'interview', title: 'How can I improve my speaking?', description: 'Speaking & Presentation', context: 'Speaking and Presentation activities give you instant feedback on clarity, fluency and confidence.'),
      AriaWelcomeCard(id: 'sec-act-writing', actionKey: 'passage_writing', icon: 'resume', title: 'How do I write better emails?', description: 'Writing & Correspondence', context: 'Writing and Correspondence trains you to write clear emails, letters and reports.'),
      AriaWelcomeCard(id: 'sec-act-listen', actionKey: 'listen_learn', icon: 'book', title: 'Can I practise listening?', description: 'Listen & Learn', context: 'Listen and Learn uses audio exercises to sharpen your listening comprehension.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-act-rec1', actionKey: 'workshop', icon: 'users', title: 'Would you like to join a workshop?', description: 'Group Discussion, JAM and Role Play', context: 'Workshops include Group Discussion, JAM and Role Play with AI participants.'),
      AriaWelcomeCard(id: 'sec-act-rec2', actionKey: 'certifications', icon: 'cap', title: 'Interested in a certification?', description: 'Earn one from the Skill Up module', context: 'Skill Up certifications prove your level with a verified mock test score.'),
    ],
  ),
  'workshop':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-ws-gd', actionKey: 'gd', icon: 'users', title: 'How does Group Discussion work?', description: 'Debate with AI participants', context: 'In Group Discussion you debate a topic with AI participants and get scored on your points.'),
      AriaWelcomeCard(id: 'sec-ws-jam', actionKey: 'jam', icon: 'interview', title: 'What is JAM?', description: 'Just A Minute speaking drill', context: 'JAM means Just A Minute: you speak on a topic for sixty seconds without hesitation.'),
      AriaWelcomeCard(id: 'sec-ws-rp', actionKey: 'roleplay', icon: 'users', title: 'Can I practise a workplace scenario?', description: 'Role Play', context: 'Role Play puts you in real workplace scenarios like meetings and client calls.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-ws-rec1', actionKey: 'mock_interview', icon: 'interview', title: 'Would you like a mock interview?', description: 'Get scored by the AI interviewer', context: 'The AI mock interview scores your answers and can unlock job matches.'),
      AriaWelcomeCard(id: 'sec-ws-rec2', actionKey: 'lessons', icon: 'book', title: 'Interested in more activities?', description: 'Back to the activities list', context: 'The activities list has speaking, writing, vocabulary and listening practice.'),
    ],
  ),
  'grammar':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-gr-tenses', actionKey: 'grammar_tenses', icon: 'book', title: 'How do tenses work?', description: 'Open the Tenses module', context: 'Tenses show when an action happens: past, present or future, each with simple, continuous and perfect forms.'),
      AriaWelcomeCard(id: 'sec-gr-struct', actionKey: 'grammar_sentence_structure', icon: 'resume', title: 'How do I build correct sentences?', description: 'Sentence Structure', context: 'A correct sentence needs a subject and a verb, and the Sentence Structure module shows how to build on that.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-gr-rec1', actionKey: 'english_vocab', icon: 'cap', title: 'Would you like to test your English?', description: 'Take the English assessment', context: 'The English assessment in Skill Up measures your level and can earn you a certificate.'),
      AriaWelcomeCard(id: 'sec-gr-rec2', actionKey: 'passage_writing', icon: 'resume', title: 'Interested in writing practice?', description: 'Apply grammar in writing', context: 'Writing practice is the best way to put grammar rules to real use.'),
    ],
  ),
  'resume':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-res-interview', actionKey: 'mock_interview', icon: 'interview', title: 'Can I practise an interview?', description: 'Start the AI mock interview', context: 'The AI mock interview uses your resume to ask relevant questions and score your answers.'),
      AriaWelcomeCard(id: 'sec-res-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Which jobs match my resume?', description: 'See your recommended jobs', context: 'Once your interview score is 70 or more, jobs matching your resume appear on your dashboard.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-res-rec1', actionKey: 'profile', icon: 'user', title: 'Would you like to see your dashboard?', description: 'Track your progress and scores', context: 'Your dashboard brings your resume score, activity progress and jobs together.'),
      AriaWelcomeCard(id: 'sec-res-rec2', actionKey: 'english_vocab', icon: 'book', title: 'Interested in improving your English?', description: 'Strengthen your communication', context: 'Stronger English helps you present your resume and answer interviews with confidence.'),
    ],
  ),
  'skillup':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-su-english', actionKey: 'english_vocab', icon: 'book', title: 'Where do I start with English?', description: 'English & Vocabulary', context: 'English and Vocabulary is the best starting point, with guides and a mock test.'),
      AriaWelcomeCard(id: 'sec-su-aptitude', actionKey: 'aptitude', icon: 'chart', title: 'How do I prepare for aptitude tests?', description: 'AMCAT, CoCubes and mocks', context: 'Aptitude and Reasoning covers AMCAT and CoCubes style questions with timed mocks.'),
      AriaWelcomeCard(id: 'sec-su-tech', actionKey: 'tech', icon: 'code', title: 'What tech topics are covered?', description: 'Python, DSA, DBMS and more', context: 'The Tech Center covers Python, data structures, databases and more.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-su-rec1', actionKey: 'certifications', icon: 'cap', title: 'Would you like to see your certifications?', description: 'What you have earned so far', context: 'Your certifications page shows each module\'s status and lets you download certificates.'),
      AriaWelcomeCard(id: 'sec-su-rec2', actionKey: 'mock_interview', icon: 'interview', title: 'Interested in a mock interview?', description: 'Practise with the AI interviewer', context: 'The AI mock interview is a great next step once your skills are sharp.'),
    ],
  ),
  'skillup_english':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-sue-cert', actionKey: 'certifications', icon: 'cap', title: 'How do I get an English certificate?', description: 'Score 70%+ in the mock test', context: 'Score 70 percent or more in the English mock test to earn your English certificate.'),
      AriaWelcomeCard(id: 'sec-sue-vocab', actionKey: 'vocabulary', icon: 'book', title: 'Can I practise vocabulary activities?', description: 'Vocabulary & Idioms', context: 'Vocabulary and Idioms activities help you use business words naturally.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-sue-rec1', actionKey: 'aptitude', icon: 'chart', title: 'Would you like to try aptitude next?', description: 'Aptitude & Reasoning', context: 'Aptitude is a common round in hiring tests, so it\'s a good next step.'),
      AriaWelcomeCard(id: 'sec-sue-rec2', actionKey: 'grammar', icon: 'resume', title: 'Interested in grammar lessons?', description: 'Nouns, verbs, tenses and more', context: 'The Grammar library covers nouns, verbs, tenses and sentence structure.'),
    ],
  ),
  'skillup_aptitude':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-sua-cert', actionKey: 'certifications', icon: 'cap', title: 'How do I get an aptitude certificate?', description: 'Score 70%+ in the mock test', context: 'Score 70 percent or more in the Aptitude mock test to earn your Aptitude certificate.'),
      AriaWelcomeCard(id: 'sec-sua-all', actionKey: 'browse_all', icon: 'chart', title: 'What else can I practise here?', description: 'Browse all Skill Up tracks', context: 'Skill Up also has English and Tech tracks alongside Aptitude.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-sua-rec1', actionKey: 'tech', icon: 'code', title: 'Would you like to explore the Tech Center?', description: 'Python, DSA, DBMS and more', context: 'The Tech Center adds programming and computer science topics to your preparation.'),
      AriaWelcomeCard(id: 'sec-sua-rec2', actionKey: 'english_vocab', icon: 'book', title: 'Interested in English & Vocabulary?', description: 'Take the English assessment', context: 'English and Vocabulary strengthens the communication side of your profile.'),
    ],
  ),
  'skillup_tech':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-sut-cert', actionKey: 'certifications', icon: 'cap', title: 'How do I get a tech certificate?', description: 'Score 70%+ in the mock test', context: 'Score 70 percent or more in the Tech mock test to earn your Tech certificate.'),
      AriaWelcomeCard(id: 'sec-sut-all', actionKey: 'browse_all', icon: 'code', title: 'Which tech guides are available?', description: 'Browse all Skill Up tracks', context: 'Browse all shows every guide across English, Aptitude and Tech.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-sut-rec1', actionKey: 'mock_interview', icon: 'interview', title: 'Would you like a technical mock interview?', description: 'Practise with the AI interviewer', context: 'The AI technical interview tests what you\'ve learned with real interview questions.'),
      AriaWelcomeCard(id: 'sec-sut-rec2', actionKey: 'aptitude', icon: 'chart', title: 'Interested in aptitude practice?', description: 'Aptitude & Reasoning', context: 'Aptitude practice complements your technical preparation for placement tests.'),
    ],
  ),
  'skillup_certs':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-suc-english', actionKey: 'english_vocab', icon: 'book', title: 'How do I earn the English certificate?', description: 'English & Vocabulary', context: 'The English certificate needs a 70 percent score in the English mock test.'),
      AriaWelcomeCard(id: 'sec-suc-aptitude', actionKey: 'aptitude', icon: 'chart', title: 'How do I earn the aptitude certificate?', description: 'Aptitude & Reasoning', context: 'The Aptitude certificate needs a 70 percent score in the Aptitude mock test.'),
      AriaWelcomeCard(id: 'sec-suc-tech', actionKey: 'tech', icon: 'code', title: 'How do I earn the tech certificate?', description: 'Tech Center', context: 'The Tech certificate needs a 70 percent score in the Tech mock test.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-suc-rec1', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Would you like to see matched jobs?', description: 'Your recommended jobs', context: 'Your matched jobs are on the dashboard once your interview score reaches 70.'),
      AriaWelcomeCard(id: 'sec-suc-rec2', actionKey: 'profile', icon: 'user', title: 'Interested in your overall progress?', description: 'Open your dashboard', context: 'Your dashboard shows your full progress across activities and scores.'),
    ],
  ),
  'employer':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-emp-post', actionKey: 'post_job', icon: 'briefcase', title: 'How do I post a new job?', description: 'Create a new opening', context: 'Posting a job takes a title, skills, experience and salary, and it goes live to candidates right away.'),
      AriaWelcomeCard(id: 'sec-emp-apps', actionKey: 'all_applications', icon: 'resume', title: 'Who has applied recently?', description: 'Review applications', context: 'Applications show each candidate\'s resume and interview score so you can shortlist quickly.'),
      AriaWelcomeCard(id: 'sec-emp-cand', actionKey: 'find_candidates', icon: 'users', title: 'How do I find candidates?', description: 'Search the candidate pool', context: 'You can search candidates by skills and experience, even if they haven\'t applied yet.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-emp-rec1', actionKey: 'job_openings', icon: 'briefcase', title: 'Would you like to review your openings?', description: 'Manage active job posts', context: 'Reviewing your openings keeps your listings accurate and attractive.'),
      AriaWelcomeCard(id: 'sec-emp-rec2', actionKey: 'company_profile', icon: 'building', title: 'Interested in completing your profile?', description: 'Improve how candidates see you', context: 'Candidates are more likely to apply to companies with a complete profile.'),
    ],
  ),
  'employer_jobs':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-empj-post', actionKey: 'post_job', icon: 'briefcase', title: 'How do I add another opening?', description: 'Post a new job', context: 'Each new opening reaches matching job seekers on CareerBuddy.'),
      AriaWelcomeCard(id: 'sec-empj-apps', actionKey: 'all_applications', icon: 'resume', title: 'Who applied to my jobs?', description: 'Review applications', context: 'Applications are grouped by job so you can compare candidates side by side.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-empj-rec1', actionKey: 'find_candidates', icon: 'users', title: 'Would you like to search candidates?', description: 'Find matching talent', context: 'Searching candidates lets you reach people before they apply.'),
      AriaWelcomeCard(id: 'sec-empj-rec2', actionKey: 'company_profile', icon: 'building', title: 'Interested in updating your company profile?', description: 'Attract better applicants', context: 'An updated company profile helps you attract stronger applicants.'),
    ],
  ),
  'employer_applications':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-empa-cand', actionKey: 'find_candidates', icon: 'users', title: 'How do I find more candidates?', description: 'Search the candidate pool', context: 'Candidate search finds more people who match your requirements.'),
      AriaWelcomeCard(id: 'sec-empa-jobs', actionKey: 'job_openings', icon: 'briefcase', title: 'Which openings are still active?', description: 'Manage job openings', context: 'Your job openings page shows which roles are still accepting applications.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-empa-rec1', actionKey: 'post_job', icon: 'briefcase', title: 'Would you like to post another job?', description: 'Create a new opening', context: 'A new posting brings in a fresh pool of applicants.'),
      AriaWelcomeCard(id: 'sec-empa-rec2', actionKey: 'company_profile', icon: 'building', title: 'Interested in completing your profile?', description: 'Improve how candidates see you', context: 'A complete profile builds trust with the candidates you contact.'),
    ],
  ),
  'employer_candidates':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'sec-empc-apps', actionKey: 'all_applications', icon: 'resume', title: 'Who has already applied?', description: 'Review applications', context: 'The applications page lists everyone who has already applied to your jobs.'),
      AriaWelcomeCard(id: 'sec-empc-jobs', actionKey: 'job_openings', icon: 'briefcase', title: 'Which roles am I hiring for?', description: 'Manage job openings', context: 'Job openings shows every role you are currently hiring for.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'sec-empc-rec1', actionKey: 'post_job', icon: 'briefcase', title: 'Would you like to post a new job?', description: 'Reach more candidates', context: 'Posting a new job helps you reach more of the candidates you\'re searching for.'),
      AriaWelcomeCard(id: 'sec-empc-rec2', actionKey: 'company_profile', icon: 'building', title: 'Interested in updating your profile?', description: 'Improve how candidates see you', context: 'Candidates check your company profile before responding to you.'),
    ],
  ),
};

/// Role-level fallback cards (no section match, or a guest with no page
/// context yet) — mirrors `WELCOME_CONTEXT`. Keyed `"guest"`/`"student"`/
/// `"employer"`.
const kAriaWelcomeRoleContext = <String, AriaWelcomeCardGroup>{
  'guest':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'guest-profile', actionKey: 'register_job_seeker', icon: 'user', title: 'Create Candidate Registration', description: 'Create your Job Seeker profile', context: 'Registering as a job seeker gives you English practice, resume scoring, AI mock interviews and matched jobs, all in one place.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'guest-explore', actionKey: 'register_employer', icon: 'building', title: 'Create Employer Account', description: 'Create your Employer profile', context: 'An employer account lets you post jobs, search candidates and review applications from your own dashboard.'),
      AriaWelcomeCard(id: 'guest-signin', actionKey: 'login_job_seeker', icon: 'user', title: 'Job Seeker Sign-In', description: 'Continue to your career workspace', context: 'Signing in takes you back to your learning progress, resume score and job matches.'),
      AriaWelcomeCard(id: 'guest-employer', actionKey: 'login_employer', icon: 'briefcase', title: 'Employer Login', description: 'Manage hiring and candidates', context: 'The employer portal is where you manage your openings, applicants and interviews.'),
    ],
  ),
  'student':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'student-jobs', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Find Jobs', description: 'Search and explore relevant opportunities', context: 'Your recommended jobs are matched to your experience and skills, and they unlock once you score 70 or more in the AI mock interview.'),
      AriaWelcomeCard(id: 'student-resume', actionKey: 'resume_builder', icon: 'resume', title: 'Check Resume', description: 'Improve your resume and career profile', context: 'The Resume Builder parses your resume, gives you an ATS score and tells you exactly what to improve.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'student-dashboard', actionKey: 'profile', icon: 'user', title: 'Complete your Profile', description: 'Review your dashboard and progress', context: 'Your dashboard shows your activity progress, scores and recommended jobs at a glance.'),
      AriaWelcomeCard(id: 'student-matches', actionKey: 'job_recommendations', icon: 'briefcase', title: 'Explore Matching Jobs', description: 'Find opportunities relevant to you', context: 'Matched jobs are picked using your resume and interview score, so they fit your experience.'),
      AriaWelcomeCard(id: 'student-cert', actionKey: 'certifications', icon: 'cap', title: 'Your Certifications', description: 'View available certification features', context: 'Certifications are earned in Skill Up by scoring 70 percent or more in a module\'s mock test.'),
      AriaWelcomeCard(id: 'student-english', actionKey: 'english_vocab', icon: 'book', title: 'Continue Learning', description: 'Improve your English and vocabulary', context: 'The English and Vocabulary track has guides and a mock test to strengthen your business English.'),
    ],
  ),
  'employer':
  AriaWelcomeCardGroup(
    quickActions: [
      AriaWelcomeCard(id: 'employer-jobs', actionKey: 'job_openings', icon: 'briefcase', title: 'Manage Jobs', description: 'View and manage your job openings', context: 'Job Openings lists every role you have posted, so you can edit, close or review each one.'),
      AriaWelcomeCard(id: 'employer-candidates', actionKey: 'find_candidates', icon: 'users', title: 'Find Candidates', description: 'Search for suitable candidates', context: 'Candidate search lets you filter job seekers by skills, experience and interview scores.'),
      AriaWelcomeCard(id: 'employer-applications', actionKey: 'all_applications', icon: 'resume', title: 'Review Applications', description: 'Review candidate applications', context: 'All Applications collects everyone who applied, with their resumes and interview results.'),
      AriaWelcomeCard(id: 'employer-interviews', actionKey: 'find_candidates', icon: 'interview', title: 'Manage Interviews', description: 'Find candidates ready for hiring', context: 'You can shortlist candidates who have already completed the AI interview and are ready to hire.'),
    ],
    recommendations: [
      AriaWelcomeCard(id: 'employer-new-apps', actionKey: 'all_applications', icon: 'resume', title: 'Review New Applications', description: 'Check applications that need attention', context: 'New applications are waiting for your review; quick responses help you secure strong candidates.'),
      AriaWelcomeCard(id: 'employer-active', actionKey: 'job_openings', icon: 'briefcase', title: 'Active Job Postings', description: 'Manage your current openings', context: 'Your active postings are the roles candidates can apply to right now.'),
      AriaWelcomeCard(id: 'employer-company', actionKey: 'company_profile', icon: 'building', title: 'Complete Company Profile', description: 'Review your company information', context: 'A complete company profile with logo and description builds trust with candidates.'),
    ],
  ),
};

/// `label`/`route`/`response` for every `ACTION_DEFINITIONS` entry this
/// feature's cards reference — a deliberately smaller mirror of the real
/// `ACTION_DEFINITIONS` (no `keywords`; those drive the real web's own NLU
/// intent-matching on free-typed text, irrelevant to a card tap, which already
/// knows its exact action).
class AriaActionCatalogEntry {
  const AriaActionCatalogEntry({required this.label, required this.route, required this.response});
  final String label;
  final String route;
  final String response;
}

const kAriaActionCatalog = <String, AriaActionCatalogEntry>{
  'home': AriaActionCatalogEntry(label: 'Home', route: '/', response: 'Opening home.'),
  'lessons': AriaActionCatalogEntry(label: 'Go to Activities', route: '/activities/', response: 'Opening the activities page.'),
  'professional_speaking': AriaActionCatalogEntry(label: 'Speaking and Presentation', route: '/activities/?category=speaking', response: 'Opening Speaking and Presentation.'),
  'passage_writing': AriaActionCatalogEntry(label: 'Writing and Correspondence', route: '/activities/?category=writing', response: 'Opening Writing and Correspondence.'),
  'vocabulary': AriaActionCatalogEntry(label: 'Vocabulary and Idioms', route: '/activities/?category=vocabulary', response: 'Opening Vocabulary and Idioms.'),
  'negotiation': AriaActionCatalogEntry(label: 'Negotiation & Meetings', route: '/activities/?category=negotiation', response: 'Opening Negotiation & Meetings.'),
  'communication': AriaActionCatalogEntry(label: 'Professional Communication', route: '/activities/?category=communication', response: 'Opening Professional Communication.'),
  'analysis': AriaActionCatalogEntry(label: 'Analysis & Reporting', route: '/activities/?category=analysis', response: 'Opening Analysis & Reporting.'),
  'listen_learn': AriaActionCatalogEntry(label: 'Listen & Learn', route: '/activities/?category=listening', response: 'Opening Listen & Learn.'),
  'profile': AriaActionCatalogEntry(label: 'View Dashboard', route: '/dashboard/', response: 'Opening your dashboard.'),
  'company_profile': AriaActionCatalogEntry(label: 'Company Profile', route: '/employer/employer/profile/edit/', response: 'Opening your company profile.'),
  'find_candidates': AriaActionCatalogEntry(label: 'Find Candidates', route: '/employer/employer/candidates/search/', response: 'Opening the candidate search page.'),
  'post_job': AriaActionCatalogEntry(label: 'Post New Job', route: '/employer/employer/jobs/new/', response: 'Opening the post new job page.'),
  'all_applications': AriaActionCatalogEntry(label: 'All Applications', route: '/employer/employer/applications/', response: 'Opening the all applications page.'),
  'job_openings': AriaActionCatalogEntry(label: 'Job Openings', route: '/employer/employer/job-openings/', response: 'Opening the job openings page.'),
  'login_job_seeker': AriaActionCatalogEntry(label: 'Job Seeker Sign-In', route: '/users/login/', response: 'Taking you to the job seeker sign-in page.'),
  'register_job_seeker': AriaActionCatalogEntry(label: 'Job Seeker Registration', route: '/users/register/', response: 'Taking you to the job seeker registration page.'),
  'login_employer': AriaActionCatalogEntry(label: 'Employer Login', route: '/employer/accounts/employer/login/', response: 'Taking you to the employer portal.'),
  'register_employer': AriaActionCatalogEntry(label: 'Employer Registration', route: '/employer/accounts/employer/register/', response: 'Taking you to the employer registration page.'),
  'english_vocab': AriaActionCatalogEntry(label: 'English & Vocab', route: '/skill-up/#depth-english', response: 'Taking you to the English & Vocab section.'),
  'aptitude': AriaActionCatalogEntry(label: 'Aptitude', route: '/skill-up/#depth-aptitude', response: 'Taking you to the Aptitude section.'),
  'tech': AriaActionCatalogEntry(label: 'Tech', route: '/skill-up/#depth-tech', response: 'Taking you to the Tech section.'),
  'sitemap': AriaActionCatalogEntry(label: 'Sitemap', route: '/skill-up/#section-sitemap', response: 'Taking you to the Sitemap.'),
  'browse_all': AriaActionCatalogEntry(label: 'Browse all', route: '/skill-up/#section-depth', response: 'Taking you to browse all activities.'),
  'grammar': AriaActionCatalogEntry(label: 'Grammar', route: '/subject/', response: 'Opening the grammar section.'),
  'grammar_noun': AriaActionCatalogEntry(label: 'Nouns', route: '/subject/noun.html', response: 'Opening the Nouns module.'),
  'grammar_pronoun': AriaActionCatalogEntry(label: 'Pronouns', route: '/subject/pronoun.html', response: 'Opening the Pronouns module.'),
  'grammar_verb': AriaActionCatalogEntry(label: 'Verbs', route: '/subject/verb.html', response: 'Opening the Verbs module.'),
  'grammar_adjective': AriaActionCatalogEntry(label: 'Adjectives', route: '/subject/adjective.html', response: 'Opening the Adjectives module.'),
  'grammar_adverb': AriaActionCatalogEntry(label: 'Adverbs', route: '/subject/adverb.html', response: 'Opening the Adverbs module.'),
  'grammar_conjunction': AriaActionCatalogEntry(label: 'Conjunctions', route: '/subject/conjunction.html', response: 'Opening the Conjunctions module.'),
  'grammar_tenses': AriaActionCatalogEntry(label: 'Tenses', route: '/subject/tenses.html', response: 'Opening the Tenses module.'),
  'grammar_sentence_structure': AriaActionCatalogEntry(label: 'Sentence Structure', route: '/subject/sentence-structure.html', response: 'Opening Sentence Structure.'),
  'grammar_types_of_sentences': AriaActionCatalogEntry(label: 'Types of Sentences', route: '/subject/types-of-sentences.html', response: 'Opening Types of Sentences.'),
  'roleplay': AriaActionCatalogEntry(label: 'Roleplay', route: '/roleplay/', response: 'Opening roleplay practice.'),
  'storytelling_practice': AriaActionCatalogEntry(label: 'Storytelling Practice', route: '/roleplay/storytelling/', response: 'Opening Storytelling practice.'),
  'situation_practice': AriaActionCatalogEntry(label: 'Situation Practice Exercise', route: '/roleplay/situations/', response: 'Opening Situation Practice Exercise.'),
  'gd': AriaActionCatalogEntry(label: 'Group Discussion', route: '/gd/', response: 'Opening group discussion.'),
  'jam': AriaActionCatalogEntry(label: 'JAM', route: '/jam/', response: 'Opening JAM practice.'),
  'resume_builder': AriaActionCatalogEntry(label: 'Resume Builder', route: '/resume-builder/', response: 'Opening resume builder.'),
  'certifications': AriaActionCatalogEntry(label: 'Certifications', route: '/skill-up/#section-certifications', response: 'Opening your certifications.'),
  'pro': AriaActionCatalogEntry(label: 'Membership', route: '/pro/', response: 'Opening membership plans.'),
  'mock_interview': AriaActionCatalogEntry(label: 'AI Mock Interview', route: '/resume-builder/', response: 'Taking you to the Resume Builder for your AI Mock Interview.'),
  'job_search': AriaActionCatalogEntry(label: 'Job Search', route: '/resume-builder/analytics/', response: 'Opening Job Recommendations.'),
  'job_recommendations': AriaActionCatalogEntry(label: 'Job Recommendations', route: '/dashboard/#recommended-jobs', response: 'Opening your job recommendations.'),
  'workshop': AriaActionCatalogEntry(label: 'Interactive Workshop', route: '/activities/?category=workshop', response: 'Opening Interactive Workshop activities.'),
  'employer_login': AriaActionCatalogEntry(label: 'Employer Login', route: '/employer/accounts/employer/login/', response: 'Taking you to the Employer Portal.'),
  'student_login': AriaActionCatalogEntry(label: 'Job Seeker Sign-In', route: '/users/login/', response: 'Opening the job seeker login page.'),
};

