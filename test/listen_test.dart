// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library listen_test;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mockito/mockito.dart';
import 'package:sky_tools/src/artifacts.dart';
import 'package:sky_tools/src/commands/listen.dart';
import 'package:test/test.dart';

import 'src/common.dart';

main() => defineTests();

defineTests() {
  group('listen', () {
    test('returns 0 when no device is connected', () {
      setupBuildPaths();
      ArtifactStore.packageRoot = 'packages';

      MockAndroidDevice android = new MockAndroidDevice();
      when(android.isConnected()).thenReturn(false);
      MockIOSDevice ios = new MockIOSDevice();
      when(ios.isConnected()).thenReturn(false);
      ListenCommand command =
          new ListenCommand(android: android, ios: ios, singleRun: true);

      CommandRunner runner = new CommandRunner('test_flutter', '')
        ..addCommand(command);
      return runner.run(['listen']).then((code) {
        expect(code, equals(0));
      }).catchError((e) {
        // ArtifactStore.getPath() seems to indicate that only Linux is
        // supported; we tolerate (expect?) exceptions on other platforms.
        if (Platform.isLinux) throw e;
      });
    });
  });
}
