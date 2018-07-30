package com.micahjon.expressvpntoggler;

import android.os.Bundle;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.*;
import java.net.NetworkInterface;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "expressvpn-toggler/mac-address";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        GeneratedPluginRegistrant.registerWith(this);

        new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler(
            new MethodCallHandler() {
                @Override
                public void onMethodCall(MethodCall call, Result result) {
                    if (call.method.equals("getMacAddress")) {
//                        int batteryLevel = getMacAddress();

                        String macAddress = getMacAddress();


//                        if (batteryLevel != -1) {
                        result.success(macAddress);
//                        } else {
//                            result.error("UNAVAILABLE", "Battery level not available.", null);
//                        }
                    } else {

                        result.notImplemented();
                    }
            }
        });

    }

    /**
     * Get MAC address of current device
     * https://stackoverflow.com/questions/33159224/getting-mac-address-in-android-6-0
     * @return String
     */
    public static String getMacAddress() {

        // TEMP - FOR DEBUGGING
        String str = "a4:5e:60:e1:c0:11";
        return str.toUpperCase();

        //--
//
//        try {
//            List<NetworkInterface> all = Collections.list(NetworkInterface.getNetworkInterfaces());
//            for (NetworkInterface nif : all) {
//                if (!nif.getName().equalsIgnoreCase("wlan0")) continue;
//
//                byte[] macBytes = nif.getHardwareAddress();
//                if (macBytes == null) {
//                    return "";
//                }
//
//                StringBuilder res1 = new StringBuilder();
//                for (byte b : macBytes) {
//                    res1.append(Integer.toHexString(b & 0xFF) + ":");
//                }
//
//                if (res1.length() > 0) {
//                    res1.deleteCharAt(res1.length() - 1);
//                }
//                return res1.toString();
//            }
//        } catch (Exception ex) {
//            //handle exception
//        }
//        return "";
    }
}
