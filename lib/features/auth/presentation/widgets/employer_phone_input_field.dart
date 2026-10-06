import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/data/country_codes.dart';

/// `templates/includes/phone_input.html` / `static/js/phone-input.js` —
/// the country-code + local-number picker for `hr_contact`. Combines the
/// two into the same `"+dial-code digits"` E.164 string `syncHidden()`
/// computes, and shows the same "N-digit number"/"min-max digit number"
/// placeholder hint (`describeExpectedLength()`, `phone-input.js:36-40`).
///
/// Country flags load from `https://flagcdn.com/w20/<iso2>.png` — the same
/// external CDN the web itself uses (not a bundled asset) — falling back
/// to a generic globe icon if that network image fails to load.
class EmployerPhoneInputField extends StatefulWidget {
  const EmployerPhoneInputField({
    required this.onChanged,
    this.errorText,
    this.hint = 'HR Contact Number',
    this.initialE164,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? errorText;

  /// Reused as-is (not renamed) by student registration's `mobile`/
  /// `alternate_mobile`/`contact_person_mobile` fields (`users/forms.py`),
  /// which share the exact same `phone_input.html`/E.164 contract — only
  /// the placeholder text differs per field.
  final String hint;

  /// Pre-fills the country + number from an existing `"+dial-code-digits"`
  /// value (e.g. Profile Edit's current `mobile`). `null`
  /// (every other call site) keeps the previous default-country/empty-
  /// number behavior unchanged. Matched against [kCountryDialCodes] by
  /// longest-dial-code-prefix so e.g. `+1` (US) isn't picked over a real
  /// `+1xxx` Caribbean code sharing that prefix.
  final String? initialE164;

  @override
  State<EmployerPhoneInputField> createState() => _EmployerPhoneInputFieldState();
}

class _EmployerPhoneInputFieldState extends State<EmployerPhoneInputField> {
  late CountryDialCode _country;
  late final TextEditingController _numberController;

  @override
  void initState() {
    super.initState();
    _country = kDefaultCountryDialCode;
    var initialDigits = '';
    final initial = widget.initialE164?.trim();
    if (initial != null && initial.isNotEmpty) {
      if (initial.startsWith('+')) {
        CountryDialCode? bestMatch;
        for (final c in kCountryDialCodes) {
          if (initial.startsWith(c.dialCode) &&
              (bestMatch == null || c.dialCode.length > bestMatch.dialCode.length)) {
            bestMatch = c;
          }
        }
        if (bestMatch != null) {
          _country = bestMatch;
          initialDigits = initial.substring(bestMatch.dialCode.length);
        }
      } else {
        // Some existing accounts have a bare local number stored with no
        // leading "+<dial code>" (confirmed live against a real production
        // profile: `mobile` came back as plain digits, not full E.164) —
        // treat it as a local number under the default country rather than
        // silently discarding it.
        initialDigits = initial.replaceAll(RegExp(r'\D'), '');
      }
    }
    _numberController = TextEditingController(text: initialDigits);
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  String _expectedLengthHint(CountryDialCode country) {
    return country.minDigits == country.maxDigits
        ? '${country.minDigits}-digit number'
        : '${country.minDigits}-${country.maxDigits} digit number';
  }

  void _emitChange() {
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    widget.onChanged(digits.isEmpty ? '' : '${_country.dialCode}$digits');
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<CountryDialCode>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CountryPickerSheet(selected: _country),
    );
    if (selected != null) {
      setState(() {
        _country = selected;
        final maxDigits = selected.maxDigits;
        final current = _numberController.text.replaceAll(RegExp(r'\D'), '');
        if (current.length > maxDigits) {
          _numberController.text = current.substring(0, maxDigits);
        }
      });
      _emitChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `.phone-input-widget{display:flex;gap:.5rem}` (`phone_input.html:35`).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        _country.flagUrl,
                        width: 20,
                        height: 14,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.public, size: 14, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_country.dialCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                maxLength: _country.maxDigits,
                onChanged: (_) => _emitChange(),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: widget.hint,
                  helperText: _expectedLengthHint(_country),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(widget.errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final CountryDialCode selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? kCountryDialCodes
        : kCountryDialCodes
              .where((c) => c.name.toLowerCase().contains(query) || c.dialCode.contains(query))
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final country = results[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        country.flagUrl,
                        width: 24,
                        height: 16,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, size: 16),
                      ),
                    ),
                    title: Text(country.name),
                    trailing: Text(country.dialCode, style: const TextStyle(color: AppColors.textMuted)),
                    selected: country.iso2 == widget.selected.iso2,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
