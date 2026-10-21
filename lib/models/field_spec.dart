import 'help_text.dart';
import 'vpn_config.dart';

/// One control on the settings screen.
///
/// The preview renders every setting from data rather than from hand-written
/// markup, and so does this: a field knows its key, its Persian label, the
/// flag it maps to on the command line, when it is visible, and when it is
/// offered but disabled. The renderer walks the list and draws whatever it
/// finds; adding a setting is adding an entry, not adding a widget.
class FieldSpec {
  const FieldSpec({
    required this.type,
    this.key,
    this.label,
    this.flag,
    this.placeholder,
    this.help,
    this.helpKey,
    this.options,
    this.columns,
    this.show,
    this.enabledWhen,
    this.text,
  });

  /// `seg`, `sw`, `text`, `area`, `num`, `note` or `servers`.
  final String type;
  final String? key;
  final String? label;
  final String? flag;
  final String? placeholder;

  /// Static Persian help, shown verbatim under the control.
  final String? help;

  /// When help depends on the selected value, name the row of the Persian
  /// help table instead: `<helpKey>.<current value of key>` is looked up.
  final String? helpKey;

  /// Segmented options as `[value, persianLabel]` pairs.
  final List<List<String>>? options;

  final int? columns;
  final bool Function(VpnConfig config)? show;
  final bool Function(String value)? enabledWhen;

  /// Only used by the `note` type.
  final String? text;

  String helpText(VpnConfig config) {
    final String? key = helpKey;
    if (key != null) {
      final String value = config.textOf(this.key ?? '');
      return kHelp['$key.$value'] ?? '';
    }
    return help ?? '';
  }

  bool isVisible(VpnConfig config) => show == null || show!(config);

  bool isDisabled(String value) => enabledWhen != null && !enabledWhen!(value);
}

/// A group of fields behind one accordion.
class SectionSpec {
  const SectionSpec({
    required this.id,
    required this.title,
    required this.fields,
    this.note,
    this.open = false,
    this.show,
  });

  final String id;

  /// Persian title.
  final String title;
  final String? note;
  final bool open;
  final bool Function(VpnConfig config)? show;
  final List<FieldSpec> fields;

  bool isVisible(VpnConfig config) => show == null || show!(config);
}
