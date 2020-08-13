import 'package:flutter/services.dart';

class AnagramTextFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // store the text to be modified; convert everything to uppercase
    final _text = newValue.text?.toUpperCase();
    var finalString = "";
    // make sure all things are capital letters and only contain alphanumeric characters
    final _acceptedCharacters= "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    for(var i=0; i<_text.length; i++) {
      // get the individual character from the string and check that it is inside the accepted characters
      var char = _text[i];
      if(_acceptedCharacters.contains(char)){
        // concat the list of characters and the character
        finalString = "$finalString$char";
      }
    }
    return TextEditingValue(
      text: finalString,
      selection: newValue.selection
    );
  }

}