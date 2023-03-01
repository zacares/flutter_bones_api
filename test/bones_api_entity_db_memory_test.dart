@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

class MemoryTestConfig extends APITestConfigDBSQLMemory {
  MemoryTestConfig()
      : super({
          'db': {
            'sql.memory': {
              'port': 0,
            }
          }
        });
}

Future<void> main() async {
  await _runTest(true);
  await _runTest(false);
  await _runTest(true);
  await _runTest(false);
}

Future<bool> _runTest(bool useReflection) {
  return runAdapterTests(
    'DBSQLMemory',
    MemoryTestConfig(),
    (provider, dbPort) => DBSQLMemoryAdapter(
      parentRepositoryProvider: provider,
    ),
    (provider, dbPort) =>
        DBObjectMemoryAdapter(parentRepositoryProvider: provider),
    '"',
    'int',
    entityByReflection: useReflection,
  );
}
