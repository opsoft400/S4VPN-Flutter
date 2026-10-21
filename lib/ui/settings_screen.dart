import 'package:flutter/material.dart';

import '../l10n/translator.dart';
import '../models/field_spec.dart';
import '../models/schema.dart';
import '../models/vpn_config.dart';
import '../engine/plan.dart';
import '../models/white_servers.dart';
import '../state/app_state.dart';
import '../theme/s4_theme.dart';
import 'app_scope.dart';

/// The settings tab: two accordions of data-driven fields, the language picker,
/// and the reset button outside them all.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final VpnConfig config = state.config;
        final List<SectionSpec> sections = <SectionSpec>[
          ...kMethodSections.where((SectionSpec s) => s.isVisible(config)),
          ...kAdvancedSections.where((SectionSpec s) => s.isVisible(config)),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          children: <Widget>[
            Text(
              state.tr('تنظیمات'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
            ),
            Text(
              state.tr('روش اتصال'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.mute),
            ),
            const SizedBox(height: 8),
            for (final SectionSpec section in sections.take(_methodCount(state)))
              _SectionCard(section: section),
            const SizedBox(height: 4),
            Text(
              state.tr('تنظیمات پیشرفته'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.mute),
            ),
            const SizedBox(height: 8),
            for (final SectionSpec section in sections.skip(_methodCount(state)))
              _SectionCard(section: section),
            const SizedBox(height: 4),
            _LanguageCard(palette: palette),
            const SizedBox(height: 14),
            _ResetButton(palette: palette),
          ],
        );
      },
    );
  }

  int _methodCount(AppState state) =>
      kMethodSections.where((SectionSpec s) => s.isVisible(state.config)).length;
}

/// An accordion. `details` in the preview, a `ExpansionTile` here -- same
/// behaviour, same position in the reading order.
class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section});

  final SectionSpec section;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.section.open;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);
    final SectionSpec section = widget.section;
    final VpnConfig config = state.config;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      state.tr(section.title),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Transform.rotate(
                    angle: _open ? 3.1415926 : 0,
                    child: Icon(Icons.arrow_drop_down, color: palette.mute, size: 22),
                  ),
                ],
              ),
            ),
          ),
          if (section.note != null && _open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                state.tr(section.note!),
                style: TextStyle(fontSize: 12, color: palette.mute, height: 1.9),
              ),
            ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final FieldSpec field in section.fields)
                    if (field.isVisible(config))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _FieldView(field: field),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One control, drawn from its [FieldSpec].
class _FieldView extends StatelessWidget {
  const _FieldView({required this.field});

  final FieldSpec field;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final S4Palette palette = paletteOf(context);

    if (field.type == 'note') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.warnBorder),
          color: palette.warnBackground,
        ),
        child: Text(
          state.tr(field.text ?? ''),
          style: TextStyle(fontSize: 12, color: palette.warnInk, height: 1.8),
        ),
      );
    }

    if (field.type == 'sw') {
      final bool value = state.config.boolOf(field.key!);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Label(field: field, palette: palette),
                if (field.help != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      state.tr(field.help!),
                      style: TextStyle(fontSize: 12, color: palette.mute, height: 1.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Switch(
            value: value,
            palette: palette,
            onChanged: (bool next) => state.setKey(field.key!, next),
          ),
        ],
      );
    }

    final String help = field.helpText(state.config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Label(field: field, palette: palette),
        if (help.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              state.tr(help),
              style: TextStyle(fontSize: 12, color: palette.mute, height: 1.7),
            ),
          ),
        if (field.type == 'seg')
          _Segment(field: field, palette: palette)
        else if (field.type == 'servers')
          _ServerList(palette: palette)
        else
          _Input(field: field, palette: palette),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.field, required this.palette});

  final FieldSpec field;
  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          state.tr(field.label ?? ''),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if ((field.flag ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsetsDirectional.only(start: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: palette.blue.withValues(alpha: 0.12),
            ),
            child: Text(
              field.flag!,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: kMonoFont,
                fontSize: 10.5,
                color: palette.blue,
              ),
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.field, required this.palette});

  final FieldSpec field;
  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String current = state.config.textOf(field.key!);
    final List<List<String>> options = field.options ?? const <List<String>>[];
    final int columns = field.columns ?? options.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final List<String> option in options)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = columns > 0
                  ? ((constraints.maxWidth - 6 * (columns - 1)) / columns)
                      .clamp(0, constraints.maxWidth)
                  : constraints.maxWidth;
              final bool selected = current == option[0];
              final bool disabled = field.isDisabled(option[0]);
              return SizedBox(
                width: width,
                child: Opacity(
                  opacity: disabled ? 0.3 : 1,
                  child: Material(
                    color: selected
                        ? null
                        : palette.dark
                            ? const Color(0x0DFFFFFF)
                            : const Color(0x0D0A1410),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      decoration: selected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: <Color>[palette.segFrom, palette.segTo],
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: palette.blue.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.line.withValues(alpha: 0.5)),
                            ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: disabled ? null : () => state.setKey(field.key!, option[0]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Text(
                            state.tr(option[1]),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? palette.segInk : palette.mute,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  final bool value;
  final S4Palette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 28,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: value ? palette.blue : palette.switchOff,
          boxShadow: value
              ? <BoxShadow>[BoxShadow(color: palette.blue.withValues(alpha: 0.5), blurRadius: 14)]
              : null,
        ),
        child: Align(
          alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.field, required this.palette});

  final FieldSpec field;
  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String value = state.config.textOf(field.key ?? '');
    final bool multiline = field.type == 'area';

    // Keyed on the value so an edit from outside -- a reset, another control
    // changing a dependent field -- replaces the box, while typing inside it
    // never does and the cursor stays where it was.
    return TextFormField(
      key: ValueKey<String>('${field.key}=$value'),
      initialValue: value,
      maxLines: multiline ? null : 1,
      minLines: multiline ? 3 : 1,
      keyboardType:
          field.type == 'num' ? TextInputType.number : TextInputType.multiline,
      textDirection: TextDirection.ltr,
      onChanged: (String next) => state.setKey(field.key!, next),
      style: TextStyle(fontFamily: kMonoFont, fontSize: 14, color: palette.ink),
      decoration: InputDecoration(
        hintText: field.placeholder,
        hintStyle: TextStyle(
          fontFamily: kMonoFont,
          fontSize: 14,
          color: palette.mute.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: palette.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.blue, width: 1.4),
        ),
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  const _ServerList({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String pick = state.config.textOf('whServerPick');
    final List<WhiteServer> servers = orderedWhiteServers(state.config);
    final WhiteServer active = activeWhiteServer(state.config);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _Choice(
              label: state.tr('خودکار (سریع‌ترین)'),
              selected: pick == 'auto',
              palette: palette,
              onTap: () => state.setKey('whServerPick', 'auto'),
            ),
            _Choice(
              label: state.tr('انتخاب دستی'),
              selected: pick == 'manual',
              palette: palette,
              onTap: () => state.setKey('whServerPick', 'manual'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                pick == 'auto' ? '${active.name} · ${state.tr('خودکار')}' : active.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: state.retestServers,
              child: Text(
                state.tr('تست دوباره'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.teal),
              ),
            ),
          ],
        ),
        Container(
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: palette.line,
          ),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: state.serverTestProgress,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: palette.teal,
              ),
            ),
          ),
        ),
        for (final WhiteServer server in servers)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => state.pickServer(server.name),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: server.name == active.name ? palette.selectedRowBorder : Colors.transparent,
                ),
                color: server.name == active.name ? palette.selectedRowFill : palette.card,
              ),
              child: Row(
                children: <Widget>[
                  Text(server.flag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.tr(server.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.line),
                      color: palette.card,
                    ),
                    child: Text(
                      server.protocol,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.mute),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    state.tr('${server.latency} ms'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: switch (latencyBand(server.latency)) {
                        LatencyBand.ok => palette.teal,
                        LatencyBand.mid => palette.amber,
                        LatencyBand.bad => palette.red,
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final S4Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.blue.withValues(alpha: 0.16) : palette.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? palette.blue : palette.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? palette.blue : palette.mute,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        color: palette.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                state.tr('زبان'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.language,
              isExpanded: true,
              dropdownColor: palette.dark ? const Color(0xFF0B1226) : Colors.white,
              items: <DropdownMenuItem<String>>[
                for (final String code in kSupportedLanguages)
                  DropdownMenuItem<String>(
                    value: code,
                    child: Text(
                      _nameOf(code),
                      style: TextStyle(fontSize: 14, color: palette.ink),
                    ),
                  ),
              ],
              onChanged: (String? next) {
                if (next != null) state.setLanguage(next);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _nameOf(String code) => switch (code) {
        'fa' => 'فارسی',
        'en' => 'English',
        'zh' => '中文',
        'ja' => '日本語',
        'de' => 'Deutsch',
        'ru' => 'Русский',
        _ => code,
      };
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.palette});

  final S4Palette palette;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final bool enabled = state.state == ConnState.idle;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: palette.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? state.resetToDefaults : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.settings_backup_restore, size: 17, color: palette.red),
                const SizedBox(width: 8),
                Text(
                  state.tr('بازگشت به تنظیمات اولیه'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
