import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:dbus/dbus.dart';

void main(List<String> arguments) {
  // Print protocol header
  print('{"version":1, "click_events":true}');
  //Print opening bracket for infinite array
  print('[');

  //List of all status blocks.
  List<Block> blocks = [
    MediaBlock(),
    TimeBlock(),
  ];

  //Listen to stdin
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((event) {
    if (event[0] != '[') {
      if (event[0] == ',') event = event.substring(1);
      final json = jsonDecode(event);
      for (var block in blocks) {
        if (block.name == json['name']) {
          block.handleClick(json['button']);
        }
      }
    }
  });

  //Setup periodic timer for updating status bar
  const Duration updateInterval = Duration(seconds: 1);
  Timer.periodic(updateInterval, (timer) {
    for (var block in blocks) {
      block.generateFullText();
    }
    print(jsonEncode(blocks) + ',');
  });
}

// Class representing a status block. Extend this to implement a custom
// status block
abstract class Block {
  String fullText = '';
  String? border;
  String? markup;
  String name = '';

  void generateFullText();

  void handleClick(int button) {}

  Map<String, dynamic> toJson() => {
        'full_text': fullText,
        'border': border,
        'markup': markup,
        'name': name,
      }..removeWhere((key, value) => value == null);
}

//Block for displaying a text

class TextBlock extends Block {
  TextBlock(String text) {
    fullText = text;
    border = '#ff991c';
    name = 'TextBlock';
  }

  @override
  void generateFullText() {}
}

//Block for getting current datetime
class TimeBlock extends Block {
  TimeBlock() {
    name = 'TimeBlock';
  }

  @override
  void generateFullText() {
    fullText = DateTime.now().toString().split('.').first;
  }
}

//Block for getting information about the current song in spotify
class MediaBlock extends Block {
  late DBusClient dbusClient;
  late DBusRemoteObject dbusObject;

  MediaBlock() {
    dbusClient = DBusClient.session();
    dbusObject = DBusRemoteObject(
      dbusClient,
      name: 'org.mpris.MediaPlayer2.spotify',
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
    );
    markup = 'pango';
    name = 'MediaBlock';
  }

  void dispose() {
    dbusClient.close();
  }

  @override
  void generateFullText() async {
    try {
      var metadata = (await dbusObject.getProperty(
              'org.mpris.MediaPlayer2.Player', 'Metadata'))
          .toNative();
      fullText =
          '${metadata['xesam:title']} - <i>${metadata['xesam:artist']}</i>';
    } on DBusServiceUnknownException {
      fullText = '';
    }
  }

  @override
  void handleClick(int button) {
    try {
      switch (button) {
        case 1:
          dbusObject
              .callMethod('org.mpris.MediaPlayer2.Player', 'PlayPause', []);
          break;
        case 2:
          dbusObject
              .callMethod('org.mpris.MediaPlayer2.Player', 'Previous', []);
          break;
        case 3:
          dbusObject.callMethod('org.mpris.MediaPlayer2.Player', 'Next', []);
          break;
      }
    } on DBusServiceUnknownException {
      return;
    }
  }
}
