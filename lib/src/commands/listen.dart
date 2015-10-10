// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library sky_tools.listen;

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../application_package.dart';
import '../device.dart';
import '../process.dart';
import 'build.dart';

final Logger _logging = new Logger('sky_tools.listen');

class ListenCommand extends Command {
  final name = 'listen';
  final description = 'Listen for changes to files and reload the running app '
      'on all connected devices.';
  AndroidDevice android;
  IOSDevice ios;
  List<String> watchCommand;

  /// Only run once.  Used for testing.
  bool singleRun;

  ListenCommand({this.android, this.ios, this.singleRun: false}) {}

  @override
  Future<int> run() async {
    if (android == null) {
      android = new AndroidDevice();
    }

    if (ios == null) {
      ios = new IOSDevice();
    }

    if (argResults.rest.length > 0) {
      watchCommand = _initWatchCommand(argResults.rest);
    } else {
      watchCommand = _initWatchCommand(['.']);
    }

    Map<BuildPlatform, ApplicationPackage> packages =
        ApplicationPackageFactory.getAvailableApplicationPackages();
    ApplicationPackage androidApp = packages[BuildPlatform.android];
    ApplicationPackage iosApp = packages[BuildPlatform.iOS];

    while (true) {
      _logging.info('Updating running Flutter apps...');

      String compilerPath;
      if (ApplicationPackageFactory.srcPath != null) {
        compilerPath = path.joinAll([
          ApplicationPackageFactory.srcPath, 'out', 'ios_Debug', 'clang_x64', 'sky_snapshot'
        ]);
      }

      String localFLXPath = await new BuildCommand().build(compilerPath: compilerPath);
      String remoteFLXPath = 'Documents/app.flx';

      if (ios.isConnected()) {
        await ios.pushFile(iosApp, localFLXPath, remoteFLXPath);
      }

      if (android.isConnected()) {
        await android.startServer(
            argResults['target'], true, argResults['checked'], androidApp);
      }

      if (singleRun || !watchDirectory()) {
        break;
      }
    }

    return 0;
  }

  List<String> _initWatchCommand(List<String> directories) {
    if (Platform.isMacOS) {
      try {
        runCheckedSync(['which', 'fswatch']);
      } catch (e) {
        _logging.severe('"listen" command is only useful if you have installed '
            'fswatch on Mac.  Run "brew install fswatch" to install it with '
            'homebrew.');
        return null;
      }
      return ['fswatch', '-r', '-v', '-1']..addAll(directories);
    } else if (Platform.isLinux) {
      try {
        runCheckedSync(['which', 'inotifywait']);
      } catch (e) {
        _logging.severe('"listen" command is only useful if you have installed '
            'inotifywait on Linux.  Run "apt-get install inotify-tools" or '
            'equivalent to install it.');
        return null;
      }
      return [
        'inotifywait',
        '-r',
        '-e',
        // Only listen for events that matter, to avoid triggering constantly
        // from the editor watching files
        'modify,close_write,move,create,delete',
      ]..addAll(directories);
    } else {
      _logging.severe('"listen" command is only available on Mac and Linux.');
    }
    return null;
  }

  bool watchDirectory() {
    if (watchCommand == null) {
      return false;
    }

    try {
      runCheckedSync(watchCommand);
    } catch (e) {
      _logging.warning('Watching directories failed.', e);
      return false;
    }
    return true;
  }
}
