import 'dart:io';

import 'package:denial_flutter_sdk/applications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory data;
  late DesktopAppsRepository repository;

  setUp(() {
    data = Directory.systemTemp.createTempSync('denial-desktop-actions');
    Directory('${data.path}/applications').createSync();
    repository = DesktopAppsRepository(
      paths: RuntimePaths(
        environment: <String, String>{
          'HOME': data.path,
          'XDG_DATA_HOME': data.path,
          'XDG_DATA_DIRS': '',
        },
      ),
    );
  });

  tearDown(() => data.deleteSync(recursive: true));

  Future<DesktopApp?> load(String content) {
    File('${data.path}/applications/test.desktop').writeAsStringSync(content);
    return repository.loadApplication('test.desktop');
  }

  test('lists the actions Actions= names, in its order, with their commands', () async {
    final app = await load('''
[Desktop Entry]
Type=Application
Name=Test
Exec=/usr/bin/test --launch
Actions=Information;Uninstall;

[Desktop Action Uninstall]
Name=Uninstall
Exec=/usr/bin/droidloomctl app uninstall org.example --user 0

[Desktop Action Information]
Name=Information
Name[zh]=信息
Exec=/usr/bin/droidloomctl app info org.example --user 0
''');

    expect(app, isNotNull);
    expect(app!.exec, '/usr/bin/test --launch');
    expect(app.actions.map((action) => action.id), <String>[
      'Information',
      'Uninstall',
    ]);
    expect(
      app.actions.last.exec,
      '/usr/bin/droidloomctl app uninstall org.example --user 0',
    );
  });

  test('skips actions that are unlisted, unnamed or have no command', () async {
    final app = await load('''
[Desktop Entry]
Type=Application
Name=Test
Exec=/usr/bin/test
Actions=Named;Missing;NoExec;

[Desktop Action Named]
Name=Named
Exec=/usr/bin/named

[Desktop Action NoExec]
Name=No command

[Desktop Action Unlisted]
Name=Unlisted
Exec=/usr/bin/unlisted
''');

    expect(app!.actions.map((action) => action.id), <String>['Named']);
  });

  test('an action group never changes the application entry', () async {
    final app = await load('''
[Desktop Entry]
Type=Application
Name=Test
Exec=/usr/bin/test
Actions=Other;

[Desktop Action Other]
Name=Other
Exec=/usr/bin/other
Icon=not-the-apps-icon
''');

    expect(app!.name, 'Test');
    expect(app.exec, '/usr/bin/test');
    expect(app.icon, isNull);
  });

  test('an entry opts out of Terminate with X-Denial-Terminate=false', () async {
    expect(
      (await load('[Desktop Entry]\nType=Application\nName=A\nExec=/a\n'))!
          .terminable,
      isTrue,
    );
    expect(
      (await load(
        '[Desktop Entry]\nType=Application\nName=A\nExec=/a\n'
        'X-Denial-Terminate=false\n',
      ))!.terminable,
      isFalse,
    );
  });
}
