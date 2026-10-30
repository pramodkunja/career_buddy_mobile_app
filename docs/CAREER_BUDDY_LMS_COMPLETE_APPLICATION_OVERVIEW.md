# Career Buddy LMS — Complete Application Overview

*A business and product overview for the website development team.*

This document explains what Career Buddy LMS is, who it serves, and how
every part of it works, in plain business language. It is based on a
thorough inspection of the actual mobile application and its backend — not
on marketing copy or assumptions. Wherever a detail could not be confirmed
from the real application, it is marked **"requires confirmation"** rather
than guessed. No prices, statistics, partnerships, or guarantees are
invented anywhere in this document — the plan prices and feature lists
quoted below are transcribed directly from the application's own pricing
screen and backend configuration.

---

## 1. Application Introduction

**Career Buddy LMS is a career-readiness platform that takes a job seeker
from "I need a job" to "I'm ready to apply" — and gives employers a direct
line to that same pool of prepared candidates.**

It was built to close a gap that most job seekers run into: learning
platforms teach skills but don't help you find a job, and job platforms
list openings but don't help you get ready for them. Career Buddy LMS
combines both halves in one place — English and communication training,
technical and non-technical upskilling, resume-building, AI-powered resume
scoring, interview practice, and a path straight through to real job
applications — alongside a dedicated employer portal for posting roles and
finding candidates.

**Why it exists**: candidates — especially students, fresh graduates, and
career-changers — often know they need to "improve their resume" or
"practice for interviews," but have no structured way to do either, and no
easy way to measure whether they've actually improved. Career Buddy LMS
gives that structure: a resume that's scored against a real job
description, a mock interview that gives a real score, and a learning path
that unlocks further opportunities (like AI mock interviews and job
recommendations) as the candidate's own readiness improves.

**Who it serves**: two distinct audiences on one platform — job seekers who
want to become more employable, and employers who want to find and hire
them.

**What makes it useful**: everything a candidate does feeds into the next
step. A resume upload doesn't just sit in a folder — it's scored, and that
score can unlock a mock interview. Doing well in the mock interview can
unlock job recommendations. Learning isn't a separate silo from job-hunting
— it's the on-ramp to it.

**Vision and value proposition**: Career Buddy LMS positions itself as a
single, structured path from "building job-readiness" to "being hired" —
for candidates, a guided way to become a stronger applicant; for employers,
direct access to candidates who have already demonstrated real,
measurable readiness.

---

## 2. Target Users

### Candidates / Job Seekers

Career Buddy LMS's candidate side is built for a wide range of people at
different career stages:

- **Students and fresh graduates** — building a first resume, learning
  foundational English and communication skills, and getting their first
  taste of structured interview practice before they've ever had a real
  interview.
- **Active job seekers** — anyone currently applying to jobs who wants
  their resume scored against a specific job description, and who wants to
  practice interviewing before the real thing.
- **Experienced professionals** — using the technical upskilling content
  (Tech Center) and the career-path browsing tools to explore adjacent or
  senior roles, and using the resume/interview tools the same way a
  first-time user would.
- **People preparing specifically for interviews** — the AI Mock Interview
  and the various speaking/communication practice modules (Group
  Discussion, "Just A Minute" timed speaking, Roleplay scenarios) are built
  around rehearsal and feedback, not just static learning content.
- **People looking to improve technical or non-technical skills** — the
  Tech Center (IT-track roles and courses) and the Non-IT Center
  (non-technical career-path roles and courses) both offer structured,
  department-by-department, role-by-role learning content.

### Employers / Recruiters

The employer side is a separate, parallel experience built for hiring:

- **Recruiters and hiring teams** who need to post job openings, manage
  applicants, and review candidates.
- **Employers sourcing talent directly** — rather than waiting for
  applications, employers can search the platform's own candidate base by
  skill, location, and experience, and export results.

### Candidate vs. Employer experience — the key difference

These are genuinely two different products sharing one platform:

| | Candidates | Employers |
|---|---|---|
| Primary goal | Build skills, build a resume, get interview-ready, find a job | Post jobs, find candidates, manage applicants |
| Registration | Personal and educational details, a required resume upload, identity-verification details | Company details, a company contact, company registration details |
| Home base | A personal dashboard with learning progress, resume status, and recommended jobs | A recruiter dashboard with job postings and applicant activity |
| Core tools | Resume builder, resume scoring, mock interviews, Skill Up learning | Job posting, applicant review, candidate search |

A candidate account and an employer account are kept separate — an
employer signing in reaches a different dashboard and a different set of
menu options than a candidate does, and vice versa.

---

## 3. Complete Application Features and Modules

### A. Home and Dashboard

- **Home screen**: the entry point for every visitor, whether or not they
  have an account. It introduces the platform and offers a "Which path
  suits you?" prompt that helps a new visitor choose between an IT-focused
  or Non-IT-focused track.
- **Navigation and menus**: a side menu (drawer) organizes the whole app —
  Home, About Us, a "Skill Up" section (with its own sub-menu covering
  English Learning, Grammar, Vocabulary & Idioms, Speaking & Presentation,
  Writing & Correspondence, Negotiation & Meetings, Interactive Roleplay,
  Aptitude, and Tech), a "Resources" section (Skill Up Hub, Activities,
  Certifications, a full Sitemap, subscription info, and Tutorials),
  Industries, Create Resume, and Contact Us — plus Login options for both
  candidates and employers.
- **Candidate dashboard**: once logged in, a candidate's home base — shows
  learning progress, activity scores, recommended jobs, subscription
  status, and a record of past payments.
- **Employer dashboard**: an employer's home base after logging in — a
  summary view for managing job postings and applicant activity.
- **Shortcuts and information**: the dashboards are designed to surface
  "what should I do next" — for a candidate, that means progress and
  recommended next steps; for an employer, that means job and applicant
  activity.

### B. User Registration and Profiles

- **Candidate registration**: collects the information needed to build a
  usable profile and to match a candidate to relevant jobs — contact
  details, education history, work experience, skills, salary
  expectations, location preferences, and a required resume upload. It also
  collects government identity-verification details (used for identity
  confirmation) as part of candidate onboarding.
- **Employer registration**: collects company details — company name,
  industry, a company contact person, and company registration/tax
  details, plus an optional company logo.
- **Login**: a standard sign-in flow for both candidates and employers,
  each through their own, separate login screen, plus a full
  forgot-password/reset flow.
- **Email verification**: both candidate and employer registration require
  verifying an email address with a one-time code before the account can be
  created — a standard security step to confirm the person signing up owns
  the email address they provided.
- **User profiles**: a profile holds a candidate's personal, educational,
  and professional information, plus a summary of their learning
  activity and scores. *(Note: the in-app profile-viewing/editing screen
  itself is still in development at the time of this review — registration
  already collects this information, but a dedicated in-app screen for
  viewing/editing it afterward is not yet available. This should be marked
  "coming soon" rather than promoted as a current feature on the website.)*
- **Profile management**: company-profile management (for employers) is
  fully available today — employers can view and update their company
  name, logo, and related details at any time.

### C. Resume Management

Career Buddy LMS offers **four distinct resume-related tools**, each
serving a different need:

1. **Resume Parsing & ATS Scoring** — a candidate uploads an existing
   resume (and, optionally, a target job description), and the platform
   analyzes how well it matches, returning a score and feedback. This is
   the tool that "unlocks" further features (AI Mock Interview access is
   tied to reaching a strong ATS score). A history of past uploads and
   scores is kept, so a candidate can track improvement over time.
2. **Manual Resume Builder** — an AI-assisted, guided resume builder that
   suggests structure and content based on the role a candidate is
   targeting, producing a polished, exportable resume.
3. **Create Resume Builder** — a simpler, free-form resume builder that
   lets anyone (even without an account) build and preview a resume, with
   the option to save it to an account for later editing.
4. **Career Paths Explorer** — a browsing tool (open to everyone, no
   account needed) that lets a visitor explore IT and Non-IT career
   departments and roles, to understand what a role actually requires
   before committing to building a resume or pursuing that path.

### D. Job and Career Opportunities

- **For candidates**: a job-openings area, the ability to view and apply to
  individual job postings, and a personal record of applications already
  submitted.
- **For employers**: full job-posting management (create, edit, and manage
  listings across IT and Non-IT job categories, with a detailed set of
  requirements, perks, and preferences per posting), an applicant-review
  system (per job and across all jobs at once, with notes and status
  tracking), and **candidate search** — the ability to search the platform's
  own registered candidates by skill, location, and experience, with the
  option to export results.
- **Shared ground**: a "Job Openings" view exists that both logged-in
  candidates and logged-in employers can see, giving both sides visibility
  into what's currently posted.

### E. Interview Preparation

- **AI Mock Interview** — the centerpiece of interview preparation: a
  simulated interview with AI-generated questions, where the candidate
  answers by speaking or typing. The feature uses the device's camera to
  verify the candidate's identity and monitor the session for interview
  integrity, and produces a score and feedback afterward. Access to this
  feature is unlocked progressively — it becomes available once a
  candidate's resume reaches a strong ATS score, reflecting the platform's
  "build readiness, then unlock the next step" design.
- **Group Discussion** — a live, real-time, AI-moderated group discussion
  exercise that simulates the back-and-forth of a real group interview
  round.
- **"Just A Minute" (JAM)** — timed, impromptu speaking practice with AI
  feedback, structured as progressive practice sessions followed by a
  graded assessment.
- **Roleplay Workshop** — AI-generated practice scenarios (storytelling,
  situational responses, and roleplay exercises) for rehearsing real-world
  communication situations.

### F. Skill Development and Learning ("Skill Up")

Skill Up is the platform's full learning hub, organized so a candidate can
move from general communication skills into deep, role-specific technical
or non-technical training.

- **English Learning, Grammar, and Vocabulary & Idioms** — foundational
  communication-skill content, available even on the platform's free tier.
- **Aptitude** — reasoning and aptitude practice content, commonly used for
  placement-style preparation.
- **Tech Center** — a structured, department-by-department library of IT
  career paths (for example, departments such as Development, DevOps &
  Infrastructure, Quality Assurance & Testing, Business Analysis, Product
  Management, Design/UX-UI, and more). Within each department, a candidate
  can browse individual **roles** (e.g., "Software Developer," "DevOps
  Engineer," "QA Lead"), and within each role, a set of **courses** —
  focused lessons covering what that specific role actually requires.
- **Non-IT Center** — the same department → role → course structure,
  covering non-technical career paths (for example, roles in recruitment,
  customer support, and other non-technical professional tracks).
- **Certifications** — candidates who complete learning content and score
  well (a score of 70 or above) can generate a personal certificate,
  downloadable as a PDF with their own name printed on it.
- **How discovery works**: a candidate browses by department first, then
  drills into a specific role to see the courses available for it, and
  finally opens individual lessons. This mirrors how someone would actually
  explore "what do I need to learn to become a ___" rather than presenting
  an undifferentiated list of lessons.
- **Tutorials**: an in-app tutorial/walkthrough video exists on the Home
  screen to help new users understand how to use the platform.

### G. AI Features

- **Riya / "Buddy" AI Assistant** — a conversational AI assistant,
  accessible throughout the app, that can answer questions and help users
  navigate directly to the feature they're looking for. It supports both
  typed and voice conversations and can speak its replies back to the
  user.
- **AI Resume Scoring** — resumes are analyzed by AI against a target job
  description to produce a match score and feedback (see Section C).
- **AI Mock Interview** — AI generates interview questions and evaluates
  responses, producing a score and feedback (see Section E).
- **AI-graded practice exercises** — several of the communication-practice
  modules (speaking, writing, listening, reading, Group Discussion, JAM,
  Roleplay) use AI to evaluate a candidate's spoken or written responses,
  not just simple right/wrong scoring.

### H. Subscription and Payments

Career Buddy LMS offers **three plan tiers**, confirmed directly from the
application's own pricing configuration (these are the platform's real,
current prices and inclusions — not estimates):

| Plan | Price | Duration | What's included |
|---|---|---|---|
| **Free** | ₹0 | — | Skill Up's English, Vocabulary, and Grammar content; access to 1 practice Activity; 4 Resume Parsing & ATS Score analyses |
| **Normal User** | ₹499 (+ 18% GST) | 1 year | Full access to all practice Activities; full Skill Up access (English, Aptitude, Tech Center, Non-IT Center) with certificates for scores of 70+; the candidate Dashboard; unlimited Resume Parsing/ATS analysis; AI Mock Interviews (unlocked once a resume reaches a 90%+ ATS score); up to 5 matched job recommendations (unlocked once a mock interview scores 90%+) |
| **Pro User** | ₹999 (+ 18% GST) | 1 year | Everything in Normal, plus expanded AI Mock Interview formats (voice and non-voice, service-desk and technical variants), unlimited matched job recommendations, and direct job applications with the candidate's resume automatically attached |

Payment is processed through a secure third-party payment gateway
(Razorpay); the platform itself never directly handles card, bank, or UPI
details. *(Note: at the time of this review, there is no in-app option to
cancel a subscription or request a refund directly — this should either be
addressed before heavy promotion of the subscription plans, or the website
should direct users to a support contact for these requests. This is
flagged here as something the business should decide on, not assumed one
way or the other.)*

### I. Additional Features

- **Learning progress tracking**: candidates' completed activities and
  scores are tracked and summarized on their dashboard.
- **Payment/transaction history**: a candidate can see a record of their
  own past payments on their dashboard.
- **Candidate CSV export** (employer-side): employers can export a list of
  searched candidates to a spreadsheet file.
- **Contact Us**: a contact destination exists in the app's navigation.
  *(Note: at the time of this review, the actual contact information behind
  this destination — a support email, phone number, or address — could not
  be confirmed in the materials inspected and should be supplied by the
  business before publicizing a "Contact Us" page on the website.)*
- **Account management**: candidates and employers can log out and, for
  employers, manage their company profile. *(Note: there is currently no
  in-app option to delete or deactivate an account — flagged here as a
  business/product decision, not something to promise on the website until
  it exists.)*

---

## 4. User Journey and Application Workflows

The following journeys describe how the application actually behaves
today, based on direct inspection. Anything not fully built is marked.

1. **A new candidate discovers the application** — they land on the Home
   screen (reachable without an account), see the "Which path suits you?"
   prompt, and can freely browse the Career Paths explorer and even build
   and preview a resume before ever creating an account.
2. **Candidate registration and login** — the candidate registers with
   their personal, educational, and professional details, verifies their
   email with a one-time code, and signs in.
3. **Candidate profile creation** — registration itself captures the
   candidate's profile information. *(Viewing/editing this profile later,
   inside the app, is not yet available — see Section B.)*
4. **Resume creation** — the candidate either uploads an existing resume
   for AI scoring, builds one with the guided Manual Resume Builder, or
   uses the simpler Create Resume Builder.
5. **Exploring career/job-related features** — the candidate browses open
   job listings, views individual job details, and can apply directly to a
   posting.
6. **Preparing for interviews** — once a resume reaches a strong ATS score,
   the candidate can access the AI Mock Interview; independently, they can
   also practice through Group Discussion, JAM, and Roleplay at any time
   (subject to their plan).
7. **Learning new skills through Skill Up** — the candidate explores Skill
   Up's English/Grammar/Vocabulary/Aptitude content, or drills into Tech
   Center / Non-IT Center by department → role → course, and can earn a
   certificate for strong scores.
8. **Using AI-powered features** — throughout the journey, the candidate
   can ask the Riya/Buddy assistant for help navigating the app, and
   receives AI-generated scoring/feedback on resumes, interviews, and
   practice exercises.
9. **Exploring subscriptions and paid features** — the candidate can view
   the three plan tiers and upgrade via the in-app checkout (Razorpay).
   Higher-value features (unlimited resume analysis, Mock Interviews, job
   recommendations) are unlocked by plan tier and by demonstrated
   readiness (ATS/interview scores).
10. **Employer registration and login** — an employer registers with
    company details, verifies their email (and their listed company
    contact's email) with a one-time code, and signs in through a
    separate employer login.
11. **Employer accessing recruiter functionality** — once signed in, the
    employer reaches their own dashboard and can post jobs, review
    applicants, search candidates, and manage their company profile.

---

## 5. Application Structure and Navigation

This section is written specifically to help a website designer plan the
website's own navigation and page structure around the real app structure.

**Main navigation (candidate/guest view)** — a side-menu (drawer) with:
- Home
- About Us
- **Skill Up** (expandable sub-menu): English Learning, Grammar, Vocabulary
  & Idioms, Speaking & Presentation, Writing & Correspondence, Negotiation
  & Meetings, Interactive Roleplay, Aptitude, Tech
- **Resources** (expandable sub-menu): Skill Up Hub, Activities,
  Certifications, Sitemap, CareerBuddy Pro (subscription info), Tutorials
- Industries
- Create Resume
- Contact Us
- Job Seeker Login / Employer Login (shown to guests)

**Main navigation (employer view)** — a separate drawer, centered on:
Employer Dashboard, Jobs, Job Applications, Candidate Search, Company
Profile, and Logout.

**Major sections** (how the app itself groups its content):
- **Home** — the shared landing experience for all visitors.
- **Learning** — Skill Up, Tech Center, Non-IT Center, Grammar,
  Certifications, Activities, Mock Tests.
- **Career tools** — Resume Builder(s), Resume Parsing/ATS, Mock Interview,
  Career Paths Explorer.
- **Practice/communication** — Group Discussion, JAM, Roleplay.
- **Jobs** — job listings, applications (candidate side); job posting,
  applicant management, candidate search (employer side).
- **Account** — registration, login, dashboard, subscription.

**Guest-accessible areas** (no account required): the Home landing page,
the Employer Home landing page, individual public job listings, the Career
Paths Explorer, and the Create Resume Builder's build/preview experience
(saving a resume to an account requires logging in). Everything else
requires signing in.

**Candidate vs. employer navigation**: these are visually and functionally
separate menus — a candidate never sees employer-only options (job
posting, candidate search) and an employer never sees candidate-only
learning content. This separation should be reflected on the website too:
distinct "For Candidates" and "For Employers" sections rather than one
blended navigation path.

---

## 6. What Makes Career Buddy LMS Valuable?

- **One platform, not a patchwork**: a candidate doesn't need a separate
  resume tool, a separate interview-practice app, and a separate
  learning platform — Career Buddy LMS connects all three, with one
  feeding into the next.
- **Resume help that's measured, not just advice**: the AI scoring gives a
  concrete number and feedback, rather than generic resume tips.
- **Realistic interview rehearsal**: the AI Mock Interview, Group
  Discussion, and JAM modules all simulate real interview-style pressure
  and produce actual feedback, not just scripted Q&A.
- **Depth in technical and non-technical learning alike**: the Tech
  Center and Non-IT Center both offer structured, role-specific learning
  paths — not a generic course catalog, but content organized the way a
  career actually is (by department, then role, then the specific courses
  that role needs).
- **Progress that unlocks opportunity**: features like the AI Mock
  Interview and job recommendations are tied to demonstrated readiness
  (ATS score, interview score) — the platform rewards improvement with
  access, which is a meaningful differentiator to highlight honestly on
  the website.
- **A real path to employers**: the learning and resume-building isn't a
  dead end — it connects to actual job listings and, for Normal/Pro
  subscribers, direct applications and job matching.
- **An employer side that benefits from the same pool**: employers aren't
  searching a generic resume database — they're searching candidates who
  have gone through the platform's own skill-building and resume-scoring
  process.

*(This section deliberately does not claim placement statistics, success
rates, partnerships, or guarantees — none of these could be confirmed from
the actual application, and none should be implied on the website unless
the business supplies verified figures separately.)*

---

## 7. Website Development Team — Design and Content Guidance

Recommended page structure, based directly on the real application:

### Home
**Purpose**: convert a first-time visitor into either a candidate sign-up
or an employer sign-up.
**Content**: a hero section (see Section 8 for suggested messaging), a
clear fork between "For Candidates" and "For Employers," a short feature
highlight row (Resume Builder, AI Mock Interview, Skill Up, Job Matching),
and a download-the-app call to action.
**Features to highlight**: the end-to-end journey (learn → build a resume
→ practice interviews → apply), not any single feature in isolation.

### About Us
**Purpose**: explain the platform's origin and mission.
**Content**: the "why it exists" framing from Section 1 of this document.
*(Company history, founding story, and team details require confirmation
from the business — not available from the application itself.)*

### Features (overview page)
**Purpose**: a single page summarizing everything the platform does, with
links out to dedicated pages for the larger features.
**Content**: a grid or list covering Resume Tools, Interview Preparation,
Skill Up/Tech Center/Non-IT Center, AI Assistant, and Job Opportunities.

### For Students / Candidates
**Purpose**: speak directly to the candidate audience described in Section
2.
**Content**: the candidate journey (Section 4, items 1-9), framed as
benefits rather than steps — "build a resume that gets noticed," "practice
interviews with real feedback," "learn the exact skills your target role
needs."
**Calls to action**: "Create Your Free Account," "Build Your Resume Now."

### For Employers
**Purpose**: speak directly to the employer audience.
**Content**: job posting, candidate search, and applicant management,
framed around "find candidates who are already job-ready."
**Calls to action**: "Post a Job," "Search Candidates."

### Resume Builder
**Purpose**: a dedicated page for the platform's most tangible, easy-to-
demonstrate feature.
**Content**: explain all three resume paths (AI Scoring, Manual Builder,
Create Resume Builder) and when a visitor would use each.

### Interview Preparation
**Purpose**: showcase the AI Mock Interview, Group Discussion, and JAM.
**Content**: emphasize real-time, AI-evaluated practice — this is a strong
visual/demo opportunity (a mocked-up screenshot or short video of the Mock
Interview flow would work well here).

### Skill Development / Tech Center
**Purpose**: showcase the depth of the Skill Up / Tech Center / Non-IT
Center content.
**Content**: illustrate the department → role → course structure visually
(e.g., "Choose a department → pick your role → start learning") — this
mirrors exactly how the app itself works and will feel authentic to anyone
who downloads the app afterward.

### AI Features
**Purpose**: a dedicated page for the Riya/Buddy assistant and the
platform's AI-driven scoring, since AI is a genuine differentiator worth
its own spotlight.
**Content**: describe the assistant conversationally ("Ask Riya anything"),
and describe AI scoring honestly as feedback/guidance rather than a
guarantee of outcome.

### Courses and Learning
**Purpose**: a catalog-style page if the business wants a more SEO-
friendly, browsable version of the Skill Up content.
**Content**: can mirror the Tech Center / Non-IT Center department
structure.

### Subscription Plans
**Purpose**: present the three real plan tiers.
**Content**: use the exact plan names, prices, and inclusions from Section
3H above — do not alter these without confirming with the business that
pricing has changed.

### Contact Us / Support
**Purpose**: a genuine way for a visitor or user to reach the business.
**Content**: *(requires confirmation from the business — no support email,
phone number, or address could be confirmed from the application at the
time of this review; this page cannot be built credibly until that
information is supplied.)*

### Download App
**Purpose**: drive installs.
**Content**: app store badges, a short "what you'll get" summary, and
ideally a few real in-app screenshots once available.

### Suggested homepage content structure
1. Hero section (headline + supporting line + two calls to action — one
   for candidates, one for employers).
2. "How it works" — a simple 3-4 step visual (Learn → Build → Practice →
   Apply).
3. Feature highlights (short cards: Resume Tools, AI Mock Interview, Skill
   Up/Tech Center, Job Matching).
4. Candidate vs. Employer split section.
5. Subscription plan teaser (linking to the full Subscription page).
6. App screenshots/download section.
7. Footer with navigation, and — once supplied — real contact details.

---

## 8. Brand and Content Direction

*(No official brand guidelines, logo files, color palette, or tagline were
found in the inspected materials — the items below are content-direction
suggestions only, not a design system, and should be confirmed/adjusted by
the business's own branding before final use.)*

**One-sentence description**: "Career Buddy LMS is an all-in-one career-
readiness platform that helps job seekers build skills, craft stronger
resumes, and practice for real interviews — while connecting employers to
candidates who are already prepared to succeed."

**Short professional introduction** (suitable for a homepage sub-heading
or an "About" teaser): "Career Buddy LMS brings together resume-building,
AI-powered interview practice, and structured skill development in one
platform — so job seekers can move from learning to applying with
confidence, and employers can hire from a pool of candidates who've already
put in the work."

**Suggested homepage headline options**:
- "Your Career, Ready."
- "From Learning to Landing the Job."
- "Build Your Skills. Build Your Resume. Get Hired."

**Suggested supporting line**: "One platform to learn in-demand skills,
build a standout resume, and practice for the interview that gets you
hired."

**Suggested feature-description tone**: direct and benefit-first, not
feature-first. For example, prefer "See exactly how your resume stacks up
against the job you want" over "AI-powered ATS resume scoring engine."

**Suggested calls to action**: "Start for Free," "Build My Resume," "Try
an AI Mock Interview," "Post a Job," "Search Candidates."

**Tone and communication style**: confident but honest — the application
genuinely offers a complete, structured journey, which is a strong
message on its own; the website copy should avoid unverifiable claims
(placement guarantees, success rates, partnership logos) that aren't
confirmed by the business.

---

## Summary for the requester

**File created**: `Mobile_app/docs/CAREER_BUDDY_LMS_COMPLETE_APPLICATION_OVERVIEW.md`

**Application in one paragraph**: Career Buddy LMS is a combined
career-readiness and hiring platform. Candidates get English/communication
and technical skill-building (Skill Up, Tech Center, Non-IT Center), resume
tools (AI scoring plus two different resume builders), AI-driven interview
practice (Mock Interview, Group Discussion, JAM, Roleplay), and a path to
real job applications — gated into a Free, ₹499 Normal, and ₹999 Pro annual
plan. Employers get a separate portal for posting jobs, managing
applicants, and searching the same candidate pool directly.

**Major modules covered**: Home/Dashboard, Registration & Profiles (both
roles), Resume Management (4 tools), Jobs & Career Opportunities (both
roles), Interview Preparation (4 features), Skill Development/Skill Up
(including Tech Center and Non-IT Center), AI Features (Riya/Buddy
assistant plus AI scoring throughout), Subscription & Payments, and
supporting features (progress tracking, payment history, candidate CSV
export, contact, account management).

**Features that could not be fully verified / are not yet complete**:
- A dedicated in-app profile viewing/editing screen (registration already
  collects this data; there's no screen to view/edit it afterward yet).
- Real support contact details (email/phone/address) behind "Contact Us."
- An in-app subscription cancellation or refund-request option.
- An in-app account-deletion option.
- Any official brand guidelines, logo, color palette, or tagline.
- Company history/founding story/team details for an "About Us" page.

**Confirmation**: this review was read-only. No source code, application
behavior, backend logic, or database content was modified in either Django
reference project or in the Flutter application. Only this one new
document was created.
