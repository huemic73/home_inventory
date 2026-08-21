import 'package:pocketbase/pocketbase.dart';

void main() {
  final record = RecordModel()..id = 'hello';
  print('Record ID directly: ${record.id}');

  // Let's see if we can instantiate it from JSON or load it
  final record2 = RecordModel( {
    'id': 'hello2',
    'name': 'test',
  });
  print('Record2 ID directly: ${record2.id}');
}
