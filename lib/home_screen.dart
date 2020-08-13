import 'package:anagramf/anagramTextFormatter.dart';
import 'package:anagramf/anagram_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomeScreenState();
}

// this is the user interface
class HomeScreenState extends State<HomeScreen> {
  Widget _anagramsListView(BuildContext context, List<String> items){
    if(items== null){
      return null;
    }
    // sort items by length
    items.sort((a,b)=>a.length-b.length);
    return GridView.builder(itemCount: items.length,gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: (3.0)), itemBuilder: (context, index){
      return Text(items[index], textAlign: TextAlign.center);
    });
  }
  var loading = true;
  final _bloc = AnagramBloc();
  // button padding
  final _buttonPadding = 10.0;
  // edit text controller for the textbox
  var _anagramTextController = new TextEditingController();
  void _updateAnagramText(String text){
    setState(() {
      _anagramTextController.text = text;
    });
  }
  void _downloadDictionary(){
    _bloc.downloadDictionaryNew();
    _bloc.dictionaryStream.listen((event) {
      // stop the loading
      loading = false;
      // reload the widget when it is done
      setState(() {

      });
    });
  }
  void _getAnagrams(){
    _bloc.getAnagrams(_anagramTextController.text);
    _bloc.resultsStream.listen((anagrams) {
      setState(() {

      });
    });
  }
  void _generateButtonClick(){
    _anagramTextController.text = _bloc.randomCharacters();
  }
  @override
  void initState() {
   // do stuff here
    super.initState();
    _downloadDictionary();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.only(top: 56, left: 12, right: 12),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _anagramTextController,
              inputFormatters: [AnagramTextFormatter()],
              decoration: InputDecoration(
              border: OutlineInputBorder(), labelText: "Anagram")),
            Container(
                height: 50,
                margin: EdgeInsets.only(top: 16),
                child: (!loading? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                          height: 50,
                          child: Padding(
                              padding: EdgeInsets.only(
                                  right: _buttonPadding),
                              child: RaisedButton(
                                  onPressed:  _generateButtonClick,
                                  child: Text("Random")
                              )
                          )
                      ),
                    ),
                    Expanded(
                      child: Container(
                          height: 50,
                          child: Padding(
                              padding: EdgeInsets.only(
                                  left: _buttonPadding),
                              child: RaisedButton(
                                  onPressed: _getAnagrams,
                                  child: Text("Generate")
                              )
                          )
                      ),
                    ),

                  ],
                ) : Column(
                  children: <Widget>[
                      Container(
                        child: CircularProgressIndicator(
                      ),
                    ),
                    Expanded(
                      child: Container(
                        child: Text("Loading...", textAlign: TextAlign.center,),
                      ),
                    )
                  ],
                ))
            ),
            Visibility(
              visible: _bloc.currentResults != null,
              child: Padding(
                padding: EdgeInsets.all(10),
                 child: Column(
                  children: <Widget>[
                    Text("Time Elapsed: ${_bloc.elapsedTime}ms"),
                    Text("Anagrams Found: ${_bloc.currentResults != null? _bloc.currentResults.length: ""}")
                  ],
                )
              ),
              ),
              Expanded(
                child: Container(
                  child: _anagramsListView(context, _bloc.currentResults)
                  ),
              ),
          ],
        ),
      ),
    );
  }
}
