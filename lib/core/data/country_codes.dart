/// Ported verbatim from `static/js/country-codes.js`'s `window.COUNTRY_CODES`
/// (name/iso2/dial-code triples for the `hr_contact` phone-input widget,
/// `templates/includes/phone_input.html`) — real reference data the web
/// itself ships, not invented. [minDigits]/[maxDigits] are the same file's
/// `window.COUNTRY_PHONE_LENGTHS` map, used identically: a client-side hint
/// only, never the final word (the server's `phonenumbers`-library check in
/// `users/forms.py: validate_international_mobile` always has the final
/// say — see that function's own doc comment).
class CountryDialCode {
  const CountryDialCode({
    required this.name,
    required this.iso2,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
  });

  final String name;
  final String iso2;
  final String dialCode;
  final int minDigits;
  final int maxDigits;

  /// `https://flagcdn.com/w20/<iso2>.png` — the same external CDN the web
  /// itself loads flags from (`phone-input.js`), not a bundled asset.
  String get flagUrl => 'https://flagcdn.com/w20/$iso2.png';
}

const List<CountryDialCode> kCountryDialCodes = [
  CountryDialCode(name: 'Afghanistan', iso2: 'af', dialCode: '+93', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Albania', iso2: 'al', dialCode: '+355', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Algeria', iso2: 'dz', dialCode: '+213', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'American Samoa', iso2: 'as', dialCode: '+1684', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Andorra', iso2: 'ad', dialCode: '+376', minDigits: 6, maxDigits: 6),
  CountryDialCode(name: 'Angola', iso2: 'ao', dialCode: '+244', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Anguilla', iso2: 'ai', dialCode: '+1264', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Antigua and Barbuda', iso2: 'ag', dialCode: '+1268', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Argentina', iso2: 'ar', dialCode: '+54', minDigits: 10, maxDigits: 11),
  CountryDialCode(name: 'Armenia', iso2: 'am', dialCode: '+374', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Aruba', iso2: 'aw', dialCode: '+297', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Australia', iso2: 'au', dialCode: '+61', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Austria', iso2: 'at', dialCode: '+43', minDigits: 10, maxDigits: 13),
  CountryDialCode(name: 'Azerbaijan', iso2: 'az', dialCode: '+994', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Bahamas', iso2: 'bs', dialCode: '+1242', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Bahrain', iso2: 'bh', dialCode: '+973', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Bangladesh', iso2: 'bd', dialCode: '+880', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Barbados', iso2: 'bb', dialCode: '+1246', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Belarus', iso2: 'by', dialCode: '+375', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Belgium', iso2: 'be', dialCode: '+32', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Belize', iso2: 'bz', dialCode: '+501', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Benin', iso2: 'bj', dialCode: '+229', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Bermuda', iso2: 'bm', dialCode: '+1441', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Bhutan', iso2: 'bt', dialCode: '+975', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Bolivia', iso2: 'bo', dialCode: '+591', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Bosnia and Herzegovina', iso2: 'ba', dialCode: '+387', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Botswana', iso2: 'bw', dialCode: '+267', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Brazil', iso2: 'br', dialCode: '+55', minDigits: 10, maxDigits: 11),
  CountryDialCode(name: 'British Virgin Islands', iso2: 'vg', dialCode: '+1284', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Brunei', iso2: 'bn', dialCode: '+673', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Bulgaria', iso2: 'bg', dialCode: '+359', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Burkina Faso', iso2: 'bf', dialCode: '+226', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Burundi', iso2: 'bi', dialCode: '+257', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Cambodia', iso2: 'kh', dialCode: '+855', minDigits: 8, maxDigits: 9),
  CountryDialCode(name: 'Cameroon', iso2: 'cm', dialCode: '+237', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Canada', iso2: 'ca', dialCode: '+1', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Cape Verde', iso2: 'cv', dialCode: '+238', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Cayman Islands', iso2: 'ky', dialCode: '+1345', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Central African Republic', iso2: 'cf', dialCode: '+236', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Chad', iso2: 'td', dialCode: '+235', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Chile', iso2: 'cl', dialCode: '+56', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'China', iso2: 'cn', dialCode: '+86', minDigits: 11, maxDigits: 11),
  CountryDialCode(name: 'Colombia', iso2: 'co', dialCode: '+57', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Comoros', iso2: 'km', dialCode: '+269', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Congo (DRC)', iso2: 'cd', dialCode: '+243', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Congo (Republic)', iso2: 'cg', dialCode: '+242', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Costa Rica', iso2: 'cr', dialCode: '+506', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Croatia', iso2: 'hr', dialCode: '+385', minDigits: 8, maxDigits: 9),
  CountryDialCode(name: 'Cuba', iso2: 'cu', dialCode: '+53', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Curacao', iso2: 'cw', dialCode: '+599', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Cyprus', iso2: 'cy', dialCode: '+357', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Czech Republic', iso2: 'cz', dialCode: '+420', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Denmark', iso2: 'dk', dialCode: '+45', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Djibouti', iso2: 'dj', dialCode: '+253', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Dominica', iso2: 'dm', dialCode: '+1767', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Dominican Republic', iso2: 'do', dialCode: '+1809', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Ecuador', iso2: 'ec', dialCode: '+593', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Egypt', iso2: 'eg', dialCode: '+20', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'El Salvador', iso2: 'sv', dialCode: '+503', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Equatorial Guinea', iso2: 'gq', dialCode: '+240', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Eritrea', iso2: 'er', dialCode: '+291', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Estonia', iso2: 'ee', dialCode: '+372', minDigits: 7, maxDigits: 8),
  CountryDialCode(name: 'Eswatini', iso2: 'sz', dialCode: '+268', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Ethiopia', iso2: 'et', dialCode: '+251', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Fiji', iso2: 'fj', dialCode: '+679', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Finland', iso2: 'fi', dialCode: '+358', minDigits: 9, maxDigits: 10),
  CountryDialCode(name: 'France', iso2: 'fr', dialCode: '+33', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'French Guiana', iso2: 'gf', dialCode: '+594', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'French Polynesia', iso2: 'pf', dialCode: '+689', minDigits: 6, maxDigits: 6),
  CountryDialCode(name: 'Gabon', iso2: 'ga', dialCode: '+241', minDigits: 7, maxDigits: 8),
  CountryDialCode(name: 'Gambia', iso2: 'gm', dialCode: '+220', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Georgia', iso2: 'ge', dialCode: '+995', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Germany', iso2: 'de', dialCode: '+49', minDigits: 7, maxDigits: 11),
  CountryDialCode(name: 'Ghana', iso2: 'gh', dialCode: '+233', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Gibraltar', iso2: 'gi', dialCode: '+350', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Greece', iso2: 'gr', dialCode: '+30', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Greenland', iso2: 'gl', dialCode: '+299', minDigits: 6, maxDigits: 6),
  CountryDialCode(name: 'Grenada', iso2: 'gd', dialCode: '+1473', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Guadeloupe', iso2: 'gp', dialCode: '+590', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Guam', iso2: 'gu', dialCode: '+1671', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Guatemala', iso2: 'gt', dialCode: '+502', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Guinea', iso2: 'gn', dialCode: '+224', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Guinea-Bissau', iso2: 'gw', dialCode: '+245', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Guyana', iso2: 'gy', dialCode: '+592', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Haiti', iso2: 'ht', dialCode: '+509', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Honduras', iso2: 'hn', dialCode: '+504', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Hong Kong', iso2: 'hk', dialCode: '+852', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Hungary', iso2: 'hu', dialCode: '+36', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Iceland', iso2: 'is', dialCode: '+354', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'India', iso2: 'in', dialCode: '+91', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Indonesia', iso2: 'id', dialCode: '+62', minDigits: 9, maxDigits: 12),
  CountryDialCode(name: 'Iran', iso2: 'ir', dialCode: '+98', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Iraq', iso2: 'iq', dialCode: '+964', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Ireland', iso2: 'ie', dialCode: '+353', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Israel', iso2: 'il', dialCode: '+972', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Italy', iso2: 'it', dialCode: '+39', minDigits: 9, maxDigits: 10),
  CountryDialCode(name: 'Ivory Coast', iso2: 'ci', dialCode: '+225', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Jamaica', iso2: 'jm', dialCode: '+1876', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Japan', iso2: 'jp', dialCode: '+81', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Jordan', iso2: 'jo', dialCode: '+962', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Kazakhstan', iso2: 'kz', dialCode: '+7', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Kenya', iso2: 'ke', dialCode: '+254', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Kiribati', iso2: 'ki', dialCode: '+686', minDigits: 5, maxDigits: 5),
  CountryDialCode(name: 'Kosovo', iso2: 'xk', dialCode: '+383', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Kuwait', iso2: 'kw', dialCode: '+965', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Kyrgyzstan', iso2: 'kg', dialCode: '+996', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Laos', iso2: 'la', dialCode: '+856', minDigits: 8, maxDigits: 9),
  CountryDialCode(name: 'Latvia', iso2: 'lv', dialCode: '+371', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Lebanon', iso2: 'lb', dialCode: '+961', minDigits: 7, maxDigits: 8),
  CountryDialCode(name: 'Lesotho', iso2: 'ls', dialCode: '+266', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Liberia', iso2: 'lr', dialCode: '+231', minDigits: 7, maxDigits: 8),
  CountryDialCode(name: 'Libya', iso2: 'ly', dialCode: '+218', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Liechtenstein', iso2: 'li', dialCode: '+423', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Lithuania', iso2: 'lt', dialCode: '+370', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Luxembourg', iso2: 'lu', dialCode: '+352', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Macau', iso2: 'mo', dialCode: '+853', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Madagascar', iso2: 'mg', dialCode: '+261', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Malawi', iso2: 'mw', dialCode: '+265', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Malaysia', iso2: 'my', dialCode: '+60', minDigits: 9, maxDigits: 10),
  CountryDialCode(name: 'Maldives', iso2: 'mv', dialCode: '+960', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Mali', iso2: 'ml', dialCode: '+223', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Malta', iso2: 'mt', dialCode: '+356', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Marshall Islands', iso2: 'mh', dialCode: '+692', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Martinique', iso2: 'mq', dialCode: '+596', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Mauritania', iso2: 'mr', dialCode: '+222', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Mauritius', iso2: 'mu', dialCode: '+230', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Mexico', iso2: 'mx', dialCode: '+52', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Micronesia', iso2: 'fm', dialCode: '+691', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Moldova', iso2: 'md', dialCode: '+373', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Monaco', iso2: 'mc', dialCode: '+377', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Mongolia', iso2: 'mn', dialCode: '+976', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Montenegro', iso2: 'me', dialCode: '+382', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Montserrat', iso2: 'ms', dialCode: '+1664', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Morocco', iso2: 'ma', dialCode: '+212', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Mozambique', iso2: 'mz', dialCode: '+258', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Myanmar', iso2: 'mm', dialCode: '+95', minDigits: 7, maxDigits: 10),
  CountryDialCode(name: 'Namibia', iso2: 'na', dialCode: '+264', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Nauru', iso2: 'nr', dialCode: '+674', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Nepal', iso2: 'np', dialCode: '+977', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Netherlands', iso2: 'nl', dialCode: '+31', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'New Caledonia', iso2: 'nc', dialCode: '+687', minDigits: 6, maxDigits: 6),
  CountryDialCode(name: 'New Zealand', iso2: 'nz', dialCode: '+64', minDigits: 8, maxDigits: 9),
  CountryDialCode(name: 'Nicaragua', iso2: 'ni', dialCode: '+505', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Niger', iso2: 'ne', dialCode: '+227', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Nigeria', iso2: 'ng', dialCode: '+234', minDigits: 7, maxDigits: 10),
  CountryDialCode(name: 'North Korea', iso2: 'kp', dialCode: '+850', minDigits: 6, maxDigits: 10),
  CountryDialCode(name: 'North Macedonia', iso2: 'mk', dialCode: '+389', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Norway', iso2: 'no', dialCode: '+47', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Oman', iso2: 'om', dialCode: '+968', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Pakistan', iso2: 'pk', dialCode: '+92', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Palau', iso2: 'pw', dialCode: '+680', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Palestine', iso2: 'ps', dialCode: '+970', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Panama', iso2: 'pa', dialCode: '+507', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Papua New Guinea', iso2: 'pg', dialCode: '+675', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Paraguay', iso2: 'py', dialCode: '+595', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Peru', iso2: 'pe', dialCode: '+51', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Philippines', iso2: 'ph', dialCode: '+63', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Poland', iso2: 'pl', dialCode: '+48', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Portugal', iso2: 'pt', dialCode: '+351', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Puerto Rico', iso2: 'pr', dialCode: '+1787', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Qatar', iso2: 'qa', dialCode: '+974', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Reunion', iso2: 're', dialCode: '+262', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Romania', iso2: 'ro', dialCode: '+40', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Russia', iso2: 'ru', dialCode: '+7', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Rwanda', iso2: 'rw', dialCode: '+250', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Saint Kitts and Nevis', iso2: 'kn', dialCode: '+1869', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Saint Lucia', iso2: 'lc', dialCode: '+1758', minDigits: 10, maxDigits: 10),
  CountryDialCode(
    name: 'Saint Vincent and the Grenadines',
    iso2: 'vc',
    dialCode: '+1784',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryDialCode(name: 'Samoa', iso2: 'ws', dialCode: '+685', minDigits: 5, maxDigits: 7),
  CountryDialCode(name: 'San Marino', iso2: 'sm', dialCode: '+378', minDigits: 6, maxDigits: 10),
  CountryDialCode(name: 'Sao Tome and Principe', iso2: 'st', dialCode: '+239', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Saudi Arabia', iso2: 'sa', dialCode: '+966', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Senegal', iso2: 'sn', dialCode: '+221', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Serbia', iso2: 'rs', dialCode: '+381', minDigits: 8, maxDigits: 9),
  CountryDialCode(name: 'Seychelles', iso2: 'sc', dialCode: '+248', minDigits: 7, maxDigits: 7),
  CountryDialCode(name: 'Sierra Leone', iso2: 'sl', dialCode: '+232', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Singapore', iso2: 'sg', dialCode: '+65', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Slovakia', iso2: 'sk', dialCode: '+421', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Slovenia', iso2: 'si', dialCode: '+386', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Solomon Islands', iso2: 'sb', dialCode: '+677', minDigits: 5, maxDigits: 7),
  CountryDialCode(name: 'Somalia', iso2: 'so', dialCode: '+252', minDigits: 7, maxDigits: 8),
  CountryDialCode(name: 'South Africa', iso2: 'za', dialCode: '+27', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'South Korea', iso2: 'kr', dialCode: '+82', minDigits: 9, maxDigits: 10),
  CountryDialCode(name: 'South Sudan', iso2: 'ss', dialCode: '+211', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Spain', iso2: 'es', dialCode: '+34', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Sri Lanka', iso2: 'lk', dialCode: '+94', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Sudan', iso2: 'sd', dialCode: '+249', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Suriname', iso2: 'sr', dialCode: '+597', minDigits: 6, maxDigits: 7),
  CountryDialCode(name: 'Sweden', iso2: 'se', dialCode: '+46', minDigits: 7, maxDigits: 9),
  CountryDialCode(name: 'Switzerland', iso2: 'ch', dialCode: '+41', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Syria', iso2: 'sy', dialCode: '+963', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Taiwan', iso2: 'tw', dialCode: '+886', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Tajikistan', iso2: 'tj', dialCode: '+992', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Tanzania', iso2: 'tz', dialCode: '+255', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Thailand', iso2: 'th', dialCode: '+66', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Timor-Leste', iso2: 'tl', dialCode: '+670', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Togo', iso2: 'tg', dialCode: '+228', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Tonga', iso2: 'to', dialCode: '+676', minDigits: 5, maxDigits: 7),
  CountryDialCode(name: 'Trinidad and Tobago', iso2: 'tt', dialCode: '+1868', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Tunisia', iso2: 'tn', dialCode: '+216', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Turkey', iso2: 'tr', dialCode: '+90', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Turkmenistan', iso2: 'tm', dialCode: '+993', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Turks and Caicos Islands', iso2: 'tc', dialCode: '+1649', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Tuvalu', iso2: 'tv', dialCode: '+688', minDigits: 5, maxDigits: 6),
  CountryDialCode(name: 'Uganda', iso2: 'ug', dialCode: '+256', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Ukraine', iso2: 'ua', dialCode: '+380', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'United Arab Emirates', iso2: 'ae', dialCode: '+971', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'United Kingdom', iso2: 'gb', dialCode: '+44', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'United States', iso2: 'us', dialCode: '+1', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Uruguay', iso2: 'uy', dialCode: '+598', minDigits: 8, maxDigits: 8),
  CountryDialCode(name: 'Uzbekistan', iso2: 'uz', dialCode: '+998', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Vanuatu', iso2: 'vu', dialCode: '+678', minDigits: 5, maxDigits: 7),
  CountryDialCode(name: 'Vatican City', iso2: 'va', dialCode: '+379', minDigits: 6, maxDigits: 10),
  CountryDialCode(name: 'Venezuela', iso2: 've', dialCode: '+58', minDigits: 10, maxDigits: 10),
  CountryDialCode(name: 'Vietnam', iso2: 'vn', dialCode: '+84', minDigits: 9, maxDigits: 10),
  CountryDialCode(name: 'Yemen', iso2: 'ye', dialCode: '+967', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Zambia', iso2: 'zm', dialCode: '+260', minDigits: 9, maxDigits: 9),
  CountryDialCode(name: 'Zimbabwe', iso2: 'zw', dialCode: '+263', minDigits: 5, maxDigits: 9),
];

/// `data-default-country="in"` (`templates/includes/phone_input.html:63`).
const CountryDialCode kDefaultCountryDialCode = CountryDialCode(
  name: 'India',
  iso2: 'in',
  dialCode: '+91',
  minDigits: 10,
  maxDigits: 10,
);

/// Normalizes a stored phone value to a real E.164 string (`"+91XXXXXXXXXX"`),
/// the same way `EmployerPhoneInputField`'s own `initState` parses its
/// `initialE164` input — extracted here so every call site gets it, not
/// just whichever one happens to render the picker widget.
///
/// Matters because a caller that reads an existing profile's `mobile` value
/// and sends it straight back on save (without ever mounting/touching the
/// picker — e.g. a user who edits an unrelated field) must submit the same
/// `+<dial-code><digits>` shape the picker would have produced, not the
/// bare digits some existing accounts have stored (confirmed live: a real
/// production profile's `mobile` came back as plain digits, no leading
/// `+91`) — the server's own phone validation rejects a bare number with no
/// dial code, which otherwise fails *every* save that doesn't happen to
/// touch this one field.
String normalizePhoneToE164(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return '';
  if (value.startsWith('+')) {
    CountryDialCode? bestMatch;
    for (final c in kCountryDialCodes) {
      if (value.startsWith(c.dialCode) && (bestMatch == null || c.dialCode.length > bestMatch.dialCode.length)) {
        bestMatch = c;
      }
    }
    if (bestMatch != null) return value;
    return value; // Unrecognized dial code prefix — pass through as-is rather than guess.
  }
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? '' : '${kDefaultCountryDialCode.dialCode}$digits';
}
