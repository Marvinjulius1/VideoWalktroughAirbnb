import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/providers.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/lumen_button.dart';
import '../../../core/widgets/lumen_card.dart';
import '../../../core/widgets/lumen_page.dart';
import '../../../core/widgets/lumen_text_field.dart';
import '../data/playlist_file_store.dart';
import '../domain/source_profile.dart';
import '../domain/url_validation.dart';
import 'source_type_ui.dart';

final playlistFileStoreProvider = Provider((ref) => PlaylistFileStore());

/// Formular zum Anlegen oder Bearbeiten einer Quelle.
///
/// Der Verbindungstest kommt in Phase 2 dazu (Xtream-Client/M3U-Parser).
/// Bis dahin wird nur die Eingabe geprüft.
class SourceFormScreen extends ConsumerStatefulWidget {
  const SourceFormScreen({super.key, required this.type, this.editId});

  final SourceType type;
  final String? editId;

  @override
  ConsumerState<SourceFormScreen> createState() => _SourceFormScreenState();
}

class _SourceFormScreenState extends ConsumerState<SourceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _playlist = TextEditingController();
  final _epg = TextEditingController();

  SourceProfile? _existing;
  String? _pickedPath;
  String? _pickedName;
  String? _fileError;
  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(sourcesRepositoryProvider);
    final profile = await repo.byId(widget.editId!);
    if (profile == null) {
      if (mounted) context.pop();
      return;
    }
    final c = await repo.credentials(profile.id);
    if (!mounted) return;
    setState(() {
      _existing = profile;
      _name.text = profile.name;
      _server.text = profile.serverUrl ?? '';
      _user.text = c.username ?? '';
      _pass.text = c.password ?? '';
      _playlist.text = c.playlistUrl ?? '';
      _epg.text = c.epgUrl ?? '';
      _pickedName = profile.localFileName;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _server, _user, _pass, _playlist, _epg]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).errRequired : null;

  String? _urlMessage(UrlCheck c) {
    final t = AppLocalizations.of(context);
    return switch (c.problem) {
      null => null,
      UrlProblem.empty => t.errRequired,
      UrlProblem.invalid => t.errUrlInvalid,
      UrlProblem.scheme => t.errUrlScheme,
      UrlProblem.port => t.errPort,
    };
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    final path = files.firstOrNull?.path;
    if (path == null) return;
    setState(() {
      _pickedPath = path;
      _pickedName = files.first.name;
      _fileError = null;
      if (_name.text.trim().isEmpty) {
        _name.text = _pickedName!.replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), '');
      }
    });
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final formOk = _form.currentState!.validate();
    final needsFile = widget.type == SourceType.m3uFile &&
        _pickedPath == null &&
        _existing?.localPath == null;
    if (needsFile) setState(() => _fileError = t.errFileRequired);
    if (!formOk || needsFile) return;

    setState(() => _saving = true);
    final repo = ref.read(sourcesRepositoryProvider);
    final files = ref.read(playlistFileStoreProvider);
    String? newFile;
    try {
      if (_pickedPath != null) newFile = await files.import(_pickedPath!);

      final epg = validateResourceUrl(_epg.text, optional: true).url;
      final creds = switch (widget.type) {
        SourceType.xtream =>
          SourceCredentials(username: _user.text.trim(), password: _pass.text),
        SourceType.m3uUrl => SourceCredentials(
            playlistUrl: _playlist.text.trim(),
            epgUrl: (epg?.isEmpty ?? true) ? null : epg,
          ),
        SourceType.m3uFile =>
          SourceCredentials(epgUrl: (epg?.isEmpty ?? true) ? null : epg),
      };
      final server = widget.type == SourceType.xtream
          ? normalizeServerUrl(_server.text).url
          : null;

      if (_existing != null) {
        final old = _existing!;
        await repo.update(
          old.copyWith(
            name: _name.text,
            serverUrl: server,
            localPath: newFile,
            localFileName: newFile != null ? _pickedName : null,
          ),
          creds,
        );
        if (newFile != null) await files.remove(old.localPath);
      } else {
        await repo.add(
          name: _name.text,
          type: widget.type,
          credentials: creds,
          serverUrl: server,
          localPath: newFile,
          localFileName: newFile != null ? _pickedName : null,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sourceSaved)));
      if (_isEdit) {
        context.pop();
      } else {
        context.go('/home');
      }
    } on PlaylistImportException catch (e) {
      setState(() => _fileError = e.error == PlaylistImportError.notM3u
          ? t.errNotM3u
          : t.errFileRead);
    } catch (_) {
      if (newFile != null) await files.remove(newFile);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.sourceSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final gap = const SizedBox(height: LumenSpace.lg);

    final fields = <Widget>[
      LumenTextField(
        key: const Key('field-name'),
        label: t.fieldName,
        hint: t.fieldNameHint,
        controller: _name,
        validator: _required,
        autofocus: !_isEdit && !l.isTv,
      ),
      gap,
      ...switch (widget.type) {
        SourceType.xtream => [
            LumenTextField(
              key: const Key('field-server'),
              label: t.fieldServer,
              hint: t.fieldServerHint,
              controller: _server,
              keyboardType: TextInputType.url,
              validator: (v) => _urlMessage(normalizeServerUrl(v ?? '')),
            ),
            gap,
            LumenTextField(
              key: const Key('field-username'),
              label: t.fieldUsername,
              controller: _user,
              validator: _required,
              autofillHints: const [AutofillHints.username],
            ),
            gap,
            LumenTextField(
              key: const Key('field-password'),
              label: t.fieldPassword,
              controller: _pass,
              obscure: true,
              validator: _required,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _save(),
            ),
          ],
        SourceType.m3uUrl => [
            LumenTextField(
              key: const Key('field-playlist'),
              label: t.fieldPlaylistUrl,
              hint: t.fieldPlaylistUrlHint,
              controller: _playlist,
              keyboardType: TextInputType.url,
              validator: (v) => _urlMessage(validateResourceUrl(v ?? '')),
            ),
            gap,
            _epgField(t),
          ],
        SourceType.m3uFile => [
            _FilePickerTile(
              fileName: _pickedName,
              error: _fileError,
              onPick: _pickFile,
            ),
            gap,
            _epgField(t),
          ],
      },
      const SizedBox(height: LumenSpace.xxl),
      LumenButton(
        key: const Key('save-source'),
        label: t.save,
        loading: _saving,
        onPressed: _save,
      ),
    ];

    return Scaffold(
      appBar: AppBar(),
      body: _loading
          ? const SizedBox.shrink()
          : Form(
              key: _form,
              child: AutofillGroup(
                child: LumenPage(
                  title: _isEdit ? t.editSourceTitle : widget.type.label(t),
                  subtitle: _isEdit ? null : widget.type.description(t),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: fields,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _epgField(AppLocalizations t) => LumenTextField(
        key: const Key('field-epg'),
        label: t.fieldEpgUrl,
        helper: t.fieldEpgUrlHelper,
        controller: _epg,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        validator: (v) => _urlMessage(validateResourceUrl(v ?? '', optional: true)),
      );
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({required this.fileName, required this.error, required this.onPick});

  final String? fileName;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: LumenSpace.xxs, bottom: LumenSpace.xs),
          child: Text(t.fieldFile, style: l.text.subhead.copyWith(color: p.textSecondary)),
        ),
        LumenCard(
          key: const Key('pick-file'),
          color: p.surface2,
          radius: LumenRadius.mdAll,
          onPressed: onPick,
          semanticLabel: fileName ?? t.chooseFile,
          child: Row(
            children: [
              Icon(fileName == null ? LucideIcons.filePlus : LucideIcons.fileText,
                  color: l.accent),
              const SizedBox(width: LumenSpace.sm),
              Expanded(
                child: Text(
                  fileName ?? t.chooseFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: l.text.body.copyWith(color: p.textPrimary),
                ),
              ),
              if (fileName != null)
                Text(t.changeFile, style: l.text.footnote.copyWith(color: l.accent)),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: LumenSpace.md, top: LumenSpace.xs),
            child: Text(error!, style: l.text.footnote.copyWith(color: p.error)),
          ),
      ],
    );
  }
}
