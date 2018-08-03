import 'package:flutter/material.dart';
import 'dart:async'; // Future
import 'dart:convert'; // json
import 'package:http/http.dart' as http; // http
import 'main.dart';
//import 'package:device_info/device_info.dart';


class ListDevices extends StatefulWidget {
  ListDevices({Key key, this.authCookie, this.macAddress}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the authCookie) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String authCookie;
  final String macAddress;

  @override
  _ListDevicesState createState() => new _ListDevicesState();
}


class _ListDevicesState extends State<ListDevices> {

  var deviceList;

  final textEditingController = TextEditingController();

  // Increment to force a UI update
//  var _uiUpdater = 0;
//  void updateUI() {
//    setState(() { _uiUpdater++; });
//  }

  void handleAction(device, action) {

    if ( action.containsKey('mode') ) {
      return updateVPNMode(device, action['mode']);
    }

    if ( action.containsKey('edit_name') ) {
      return editName(device, action['edit_name']);
    }

  }

  void updateVPNMode(device, newMode) {

    device['gw'] = newMode;

    // Immediately show user's choice
    setState(() {
      deviceList = deviceList;
    });

    // Display latest updates from API
    updateDevice(device, widget.authCookie, widget.macAddress)
      .then((devices) {
        setState(() {
          deviceList = devices;
        });
      })
      .catchError((error) {
        print('Unable to update VPN mode:');
        print(error);
        _loginAgain();
      });

  }

  void editName(device, isEditing) {

    print('--------------');
    print(device);
    print(isEditing);

    device['__is_editing_name'] = isEditing;

    if ( isEditing ) {
      // Disable editing on every device except this one
      deviceList.forEach((thisDevice) {
        if ( thisDevice != device ) thisDevice.remove('__is_editing_name');
      });
      // Set text to device's name
      textEditingController.text = device['name'];
    }

    // Update name
    var nameWasUpdated = ! isEditing
        && textEditingController.text.length > 0
        && textEditingController.text != device['name'];
    if ( nameWasUpdated ) {
      device['name'] = textEditingController.text;
    }

    // Immediately show user's edits
    setState(() {
      deviceList = deviceList;
    });

    // Save edited name to API and display latest data
    if ( nameWasUpdated ) {
      updateDevice(device, widget.authCookie, widget.macAddress)
          .then((devices) {
            setState(() {
              deviceList = devices;
            });
          })
          .catchError((error) {
            print('Unable to update name:');
            print(error);
            _loginAgain();
          });
    }

  }

  void _loginAgain() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the ListDevices object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text('Connected Devices'),
      ),
      body: new Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: new Align(
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
          alignment: Alignment.topCenter,
          child: new FutureBuilder<List>(
              future: deviceList != null
                  ? Future(() => deviceList)
                  : getDevicesList(widget.authCookie, widget.macAddress),
              builder: (context, snapshot) {

                if ( snapshot.hasError ) {
                  return Text("Unable to fetch device list: ${snapshot.error}");
                }

                if ( ! snapshot.hasData ) {
                  return CircularProgressIndicator();
                }

                if ( deviceList == null ) {
//                  print('deviceList set from API data');
                  deviceList = snapshot.data;
                }

                return new ListView.builder(
                    itemBuilder: (context, index) {
                      return deviceCard(
                          deviceList[index],
                          Theme.of(context),
                          textEditingController,
                          (action) { handleAction(deviceList[index], action); },
                      );
                    },
                    itemCount: deviceList.length
                );

              },
            ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the Widget is removed from the Widget tree
    textEditingController.dispose();
    super.dispose();
  }
}

//--

Future<List> getDevicesList(String authCookie, String currentMacAddress) async {

  print('fetching devices from API..');

  const url = 'https://expressvpnrouter.com/rpc',
    body = '{"jsonrpc":"2.0","id":1,"method":"load_advanced_routing"}';

  final response =
  await http
      .post(
        url,
        headers: {
          'Cookie': 'auth="$authCookie"',
          'Referer': 'https://expressvpnrouter.com/vpn/manage_devices',
        },
        body: body
      )
      .timeout(const Duration(seconds: 3));

  print('got response:');
  print(response.body);

  // Auth token has expired
  if ( response.headers['location'] == '/login' ) {
    throw Exception('auth_cookie_expired');
  }

  if ( response.headers['content-type'] == 'application/json' ) {

    var map = json.decode(response.body)['result'];

    return createDevicesListForApp(map, currentMacAddress);

  }

  print('Unexpected response:');
  print(response.headers);
  print(response.body);

  throw Exception('Unexpected response');

}


Future<List> updateDevice(Map device, String authCookie, String currentMacAddress) async {

  print('updating API..');

  var data = json.encode(createDeviceMapForAPI(device));

  var url = 'https://expressvpnrouter.com/rpc',
      body = '{"jsonrpc":"2.0","id":5,"method":"save_advanced_routing","params":$data}';

  final response =
  await http
      .post(
      url,
      headers: {
        'Cookie': 'auth="$authCookie"',
        'Referer': 'https://expressvpnrouter.com/vpn/manage_devices',
      },
      body: body
  )
      .timeout(const Duration(seconds: 3));

  // Auth token has expired
  if ( response.headers['location'] == '/login' ) {
    throw Exception('auth_cookie_expired');
  }

  if ( response.headers['content-type'] == 'application/json' ) {

    var map = json.decode(response.body)['result'];

    return createDevicesListForApp(map, currentMacAddress);

  }

  print('Unexpected response:');
  print(response.headers);
  print(response.body);

  throw Exception('Unexpected response');

}

// Generates a map of MAC address to device info to send to the API
Map createDeviceMapForAPI(Map deviceObject) {

  var macAddress = deviceObject['mac_address'];
  var deviceAPIData = new Map.fromIterable(
      deviceObject.keys.where((k) => ! k.startsWith('__') && k != 'mac_address' ),
      key: (k) => k,
      value: (k) => deviceObject[k]
  );

  var map = new Map();
  map[macAddress] = deviceAPIData;

  return map;

}

// Convert map of MAC addresses to other device info (from API)
// to a list with all the device info (including mac address)
List createDevicesListForApp(Map deviceMap, String currentMacAddress) {

  var deviceList = [];
  RegExp matchMacAddress = new RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');

  deviceMap.forEach((key, value) {
    if ( matchMacAddress.hasMatch(key) && value['name'] != null ) {
      var deviceData = value;
      deviceData['mac_address'] = key;
      deviceList.add(deviceData);
    }
  });

  // If a device matches the current device, mark it as current
  var thisDevice = deviceList.firstWhere(
          (device) => device['mac_address'] == currentMacAddress,
      orElse: () => null
  );
  if ( thisDevice != null ) {
    thisDevice['__is_current_device'] = true;
  }

  // Sort devices alphabetically by name, with current device at the top
  // Capitalized names will go above lowercase ones, since this usually
  // means the person actually gave the device a name
  deviceList.sort((a, b) {
    if ( a['__is_current_device'] == true ) return -1;
    if ( b['__is_current_device'] == true ) return 1;
    return Comparable.compare(a['name'], b['name']);
  });

  // Note: internally-used properties are prefixed with a double underscore
  // and not sent to the API
  return deviceList;

}

//--

Card deviceCard(deviceData, theme, textEditingController, handleAction) {

  var isCurrentDevice = deviceData['__is_current_device'] == true;
  var isEditingName = deviceData['__is_editing_name'] == true;

  // Button styles
  var titleStyle = isCurrentDevice
      ? theme.textTheme.subhead.copyWith(height: 2.0, fontWeight: FontWeight.w600)
      : theme.textTheme.subhead.copyWith(height: 2.0);

  var optionTextStyle = theme.textTheme.button.copyWith(fontWeight: FontWeight.w400);
  var selectedOptionTextStyle = theme.textTheme.button.copyWith(color: Colors.white);
  var radius3px = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(3.0)));

  // API values for each of the 3 modes
  const vpnValue = 'vpn0';
  const mediaValue = 'ms0';
  const directValue = 'wan';

  // Determine which button is in an active state
  var usingVPN = deviceData['gw'] == vpnValue;
  var usingMedia = deviceData['gw'] == mediaValue;
  var usingDirect = deviceData['gw'] == directValue;

  // Current IP is used by connected devices.
  // IP is the prior (or first) IP address I think.
  var ipAddress = deviceData['current_ip'] ?? deviceData['ip'];

  return new Card(
    child: new Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
            children: <Widget>[
              Padding(padding: const EdgeInsets.all(8.0)),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isEditingName
                            ? <Widget>[
                                Container(
                                    width: 150.0,
                                    height: 48.0,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 4.0),
                                      ),
                                      autofocus: true,
                                      controller: textEditingController,
                                      onSubmitted: (e) { handleAction({ 'edit_name': false }); },
                                    ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.save),
                                  padding: const EdgeInsets.all(0.0),
                                  iconSize: 16.0,
                                  onPressed: () { handleAction({ 'edit_name': false }); },
                                  tooltip: 'edit device name',
                                ),
                              ]
                            : <Widget>[
                                Text(
                                  deviceData['name'],
                                  style: titleStyle,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  padding: const EdgeInsets.all(0.0),
                                  iconSize: 16.0,
                                  onPressed: () { handleAction({ 'edit_name': true }); },
                                  tooltip: 'edit device name',
                                ),
                              ]
                      ),
                      Text(
                        '$ipAddress | ${deviceData['mac_address']}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          height: 0.5,
                        ),
                      ),
                    ]),
              ),
              isCurrentDevice
                  ? IconButton(
                icon: const Icon(Icons.home),
                padding: const EdgeInsets.all(16.0),
                tooltip: 'current device',
                onPressed: null,
              )
                  : Container(),
//            IconButton(
//                icon: const Icon(Icons.star_border),
//                padding: const EdgeInsets.all(16.0),
//                onPressed: () { handleAction({ 'starred': ! isStarred }); },
//                tooltip: 'star device',
//              ),
            ]
        ),
        new ButtonTheme.bar( // make buttons use the appropriate styles for cards
          child: new ButtonBar(
            alignment: MainAxisAlignment.start,
            children: <Widget>[
              new RawMaterialButton(
                child: const Text('VPN'),
                padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                textStyle: usingVPN ? selectedOptionTextStyle : optionTextStyle,
                fillColor: usingVPN ? Colors.green : null,
                shape: radius3px,
                onPressed: () { handleAction({ 'mode': vpnValue }); },
              ),
              new RawMaterialButton(
                padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                child: const Text('MediaStreamer'),
                textStyle: usingMedia ? selectedOptionTextStyle : optionTextStyle,
                fillColor: usingMedia ? Colors.green : null,
                shape: radius3px,
                onPressed: () { handleAction({ 'mode': mediaValue }); },
              ),
              new RawMaterialButton(
                padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
                child: const Text('No VPN'),
                textStyle: usingDirect ? selectedOptionTextStyle : optionTextStyle,
                fillColor: usingDirect ? Colors.green : null,
                shape: radius3px,
                onPressed: () { handleAction({ 'mode': directValue }); },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}