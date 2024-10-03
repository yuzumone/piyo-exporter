import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:http/http.dart' as http;

const url = String.fromEnvironment('URL');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'piyopiyo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'piyopiyo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late StreamSubscription _intentSub;

  bool checkItem(String log) {
    final reg1 = RegExp(r'起きる|寝る|母乳|ミルク|搾母乳|身長|体重|お風呂|うんち|おしっこ|体温|離乳食');
    final reg2 = RegExp(r'([01][0-9]|2[0-3]):[0-5][0-9]');

    if (reg1.hasMatch(log) && reg2.hasMatch(log)) {
      return true;
    }
    return false;
  }

  int? convertToMinutes(String timeDifference) {
    RegExp regex = RegExp(r'\((\d+)時間(\d+)分\)');
    Match? match = regex.firstMatch(timeDifference);

    if (match != null) {
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      return hours * 60 + minutes;
    } else {
      return null;
    }
  }

  String parsePiyo(String log) {
    var result = [];
    var list = log.split('\n');
    var tmp = [...list];

    var day = '';
    list.asMap().forEach((var index, var value) {
      if (value == '----------' && index < tmp.length - 1) {
        var d = tmp[index + 1];
        if (d.isNotEmpty) {
          day = d.substring(0, d.length - 3);
        }
      }

      if (value.isNotEmpty && checkItem(value)) {
        final record = value.split(' ').where((e) => e.isNotEmpty).toList();
        if (['母乳', '寝る', 'お風呂', 'うんち', 'おしっこ', '離乳食'].contains(record[1])) {
          result.add(
              {'name': record[1], 'date': '$day ${record[0]}', 'value': ''});
        } else if (['起きる'].contains(record[1])) {
          var diff = convertToMinutes(record[2]);
          result.add({
            'name': record[1],
            'date': '$day ${record[0]}',
            'value': diff ?? ''
          });
        } else if (['ミルク', '搾母乳', '身長', '体重', '体温'].contains(record[1])) {
          result.add({
            'name': record[1],
            'date': '$day ${record[0]}',
            'value': record[2]
                .replaceAll("ml", "")
                .replaceAll("g", "")
                .replaceAll("cm", "")
                .replaceAll("°C", "")
          });
        }
      }
    });

    return json.encode(result);
  }

  Future<int> post(String json) async {
    final response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: json,
    );

    return response.statusCode;
  }

  @override
  void initState() {
    super.initState();
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      final string = value.map((e) => e.path).join();
      if (string.contains('【ぴよログ】')) {
        final json = parsePiyo(string);
        Future(() async {
          await post(json);
          SystemNavigator.pop();
        });
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      final string = value.map((e) => e.path).join();
      if (string.contains('【ぴよログ】')) {
        final json = parsePiyo(string);
        Future(() async {
          await post(json);
          SystemNavigator.pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
    );
  }
}
