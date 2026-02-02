import 'package:test/test.dart';
import 'package:libprolog/libprolog.dart';

void main() {
  group('DCG Parsing Tests', () {
    late PrologEngine engine;

    setUp(() {
      engine = PrologEngine();
    });

    test('DCG with parenthesized disjunction', () async {
      // From clce.dcg: chapter --> clce_prefix, left_brace, (paragraph | chapter), ...
      engine.assertTerm('test1 --> a, (b | c), d.');

      // Should translate to: test1(S0, S3) :- a(S0, S1), (b(S1, S2); c(S1, S2)), d(S2, S3).

      final indicators = engine.predicateIndicators();
      print(
        'Predicates after asserting: ${indicators.where((i) => i.contains('test1'))}',
      );

      // Check if the rule was loaded
      expect(indicators.contains('test1/2'), isTrue);
    });

    test('DCG with simple disjunction', () async {
      // From clce.dcg: sentence --> declarative_sentence | interrogative_sentence.
      engine.assertTerm('test2 --> a | b.');

      final indicators = engine.predicateIndicators();
      print('Predicates: ${indicators.where((i) => i.contains('test2'))}');

      expect(indicators.contains('test2/2'), isTrue);
    });

    test('DCG with curly brace goals', () async {
      // From clce.dcg: zero_or_more_chapters --> {true}.
      engine.assertTerm('test3 --> {true}.');

      final indicators = engine.predicateIndicators();
      print('Predicates: ${indicators.where((i) => i.contains('test3'))}');

      expect(indicators.contains('test3/2'), isTrue);

      // Test that it works
      final result = await engine.queryOnce('test3(X, X)');
      expect(
        result.success,
        isTrue,
        reason: '{true} should unify input=output',
      );
    });

    test('DCG with multiple alternatives using disjunction', () async {
      // From clce.dcg: declarative_sentence --> simple_declarative_sentence |
      //                                          complex_declarative_sentence |
      //                                          compound_declarative_sentence.
      engine.assertTerm('test4 --> a | b | c.');

      final indicators = engine.predicateIndicators();
      expect(indicators.contains('test4/2'), isTrue);
    });

    test('DCG with complex nested structure', () async {
      // From clce.dcg line 9-10:
      // chapter --> clce_prefix, left_brace, (paragraph | chapter),
      //             (zero_or_more_paragraphs, zero_or_more_chapters), right_brace.
      engine.assertTerm('test5 --> a, b, (c | d), (e, f), g.');

      final indicators = engine.predicateIndicators();
      expect(indicators.contains('test5/2'), isTrue);
    });

    test('DCG with optional elements using disjunction with true', () async {
      // From clce.dcg: simple_verb_phrase --> has, simple_noun_phrase, ((as, noun)| {true}).
      engine.assertTerm('test6 --> a, b, ((c, d) | {true}).');

      final indicators = engine.predicateIndicators();
      expect(indicators.contains('test6/2'), isTrue);
    });

    test('DCG terminal list parsing', () async {
      // Test that terminal lists [W] work correctly
      engine.assertTerm('word --> [W], {atom(W)}.');

      final indicators = engine.predicateIndicators();
      expect(indicators.contains('word/2'), isTrue);

      // Test with actual data
      final result = await engine.queryOnce('word([hello], [])');
      expect(result.success, isTrue);
    });

    test('DCG with variable in goal', () async {
      // DCG rules can have variables that are passed through
      engine.assertTerm('wrap(W) --> [W1], {W1 = wrap(W)}.');

      final indicators = engine.predicateIndicators();
      expect(
        indicators.contains('wrap/3'),
        isTrue,
        reason: 'Should add 2 args for difference list plus 1 for W',
      );
    });
  });
}
