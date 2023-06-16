import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('勤怠'),
        ),
        body: const _Body(),
      ),
    );
  }
}

const kintaiTime = 'kintaiTime';
const kintaiState = 'kintaiState';
const clockIn = '出勤';
const clockOut = '退勤';

class _Body extends HookWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final formatTimeState = useState('--:--:--');
    final buttonState = useState('--');
    final kintaiList = useState(<String>[]);
    final scrollCtrl = useScrollController();

    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final now = DateTime.now();
        final nf = NumberFormat('00');

        formatTimeState.value =
            '${nf.format(now.hour)}:${nf.format(now.minute)}:${nf.format(now.second)}';
      });

      return timer.cancel;
    }, const []);

    updateButtonState() => Future.microtask(() async {
          final pref = await SharedPreferences.getInstance();
          final kintai = pref.getStringList(kintaiState);
          buttonState.value =
              ((kintai?.last ?? clockOut) == clockOut) ? clockIn : clockOut;
        });

    updateKintaiList() => Future.microtask(() async {
          final pref = await SharedPreferences.getInstance();
          final currentKintaiTime = pref.getStringList(kintaiTime);
          final currentKintaiState = pref.getStringList(kintaiState);

          if (currentKintaiState == null || currentKintaiTime == null) return;

          final list = <String>[];
          for (var i = 0; i < currentKintaiTime.length; i++) {
            list.add('${currentKintaiTime[i]}: ${currentKintaiState[i]}');
          }
          kintaiList.value = list;
        });

    saveClock() => Future.microtask(() async {
          final pref = await SharedPreferences.getInstance();
          final prevKintaiTime = pref.getStringList(kintaiTime);
          final prevKintai = pref.getStringList(kintaiState);

          if (prevKintaiTime == null || prevKintai == null) {
            pref.setStringList(kintaiTime, [formatTimeState.value]);
            pref.setStringList(kintaiState, [clockIn]);
          } else {
            pref.setStringList(
                kintaiTime, [...prevKintaiTime, formatTimeState.value]);

            if (prevKintai.last == clockIn) {
              pref.setStringList(kintaiState, [...prevKintai, clockOut]);
            } else {
              pref.setStringList(kintaiState, [...prevKintai, clockIn]);
            }
          }

          updateButtonState();
          updateKintaiList();
          scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
        });

    useEffect(() {
      updateButtonState();
      updateKintaiList();

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          // kintaiList.value.add(tag.data.toString());
          saveClock();
        },
      );
      return;
    }, []);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Text(
              formatTimeState.value,
              style: const TextStyle(fontSize: 100),
            ),
            TextButton(
              onPressed: () async {
                await saveClock();
              },
              child: Text(
                buttonState.value,
                style: TextStyle(
                  fontSize: 100,
                  color:
                      (buttonState.value == clockIn) ? Colors.blue : Colors.red,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                shrinkWrap: true,
                controller: scrollCtrl,
                itemCount: kintaiList.value.length,
                itemBuilder: (BuildContext context, int index) {
                  return Text(
                    kintaiList.value[index],
                    style: const TextStyle(color: Colors.green),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
