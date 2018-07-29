import 'package:flutter/material.dart';
import 'dart:async'; // Future
import 'dart:convert'; // json
import 'package:http/http.dart' as http; // http
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

  var mode = 1;

  void handleAction(device, action) {

    print('new action ---------');
    print(device);
    print(action);

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
              future: getDeviceList(widget.authCookie),
              builder: (context, snapshot) {

                if ( snapshot.hasError ) {
                  return Text("Unable to fetch device list: ${snapshot.error}");
                }

                if ( ! snapshot.hasData ) {
                  return CircularProgressIndicator();
                }

                var devices = snapshot.data;

                // If a device matches the current device, mark it as current
                // and move it to the beginning of the list
                var thisDevice = devices.firstWhere(
                    (device) => device['mac_address'] == widget.macAddress,
                    orElse: () => null
                );
                if ( thisDevice != null ) {
                  thisDevice['__is_current_device'] = true;
                  devices.remove(thisDevice);
                  devices.insert(0, thisDevice);
                }

//                print('thisDevice?');
//                print(thisDevice);

                return new ListView.builder(
                    itemBuilder: (context, index) {
                      return deviceCard(
                          devices[index],
                          Theme.of(context),
                          (action) { handleAction(devices[index], action); },
                      );
                    },
                    itemCount: snapshot.data.length
                );

              },
            ),
        ),
      ),
    );
  }
}

Card deviceCard(deviceData, theme, handleAction) {

  var isCurrentDevice = deviceData['__is_current_device'] == true;
  var isStarred = deviceData['__is_starred'] == true;

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
                    children: <Widget>[
                      Text(
                          deviceData['name'],
                          style: titleStyle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        padding: const EdgeInsets.all(0.0),
                        iconSize: 16.0,
                        onPressed: () { handleAction({ 'editName': true }); },
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
                  icon: const Icon(Icons.phone_android),
                  padding: const EdgeInsets.all(16.0),
                  tooltip: 'current device',
                  onPressed: () {},
              )
              : IconButton(
                icon: const Icon(Icons.star_border),
                padding: const EdgeInsets.all(16.0),
                onPressed: () { handleAction({ 'starred': ! isStarred }); },
                tooltip: 'star device',
              ),
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

Future<List> getDeviceList(String authCookie) async {

  const url = 'https://expressvpnrouter.com/rpc',
    body = '{"jsonrpc":"2.0","id":1,"method":"load_advanced_routing"}';

  final response =
  await http
      .post(
        url,
        headers: {
          'Cookie': 'auth="'+ authCookie + '"', // 'auth="test"', //
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

    var list = [];
    RegExp matchMacAddress = new RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');

    map.forEach((key, value) {
      if ( matchMacAddress.hasMatch(key) ) {
        var deviceData = value;
        deviceData['mac_address'] = key;
        list.add(deviceData);
      }
    });

    return list;

  }

  print('Unexpected response:');
  print(response.headers);
  print(response.body);

  throw Exception('Unexpected response');

}
