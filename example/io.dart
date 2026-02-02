/// Example: I/O and Streams
///
/// Demonstrates the I/O system:
/// - Character I/O (get_char, put_char, get_code, put_code)
/// - Term I/O (read, write, writeln)
/// - File I/O (open, close)
/// - Stream management (current_input, current_output, set_input, set_output)

library;

import 'dart:io' as io;
import 'package:libprolog/libprolog.dart';

void main() async {
  print('=== I/O and Streams Demo ===\n');

  final db = Database();
  final streamManager = StreamManager();
  final resolver = Resolver(db, streamManager: streamManager);

  // 1. Character Output
  print('1. Character Output (put_char/1):');
  print('   Writing characters H, e, l, l, o...');

  Term goal = Compound(Atom('put_char'), [Atom('H')]);
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_char'), [Atom('e')]);
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_char'), [Atom('l')]);
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_char'), [Atom('l')]);
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_char'), [Atom('o')]);
  await resolver.queryGoal(goal).toList();

  goal = Atom('nl');
  await resolver.queryGoal(goal).toList();

  print('');

  // 2. Character Code I/O
  print('2. Character Code I/O (put_code/1):');
  print('   Writing character codes 87(W), 111(o), 114(r), 108(l), 100(d)...');

  goal = Compound(Atom('put_code'), [PrologInteger(87)]); // W
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_code'), [PrologInteger(111)]); // o
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_code'), [PrologInteger(114)]); // r
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_code'), [PrologInteger(108)]); // l
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('put_code'), [PrologInteger(100)]); // d
  await resolver.queryGoal(goal).toList();

  goal = Atom('nl');
  await resolver.queryGoal(goal).toList();

  print('');

  // 3. Term Output
  print('3. Term Output (write/1, writeln/1):');
  print('   Writing term: parent(tom, bob)');

  final term = Compound(Atom('parent'), [Atom('tom'), Atom('bob')]);
  goal = Compound(Atom('write'), [term]);
  await resolver.queryGoal(goal).toList();

  goal = Atom('nl');
  await resolver.queryGoal(goal).toList();

  print('   Writing with writeln: [1, 2, 3]');
  final list = Compound.fromList([
    PrologInteger(1),
    PrologInteger(2),
    PrologInteger(3),
  ]);
  goal = Compound(Atom('writeln'), [list]);
  await resolver.queryGoal(goal).toList();

  print('');

  // 4. Current Stream Information
  print('4. Current Stream Information:');

  final currentIn = Variable('In');
  goal = Compound(Atom('current_input'), [currentIn]);
  var solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   Current input: ${solutions[0].binding('In')}');
  }

  final currentOut = Variable('Out');
  goal = Compound(Atom('current_output'), [currentOut]);
  solutions = await resolver.queryGoal(goal).toList();
  if (solutions.isNotEmpty) {
    print('   Current output: ${solutions[0].binding('Out')}\n');
  }

  // 5. File I/O
  print('5. File I/O (open/3, write, close/1):');

  // Create a test file
  final testFile = io.File('/tmp/prolog_test.txt');
  print('   Opening file: /tmp/prolog_test.txt');

  final stream = Variable('Stream');
  goal = Compound(Atom('open'), [
    Atom('/tmp/prolog_test.txt'),
    Atom('write'),
    stream,
  ]);
  solutions = await resolver.queryGoal(goal).toList();

  if (solutions.isNotEmpty) {
    final streamAlias = solutions[0].binding('Stream')!;
    print('   Stream opened: $streamAlias');

    // Set it as current output
    goal = Compound(Atom('set_output'), [streamAlias]);
    await resolver.queryGoal(goal).toList();
    print('   Set as current output');

    // Write to the file
    goal = Compound(Atom('writeln'), [Atom('% Prolog facts')]);
    await resolver.queryGoal(goal).toList();

    goal = Compound(Atom('writeln'), [
      Compound(Atom('likes'), [Atom('alice'), Atom('prolog')]),
    ]);
    await resolver.queryGoal(goal).toList();

    goal = Compound(Atom('writeln'), [
      Compound(Atom('likes'), [Atom('bob'), Atom('dart')]),
    ]);
    await resolver.queryGoal(goal).toList();

    print('   Written facts to file');

    // Restore stdout
    goal = Compound(Atom('set_output'), [Atom('user_output')]);
    await resolver.queryGoal(goal).toList();

    // Close the file
    goal = Compound(Atom('close'), [streamAlias]);
    await resolver.queryGoal(goal).toList();
    print('   File closed');

    // Read and display the file content
    if (await testFile.exists()) {
      print('\n   File contents:');
      final content = await testFile.readAsString();
      print('   $content');
    }

    // Clean up
    await testFile.delete();
  }

  // 6. Stream Switching
  print('\n6. Stream Switching:');
  print('   Demonstrating output to different streams...');

  // Write to stdout
  goal = Compound(Atom('write'), [Atom('   [stdout] Hello from user_output')]);
  await resolver.queryGoal(goal).toList();

  goal = Atom('nl');
  await resolver.queryGoal(goal).toList();

  // Switch to stderr and write
  goal = Compound(Atom('set_output'), [Atom('user_error')]);
  await resolver.queryGoal(goal).toList();

  goal = Compound(Atom('write'), [Atom('   [stderr] Warning from user_error')]);
  await resolver.queryGoal(goal).toList();

  goal = Atom('nl');
  await resolver.queryGoal(goal).toList();

  // Switch back to stdout
  goal = Compound(Atom('set_output'), [Atom('user_output')]);
  await resolver.queryGoal(goal).toList();

  print('   [stdout] Back to user_output');

  print('\n=== Demo Complete ===');
  print('I/O system is fully functional!');

  // Clean up
  streamManager.closeAll();
}
