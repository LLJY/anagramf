import 'dart:async';
import 'dart:convert';
import 'package:quiver/iterables.dart';
import 'dart:isolate';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import 'package:anagramf/bloc.dart';

class AnagramBloc implements Bloc {
  BehaviorSubject<List<WordData>> _dictionaryStreamController =
      BehaviorSubject();
  BehaviorSubject<List<String>> _resultsStreamController = BehaviorSubject();

  Stream<List<WordData>> get dictionaryStream =>
      _dictionaryStreamController.stream;

  Stream<List<String>> get resultsStream => _resultsStreamController.stream;

  List<WordData> get currentDictionary => _dictionaryStreamController.value;

  List<String> get currentResults => _resultsStreamController.value;
  var elapsedTime = 0;

  // create random here to keep the "Randomness" across function calls
  final _random = Random();

  @override
  void dispose() {
    // close the stream controller on dispose to prevent memory leaks
    _dictionaryStreamController.close();
    _resultsStreamController.close();
  }

  String randomCharacters() {
    // characters
    final characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var returnString = "";
    for (var i = 0; i <= 10; i++) {
      final randomChar = characters[_random.nextInt(25)];
      returnString = "$returnString$randomChar";
    }
    return returnString;
  }

  static void _runInIsolate(IsolateMessageDownload message) {
    final returnList = List<WordData>();
    for (var i = 0; i < message.chunk.length; i++) {
      returnList.add(WordData.fromString(message.chunk[i]));
    }
    // send message to the main thread
    message.sendPort.send(returnList);
  }

  /// this function is not used, but it shows my attempt at using isolates for processing heavy compute tasks
  void downloadDictionary() async {
    final response = await http.get(
        "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt");
    var dictionaryList = new List<WordData>();
    // split string into list of strings by newline
    final ls = LineSplitter();
    var words = ls.convert(response.body);
    // split list into chunks to process in different isolates
    var size = (words.length / 8).ceil();
    var splitWords = partition(words, size).toList();
    // this is a list of futures to wait for
    final isolates = List<Future>();
    for (var i = 0; i < splitWords.length; i++) {
      final chunkWords = splitWords[i];
      final isolateReceive = ReceivePort();
      isolates.add(Isolate.spawn(_runInIsolate,
              IsolateMessageDownload(chunkWords, isolateReceive.sendPort))
          .then((value) => isolateReceive.close()));
      isolateReceive.listen((message) {
        dictionaryList.addAll(message);
      });
    }
    await Future.wait(isolates);
    for (var i = 0; i < dictionaryList.length; i++) {
    }
    _dictionaryStreamController.add(dictionaryList);
  }

  /// converts a list of strings into a list of WordData objects
  Future<List<WordData>> convertList(List<String> chunkWords) async {
    final returnList = List<WordData>();
    chunkWords.forEach((word) {
      returnList.add(WordData.fromString(word));
    });
    return returnList;
  }

  void downloadDictionaryNew() async {
    final response = await http.get(
        "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt");
    var dictionaryList = new List<WordData>();
    // split string into list of strings by newline
    final ls = LineSplitter();
    var words = ls.convert(response.body);
    // split list into chunks to process in different isolates
    var size = (words.length / 8).ceil();
    var splitWords = partition(words, size).toList();
    // this is a list of futures to wait for
    final futures = List<Future<List<WordData>>>();
    splitWords.forEach((chunkWords) {
      futures.add(convertList(chunkWords));
    });
    var doneList = (await Future.wait(futures)).toList();
    doneList.forEach((element) {
      dictionaryList.addAll(element);
    });
    _dictionaryStreamController.add(dictionaryList);
  }

  /// function to get the anagrams from the list.
  void getAnagrams(String word) async {
    final stopwatch = new Stopwatch()..start();
    final finishedList = new List<String>();
    final compareWord = WordData.fromString(word);
    // get the current stream controller value and add a shorthand variable for it
    final dictionary = _dictionaryStreamController.value;
    final size = (dictionary.length / 8).ceil();
    // split the list into list of lists so we can process each one individually
    final splitList = partition(dictionary, size);
    final futures = List<Future<List<String>>>();
    splitList.forEach((wordsChunk) {
      futures.add(getAnagramsSubList(wordsChunk, compareWord));
    });
    // wait for all the futures to complete
    final completedFutures = await Future.wait(futures);
    // add all results to the list
    completedFutures.forEach((element) {
      finishedList.addAll(element);
    });
    // update the stream controller with the results
    _resultsStreamController.add(finishedList);
    elapsedTime=stopwatch.elapsedMilliseconds;
    stopwatch.stop();
  }

  Future<List<String>> getAnagramsSubList(
      List<WordData> wordsChunk, WordData compareWord) async {
    final returnList = List<String>();
    wordsChunk.forEach((word) {
      // check to use bigint or not
      if (compareWord.wordValue == 0) {
        if (word.wordValue == 0) {
          // if it is perfectly divisible, it contains an anagram of the word
          if (compareWord.wordValueBig % word.wordValueBig == BigInt.from(0)) {
            returnList.add(word.word);
          }
        } else {
          // if it is perfectly divisible, it contains an anagram of the word
          if (compareWord.wordValueBig % BigInt.from(word.wordValue) ==
              BigInt.from(0)) {
            returnList.add(word.word);
          }
        }
      } else {
        if (word.wordValue == 0) {
          // if it is perfectly divisible, it contains an anagram of the word
          if (BigInt.from(compareWord.wordValue) % word.wordValueBig ==
              BigInt.from(0)) {
            returnList.add(word.word);
          }
        } else {
          // if it is perfectly divisible, it contains an anagram of the word
          if (compareWord.wordValue % word.wordValue == 0) {
            returnList.add(word.word);
          }
        }
      }
    });
    return returnList;
  }
}

// isolate data to be passed to the download function
class IsolateMessageDownload {
  // a small chunk of the list to be processed.
  List<String> chunk;

  // a sendport for ipc between main Isolate and child Isolate
  SendPort sendPort;

  IsolateMessageDownload(this.chunk, this.sendPort);
}

class WordData {
  String word;
  int wordValue;
  BigInt wordValueBig;

  WordData(this.word, this.wordValue, this.wordValueBig);

  WordData.fromString(String word) {
    this.word = word;
    word = word.toUpperCase();
    var wordValuePrev = 0;
    var wordValue = 1;
    var overflow = false;
    var wordValueBig = BigInt.from(1);
    for (var i = 0; i < word.length; i++) {
      final character = word[i];
      // each character has a prime assigned, so we can use prime factorization to find primes.
      switch (character) {
        case 'A':
          wordValue *= 2;
          break;
        case 'B':
          wordValue *= 3;
          break;
        case 'C':
          wordValue *= 5;
          break;
        case 'D':
          wordValue *= 7;
          break;
        case 'E':
          wordValue *= 11;
          break;
        case 'F':
          wordValue *= 13;
          break;
        case 'G':
          wordValue *= 17;
          break;
        case 'H':
          wordValue *= 19;
          break;
        case 'I':
          wordValue *= 23;
          break;
        case 'J':
          wordValue *= 29;
          break;
        case 'K':
          wordValue *= 31;
          break;
        case 'L':
          wordValue *= 37;
          break;
        case 'M':
          wordValue *= 41;
          break;
        case 'N':
          wordValue *= 43;
          break;
        case 'O':
          wordValue *= 47;
          break;
        case 'P':
          wordValue *= 53;
          break;
        case 'Q':
          wordValue *= 59;
          break;
        case 'R':
          wordValue *= 61;
          break;
        case 'S':
          wordValue *= 67;
          break;
        case 'T':
          wordValue *= 71;
          break;
        case 'U':
          wordValue *= 73;
          break;
        case 'V':
          wordValue *= 79;
          break;
        case 'W':
          wordValue *= 83;
          break;
        case 'X':
          wordValue *= 89;
          break;
        case 'Y':
          wordValue *= 97;
          break;
        case 'Z':
          wordValue *= 101;
          break;
      }
      // if the value has overflowed, break and
      if (wordValue > wordValuePrev) {
        wordValuePrev = wordValue;
      } else {
        overflow = true;
        wordValue = 0;
        break;
      }
    }
    if (overflow) {
      for (var i = 0; i < word.length; i++) {
        final character = word[i];
        // each character has a prime assigned, so we can use prime factorization to find primes.
        switch (character) {
          case 'A':
            wordValueBig *= BigInt.from(2);
            break;
          case 'B':
            wordValueBig *= BigInt.from(3);
            break;
          case 'C':
            wordValueBig *= BigInt.from(5);
            break;
          case 'D':
            wordValueBig *= BigInt.from(7);
            break;
          case 'E':
            wordValueBig *= BigInt.from(11);
            break;
          case 'F':
            wordValueBig *= BigInt.from(13);
            break;
          case 'G':
            wordValueBig *= BigInt.from(17);
            break;
          case 'H':
            wordValueBig *= BigInt.from(19);
            break;
          case 'I':
            wordValueBig *= BigInt.from(23);
            break;
          case 'J':
            wordValueBig *= BigInt.from(29);
            break;
          case 'K':
            wordValueBig *= BigInt.from(31);
            break;
          case 'L':
            wordValueBig *= BigInt.from(37);
            break;
          case 'M':
            wordValueBig *= BigInt.from(41);
            break;
          case 'N':
            wordValueBig *= BigInt.from(43);
            break;
          case 'O':
            wordValueBig *= BigInt.from(47);
            break;
          case 'P':
            wordValueBig *= BigInt.from(53);
            break;
          case 'Q':
            wordValueBig *= BigInt.from(59);
            break;
          case 'R':
            wordValueBig *= BigInt.from(61);
            break;
          case 'S':
            wordValueBig *= BigInt.from(67);
            break;
          case 'T':
            wordValueBig *= BigInt.from(71);
            break;
          case 'U':
            wordValueBig *= BigInt.from(73);
            break;
          case 'V':
            wordValueBig *= BigInt.from(79);
            break;
          case 'W':
            wordValueBig *= BigInt.from(83);
            break;
          case 'X':
            wordValueBig *= BigInt.from(89);
            break;
          case 'Y':
            wordValueBig *= BigInt.from(97);
            break;
          case 'Z':
            wordValueBig *= BigInt.from(101);
            break;
        }
      }
    }
    this.wordValue = wordValue;
    this.wordValueBig = wordValueBig;
  }
}
