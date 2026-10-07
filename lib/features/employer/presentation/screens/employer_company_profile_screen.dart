import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/validators/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../../auth/presentation/widgets/employer_phone_input_field.dart';
import '../../domain/entities/employer_profile_form.dart';
import '../controllers/employer_profile_controller.dart';
import '../providers/employer_dashboard_providers.dart';

/// `jobs_app.views.employer_profile_create`/`employer_profile_edit`
/// (`templates/employer/profile_form.html`) — one Flutter destination for
/// both real web views: [isCreate] picks which URL is hit (see
/// `ApiEndpoints.employerProfileCreate`/`employerProfileEdit`), matching
/// how the web itself only differs in which view renders the same
/// template. Reached either by push, from the dashboard's "complete your
/// profile" prompt ([isCreate] true — see `EmployerDashboardScreen`'s
/// `_ProfileIncompleteView`), or from the nav drawer's "Company Profile"
/// item ([isCreate] false, a profile that's already complete).
class EmployerCompanyProfileScreen extends ConsumerWidget {
  const EmployerCompanyProfileScreen({required this.isCreate, super.key});

  final bool isCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerProfileControllerProvider(isCreate));

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreate ? 'Complete Company Profile' : 'Company Profile'),
        leading: drawerAwareBackLeading(context),
      ),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _ProfileForm(isCreate: isCreate, data: data),
            AsyncError() => AppErrorView(
              message: 'Could not load your company profile.',
              onRetry: () => ref.read(employerProfileControllerProvider(isCreate).notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.isCreate, required this.data});

  final bool isCreate;
  final EmployerProfileFormData data;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _companyName;
  late final TextEditingController _companyWebsite;
  late final TextEditingController _industry;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _companyAddress;
  late final TextEditingController _companyGst;
  final _companyPanTin = TextEditingController();
  late final TextEditingController _hrMail;

  late String _companySize;
  String _hrContactE164 = '';
  PlatformFile? _logo;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _companyName = TextEditingController(text: d.companyName);
    _companyWebsite = TextEditingController(text: d.companyWebsite);
    _industry = TextEditingController(text: d.industry);
    _location = TextEditingController(text: d.location);
    _description = TextEditingController(text: d.description);
    _companyAddress = TextEditingController(text: d.companyAddress);
    _companyGst = TextEditingController(text: d.companyGst);
    _hrMail = TextEditingController(text: d.hrMail);
    _companySize = d.companySize;
    _hrContactE164 = d.hrContactE164;
  }

  @override
  void dispose() {
    for (final c in [
      _companyName, _companyWebsite, _industry, _location, _description,
      _companyAddress, _companyGst, _companyPanTin, _hrMail,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isNotEmpty) setState(() => _logo = files.single);
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final submission = EmployerProfileSubmission(
      companyName: _companyName.text.trim(),
      companyWebsite: _companyWebsite.text.trim(),
      industry: _industry.text.trim(),
      companySize: _companySize,
      location: _location.text.trim(),
      description: _description.text.trim(),
      companyAddress: _companyAddress.text.trim(),
      companyGst: _companyGst.text.trim(),
      companyPanTin: _companyPanTin.text.trim(),
      hrContactE164: _hrContactE164,
      hrMail: _hrMail.text.trim(),
      companyLogoPath: _logo?.path,
    );

    final result = await ref.read(employerProfileControllerProvider(widget.isCreate).notifier).submit(submission);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isCreate ? 'Company profile created!' : 'Profile updated!')),
        );
        // Confirmed live: editing an existing profile (isCreate == false)
        // never navigates away, so without this the dashboard kept showing
        // its stale `EmployerProfileIncompleteFailure` state
        // (`employer_dashboard_screen.dart`'s `_ProfileIncompleteView`,
        // gated on the real `_employer_profile_complete` GST+PAN check) even
        // after the server had already accepted the new GSTIN/PAN — the
        // dashboard provider was never re-fetched to find out.
        ref.invalidate(employerDashboardControllerProvider);
        if (widget.isCreate) context.go(RoutePaths.employerDashboard);
      case Failed(failure: final failure):
        setState(() => _submitError = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panOnFile = widget.data.maskedPan.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Company Identity', [
              AppTextField(label: 'Company Name *', controller: _companyName, enabled: !_submitting, validator: Validators.required),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Industry *', controller: _industry, enabled: !_submitting, validator: Validators.required),
              const SizedBox(height: AppSpacing.sm),
              _companySizeDropdown(),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Location', controller: _location, enabled: !_submitting),
            ]),
            _section('Web Presence & Branding', [
              AppTextField(label: 'Website URL', controller: _companyWebsite, enabled: !_submitting),
              const SizedBox(height: AppSpacing.sm),
              _LogoPicker(fileName: _logo?.name, onPick: _submitting ? null : _pickLogo),
            ]),
            _section('About the Organization', [
              TextFormField(
                controller: _description,
                enabled: !_submitting,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Company Overview', isDense: true),
              ),
            ]),
            _section('Headquarters Location', [
              TextFormField(
                controller: _companyAddress,
                enabled: !_submitting,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Complete Office Address', isDense: true),
              ),
            ]),
            _section('Tax & Legal Registration', [
              AppTextField(label: 'Company GST (GSTIN) *', controller: _companyGst, enabled: !_submitting, validator: Validators.gst),
              const SizedBox(height: AppSpacing.sm),
              if (panOnFile) ...[
                Text('PAN on file: ${widget.data.maskedPan}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Leave blank to keep the current PAN unchanged.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              AppTextField(
                label: panOnFile ? 'New Company PAN / TIN (optional)' : 'Company PAN / TIN *',
                controller: _companyPanTin,
                enabled: !_submitting,
                validator: panOnFile ? Validators.pan : (v) => Validators.pan(v) ?? Validators.required(v, fieldName: 'PAN'),
              ),
            ]),
            _section('HR & Contact Details', [
              EmployerPhoneInputField(hint: 'HR Phone Number', initialE164: _hrContactE164, onChanged: (v) => _hrContactE164 = v),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'HR Email Address', controller: _hrMail, enabled: !_submitting, validator: Validators.email),
            ]),
            if (_submitError != null) ...[
              Text(_submitError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: widget.isCreate ? 'Create Company Profile' : 'Save Company Profile',
              icon: Icons.save_outlined,
              isLoading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _companySizeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _companySize.isEmpty ? null : _companySize,
      decoration: const InputDecoration(labelText: 'Company Size', isDense: true),
      items: [for (final o in kCompanySizeOptions) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
      onChanged: _submitting ? null : (v) => setState(() => _companySize = v ?? ''),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          border: Border.all(color: const Color(0xFF93C5FD), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF185ADB)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                fileName ?? 'Upload company logo (optional)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fileName == null ? const Color(0xFF64748B) : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
