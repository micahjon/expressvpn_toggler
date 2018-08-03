import 'package:flutter/material.dart';
import 'dart:async'; // Future
import 'package:http/http.dart' as http; // http
import 'list-devices.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'ExpressVPN Toggler',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.green,
      ),
      home: new MyHomePage(), // title: 'ExpressVPN Router Login'
//      routes: <String, WidgetBuilder>{
//        '/list-devices': (BuildContext context) =>  new ListDevices(title: 'test'),
//      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key); // , this.title

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  // final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

//
// Login Screen
//

class _MyHomePageState extends State<MyHomePage> {
//  int _counter = 0;

  // Username & password
  String username = ''; // 'admin';
  String password = ''; // 'masterofthehouse';

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  String authCookie = '';
  bool isAuthenticating = false;

  String macAddress = '';

  void _authenticate() {

    username = usernameController.text; //.length > 0 ? usernameController.text : username;
    password = passwordController.text; //.length > 0 ? passwordController.text : password;
//
//    print('authenticate...');
//    print(username + ' ' + username.length.toString());
//    print(password + ' ' + password.length.toString());

    setState(() {
      isAuthenticating = true;

      getAuthCookie(username, password)
        .then((cookie) {

          // Authentication was successful. Save credentials.
          saveCredentials(username, password);

          // Get MAC address as well
          getMacAddress().then((result) {

            setState(() {
              macAddress = result;

              authCookie = cookie;
              isAuthenticating = false;
            });

            _listDevices();

          });
        })
        .catchError((error) {
          setState(() {
            authCookie = '';
            isAuthenticating = false;
          });
          print(error);
        });
    });
  }

  void _listDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListDevices(authCookie: authCookie, macAddress: macAddress),
      ),
    );
  }

  @override
  void initState() {

    getCredentials().then((map) {
//
//      print('got credentials');
//      print(map);

      usernameController.text = map['username'];
      passwordController.text = map['password'];
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text('ExpressVPN Router Login'),
      ),
      body: new Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: new Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug paint" (press "p" in the console where you ran
          // "flutter run", or select "Toggle Debug Paint" from the Flutter tool
          // window in IntelliJ) to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: new ListTile(
                leading: const Icon(Icons.person),
                title: new TextField(
                  controller: usernameController,
                  decoration: new InputDecoration(
                    hintText: "Username",
                  ),
                ),
              ),
            ),
            new Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: new ListTile(
                leading: const Icon(Icons.lock),
                title: new TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: new InputDecoration(
                    hintText: "Password",
                  ),
                ),
              ),
            ),
            new Padding(
              padding: const EdgeInsets.all(20.0),
              child: isAuthenticating
                  ? CircularProgressIndicator()
                : new RaisedButton(
                    onPressed: _authenticate,
                    child:  new Text('Authenticate'),
                    color: Colors.green,
                    textColor: Colors.white,
                    splashColor: Colors.green[700]
                  )
            ),
//            FutureBuilder<String>(
//              future: getAuthCookie(username, password), // fetchPost(),
//              builder: (context, snapshot) {
//                if (snapshot.hasData) {
//                  return Text(snapshot.data);
//                } else if (snapshot.hasError) {
//                  return Text("${snapshot.error}");
//                }
//
//                // By default, show a loading spinner
//                return CircularProgressIndicator();
//              },
//            ),
          ],
        ),
      ),
    );
  }
}

Future<String> getAuthCookie(String username, String password) async {

  final response =
  await http
      .post('https://expressvpnrouter.com/login', body: { 'username': username, 'password': password })
      .timeout(const Duration(seconds: 3));

  if (response.statusCode == 200 || response.statusCode == 302) {

    RegExp findAuthToken = new RegExp(r'auth="([a-zA-Z0-9]+)"');
    String token = '';
    try {
      token = findAuthToken.firstMatch(response.headers['set-cookie']).group(1);
    }
    catch(error) {
      throw Exception('Authentication failed');
    }

    return token;

  }

  throw Exception('Got unexpected statuscode from expressvpnrouter.com');

}

Future<String> getMacAddress() async {

  // Get MAC address
  const platform = const MethodChannel('expressvpn-toggler/mac-address');

  String result = '';
  try {
    result = await platform.invokeMethod('getMacAddress');
    print('Got MAC address: $result.');
  } on PlatformException catch (e) {
    print('Unable to get MAC address: ${e.message}.');
  }

  return result;

}

Future<Map> getCredentials() async {

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String username = prefs.getString('username') ?? '';
  String password = prefs.getString('password') ?? '';
//
//  print('username = ' + username);
//  print('password = ' + password);

  return {
    "username": username,
    "password": password,
  };

}

Future saveCredentials(username, password) async {

  SharedPreferences prefs = await SharedPreferences.getInstance();

  await prefs.setString('username', username);
  await prefs.setString('password', password);

  print('saved credentials');

}