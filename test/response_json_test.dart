import 'package:coral_music_mobile/core/response_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes JSONP responses returned by music catalog endpoints', () {
    expect(decodeJsonMap('callback({"code":0,"value":"ok"});'), {
      'code': 0,
      'value': 'ok',
    });
  });

  test('decodes Kuwo single-quoted result objects', () {
    expect(decodeJsonMap("{'TOTAL':'1','abslist':[{'name':'Jay\\'s'}]}"), {
      'TOTAL': '1',
      'abslist': [
        {'name': "Jay's"},
      ],
    });
  });
}
