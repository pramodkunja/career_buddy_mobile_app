/// Static option/skill catalog for the live "Post New Job" page
/// (`employer/employer/jobs/new/`, confirmed directly by fetching and
/// parsing the real rendered HTML during this task — the committed
/// `jobs_app.forms.JobPostingForm`/`jobs_app/models.py` in the Django repo
/// describe a much smaller, 17-field form with one free-text
/// `skills_required` field and no department/mandatory-skill system at
/// all; that committed form is NOT what production actually serves, and is
/// not used as the contract here, per this task's own explicit instruction
/// to follow the live page over stale repository code).
///
/// Every value/label pair and every skill name below is copied verbatim
/// from the live page's rendered `<option>`/`<li data-skill="...">`
/// markup — nothing here is invented. `(value, label)` tuples match this
/// codebase's existing convention (see `kCompanySizeOptions`,
/// `employer_profile_form.dart`).
library;

const List<(String value, String label)> kJobCategoryOptions = [
  ('it', 'IT'),
  ('non_it', 'Non-IT'),
];

const List<(String value, String label)> kJobClassificationOptions = [
  ('technical', 'Technical'),
  ('non_technical', 'Non-Technical'),
];

/// `id_department` — only shown/used for Non-IT + Technical (also doubles
/// as each department's skill-picker group key, see [kSkillCatalog]).
const List<(String value, String label)> kDepartmentOptions = [
  ('engineering', 'Engineering Skills'),
  ('epc_construction', 'EPC & Construction Skills'),
  ('hse_safety', 'HSE / EHS / Safety Skills'),
  ('fire_emergency', 'Fire & Emergency Skills'),
  ('quality_inspection', 'Quality & Inspection Skills'),
  ('plant_operations', 'Plant Operations & Maintenance'),
  ('skilled_trades', 'Skilled & Technical Trades'),
  ('renewable_energy', 'Renewable Energy Skills'),
  ('industrial_manufacturing', 'Industrial & Manufacturing Skills'),
  ('automotive_ev', 'Automotive & EV Skills'),
  ('oil_gas_energy', 'Oil & Gas / Energy Skills'),
  ('logistics_workforce', 'Logistics & Industrial Workforce Skills'),
];

/// `id_designation` — optional on every branch; `dataClassification` is
/// `null` for none (shown regardless of [JobClassification]).
const List<(String value, String label, String? dataClassification)> kDesignationOptions = [
  ('manager', 'Manager', 'technical'),
  ('project_engineer', 'Project Engineer', 'technical'),
  ('site_engineer', 'Site Engineer', 'technical'),
  ('estimation_engineer', 'Estimation Engineer', 'technical'),
  ('back_office_manager', 'Back Office Manager', 'technical'),
  ('project_coordinator', 'Project Coordinator', 'technical'),
  ('project_director', 'Project Director', 'technical'),
  ('hr_manager', 'HR Manager', 'non_technical'),
  ('hr_executive', 'HR Executive', 'non_technical'),
  ('hr_recruiter', 'HR Recruiter', 'non_technical'),
  ('back_office_executive', 'Back Office Executive', 'non_technical'),
  ('accountant', 'Accountant', 'non_technical'),
  ('account_executive', 'Account Executive', 'non_technical'),
  ('sales_executive', 'Sales Executive', 'non_technical'),
  ('sales_manager', 'Sales Manager', 'non_technical'),
  ('sales_officer', 'Sales Officer', 'non_technical'),
  ('sales_marketing_executive', 'Sales & Marketing Executive', 'non_technical'),
  ('store_executive', 'Store Executive', 'non_technical'),
  ('store_supervisor', 'Store Supervisor', 'non_technical'),
  ('store_manager', 'Store Manager', 'non_technical'),
  ('purchase_executive', 'Purchase Executive', 'non_technical'),
  ('purchase_manager', 'Purchase Manager', 'non_technical'),
];

/// `id_job_type` — IT branch label ("Job Type"); the same field is
/// relabeled "Employment Type" on the Non-IT branch per the real page's
/// `data-it-label`/`data-nonit-label` spans.
const List<(String value, String label)> kJobTypeOptions = [
  ('full_time', 'Full Time'),
  ('part_time', 'Part Time'),
  ('contract', 'Contract'),
  ('internship', 'Internship'),
  ('remote', 'Remote'),
];

/// `id_employment_type` — Non-IT only.
const List<(String value, String label)> kEmploymentTypeOptions = [
  ('permanent', 'Permanent'),
  ('contract', 'Contract'),
  ('project', 'Project'),
];

/// `id_experience` presets — "Enter manually" (`custom`) reveals a typed
/// years field instead (see `JobPostingSubmission.experience*`).
const List<(String value, String label)> kExperiencePresets = [
  ('fresher', 'Fresher'),
  ('1-2', '1-2 Years'),
  ('3-5', '3-5 Years'),
  ('5-8', '5-8 Years'),
  ('8+', '8+ Years'),
];

/// `id_education` presets — "Enter manually" (`custom`) reveals
/// `education_other` instead.
const List<(String value, String label)> kEducationPresets = [
  ('below_10th', 'Below 10th Standard'),
  ('10th', '10th / SSLC'),
  ('11th', '11th Standard'),
  ('12th', '12th / HSC / PUC'),
  ('iti', 'ITI'),
  ('diploma', 'Diploma'),
  ('ug', 'Under-Graduate / Degree'),
  ('pg', 'Post-Graduate'),
  ('degree', 'Degree'),
  ('certification', 'Certification'),
];

const List<(String value, String label)> kSalaryFormatOptions = [
  ('monthly', 'Monthly'),
  ('lpa', 'LPA (Lakhs Per Annum)'),
];

/// `id_status` — default `active`, matching the live page's pre-selected
/// option.
const List<(String value, String label)> kJobStatusOptions = [
  ('active', 'Active'),
  ('closed', 'Closed'),
  ('draft', 'Draft'),
];

/// `id_work_mode` — Non-IT only ("Work Mode").
const List<(String value, String label)> kWorkModeOptions = [
  ('onsite', 'On-site'),
  ('field', 'Field'),
  ('plant', 'Plant'),
  ('office', 'Office'),
  ('hybrid', 'Hybrid'),
];

/// `id_joining_requirement` — Non-IT + Non-Technical only.
const List<(String value, String label)> kJoiningRequirementOptions = [
  ('immediate', 'Immediate'),
  ('notice_ok', 'Notice period acceptable'),
];

/// `id_work_environment` radio group — IT only (relabeled "Work Mode" with
/// different options on Non-IT, see [kWorkModeOptions]).
const List<(String value, String label)> kWorkEnvironmentOptions = [
  ('wfh', 'Work From Home'),
  ('hybrid', 'Hybrid'),
  ('wfo', 'Work From Office'),
];

/// `id_interview_mode` radio group — IT only.
const List<(String value, String label)> kInterviewModeOptions = [
  ('walk_in', 'Walk In'),
  ('virtual', 'Virtual'),
  ('others', 'Others'),
];

/// `id_notice_period` radio group — IT only (relabeled "Joining
/// Requirement" with different options on Non-IT + Non-Technical, see
/// [kJoiningRequirementOptions]).
const List<(String value, String label)> kNoticePeriodOptions = [
  ('immediate', 'Immediately'),
  ('15_days', '15 Days'),
  ('30_days', '30 Days'),
  ('others', 'Others'),
];

const List<(String value, String label)> kGenderPreferenceOptions = [
  ('male', 'Male'),
  ('female', 'Female'),
  ('both', 'Both'),
];

/// `#perks-group` — `id_perks_0..17`, all optional, any number selected.
const List<(String value, String label)> kPerksOptions = [
  ('flexible_hours', 'Flexible Working Hours'),
  ('weekly_payout', 'Weekly Payout'),
  ('overtime_pay', 'Overtime Pay'),
  ('joining_bonus', 'Joining Bonus'),
  ('annual_bonus', 'Annual Bonus'),
  ('pf', 'PF'),
  ('travel_allowance', 'Travel Allowance (TA)'),
  ('petrol_allowance', 'Petrol Allowance'),
  ('mobile_allowance', 'Mobile Allowance'),
  ('internet_allowance', 'Internet Allowance'),
  ('laptop', 'Laptop'),
  ('health_insurance', 'Health Insurance'),
  ('esi', 'ESI (ESIC)'),
  ('food_meals', 'Food/Meals'),
  ('accommodation', 'Accommodation'),
  ('five_working_days', '5 Working Days'),
  ('one_way_cab', 'One-Way Cab'),
  ('two_way_cab', 'Two-Way Cab'),
];

/// One `.skills-group[data-department]` pill group. [key] is `"it"` for
/// the IT branch's general group, or one of [kDepartmentOptions]'s values
/// for a Non-IT Technical department. `skills` is each `<li data-skill>`'s
/// exact label, in the real page's own order.
class JobSkillCategory {
  const JobSkillCategory({required this.key, required this.skills});

  final String key;
  final List<String> skills;
}

/// Every skill-picker group the live page renders, keyed the same way
/// `currentSkillsGroup()` (`job_form.html`'s inline script) picks one:
/// `"it"` for the IT branch, or the selected [kDepartmentOptions] value for
/// Non-IT + Technical. Non-IT + Non-Technical has no skill picker at all
/// (a plain `functional_skills` text field instead).
const List<JobSkillCategory> kSkillCatalog = [
  JobSkillCategory(
    key: 'it',
    skills: [
      'Communication',
      'English Proficiency',
      'Teamwork',
      'Problem Solving',
      'Time Management',
      'Leadership',
      'Customer Service',
      'Sales & Negotiation',
      'MS Office / Excel',
      'Data Analysis',
      'Computer Basics',
      'Project Management',
      'Technical / Domain Knowledge',
      'Adaptability',
    ],
  ),
  JobSkillCategory(
    key: 'engineering',
    skills: [
      'Civil Engineering',
      'Mechanical Engineering',
      'Electrical Engineering',
      'Instrumentation',
      'Automation & Control',
      'Electronics',
      'Chemical / Process Engineering',
      'Industrial Engineering',
      'Production Engineering',
      'Maintenance Engineering',
      'Reliability Engineering',
      'Marine Engineering',
      'Renewable Energy',
    ],
  ),
  JobSkillCategory(
    key: 'epc_construction',
    skills: [
      'Project Management',
      'Construction Management',
      'Project Planning',
      'Project Scheduling',
      'Project Controls',
      'Cost Control',
      'Site Supervision',
      'Contract Management',
      'Quantity/Commercial Management',
      'Testing & Commissioning',
      'Project Handover',
    ],
  ),
  JobSkillCategory(
    key: 'hse_safety',
    skills: [
      'HSE Management',
      'EHS',
      'Industrial Safety',
      'Process Safety',
      'Environmental Safety',
      'Permit-to-Work',
      'Emergency Response',
      'Safety Auditing',
      'Fire Safety',
      'Firefighting',
    ],
  ),
  JobSkillCategory(
    key: 'fire_emergency',
    skills: [
      'Fire & Safety Officer',
      'Fire Engineer',
      'Fire Supervisor',
      'Fire Technician',
      'Firefighter',
      'Emergency Response',
      'Emergency Preparedness',
    ],
  ),
  JobSkillCategory(
    key: 'quality_inspection',
    skills: [
      'QA/QC',
      'Quality Inspection',
      'Quality Engineering',
      'NDT',
      'Welding Inspection',
      'Mechanical Inspection',
      'Electrical Inspection',
      'Documentation & Quality Reporting',
    ],
  ),
  JobSkillCategory(
    key: 'plant_operations',
    skills: [
      'Plant Operations',
      'Equipment Maintenance',
      'Mechanical Maintenance',
      'Electrical Maintenance',
      'Instrumentation Maintenance',
      'Maintenance Planning',
      'Reliability',
      'Production Operations',
      'Supervisory Skills',
    ],
  ),
  JobSkillCategory(
    key: 'skilled_trades',
    skills: [
      'Electrician',
      'Fitter',
      'Welder',
      'Rigger',
      'Fabricator',
      'Technician',
      'Machine Operator',
      'Plant Operator',
      'Foreman',
      'Site Supervisor',
    ],
  ),
  JobSkillCategory(
    key: 'renewable_energy',
    skills: [
      'Solar EPC',
      'Solar O&M',
      'Wind Energy',
      'Electrical Power Systems',
      'SCADA',
      'Monitoring & Analytics',
      'Testing & Commissioning',
      'Renewable Energy QA/QC',
      'Environmental & HSE',
    ],
  ),
  JobSkillCategory(
    key: 'industrial_manufacturing',
    skills: [
      'Production',
      'Manufacturing Operations',
      'Industrial Automation',
      'Maintenance',
      'Quality Control',
      'Production Planning',
      'Process Operations',
      'Equipment Operations',
      'Smart Manufacturing',
    ],
  ),
  JobSkillCategory(
    key: 'automotive_ev',
    skills: [
      'Automotive Production',
      'EV Manufacturing',
      'Electrical Systems',
      'Mechanical Assembly',
      'Production Operations',
      'Quality Inspection',
      'Maintenance',
      'Industrial Automation',
    ],
  ),
  JobSkillCategory(
    key: 'oil_gas_energy',
    skills: [
      'Refinery Operations',
      'Petrochemical Operations',
      'Oil & Gas Maintenance',
      'Process Engineering',
      'HSE',
      'Fire Safety',
      'Shutdown & Turnaround',
      'Commissioning',
      'Inspection',
    ],
  ),
  JobSkillCategory(
    key: 'logistics_workforce',
    skills: [
      'Warehouse Operations',
      'Industrial Logistics',
      'Material Handling',
      'Inventory Management',
      'Supervisory Skills',
      'Workforce Coordination',
      'Shift Management',
    ],
  ),
];

/// Exactly 3 or 4 of the selected skills must be marked mandatory before
/// submitting — `MANDATORY_MIN`/`MANDATORY_MAX` (`job_form.html`'s inline
/// script), reproduced here for client-side guidance; the live server is
/// still the final authority (see `JobPostingRemoteDataSource`).
const int kMandatorySkillsMin = 3;
const int kMandatorySkillsMax = 4;

/// IT's free-typed custom skill (`addItSkill`, `job_form.html`): letters,
/// digits and ` .&/()'+#-` only, at most 40 characters, no commas.
final RegExp kCustomSkillPattern = RegExp(r"^[A-Za-z0-9 .&/()'+#-]+$");
const int kCustomSkillMaxLength = 40;
