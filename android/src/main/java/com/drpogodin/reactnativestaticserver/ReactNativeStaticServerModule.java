package com.drpogodin.reactnativestaticserver;

import androidx.annotation.NonNull;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.util.Enumeration;
import java.util.function.Consumer;

import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.drpogodin.reactnativestaticserver.Errors;
import com.lighttpd.Server;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactMethod;

import java.util.HashMap;
import java.util.Map;

public class ReactNativeStaticServerModule
  extends ReactNativeStaticServerSpec implements LifecycleEventListener
{
  // The currently active server instance. We assume only single server instance
  // can be active at any time, thus a simple field should be enought for now.
  // If we arrive to having possibility of multiple servers running in
  // parallel, then this will become a hash map [ID <-> Server], and we will
  // use it for communication from JS to this module to the target Server
  // instance.
  private Server server = null;

  public static final String NAME = "ReactNativeStaticServer";
  public static final String LOGTAG = Errors.LOGTAG
    + ": FPStaticServerModuleImpl";

  ReactNativeStaticServerModule(ReactApplicationContext context) {
    super(context);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  public Map<String,Object> getTypedExportedConstants() {
    final Map<String,Object> constants = new HashMap<>();

    constants.put("CRASHED", Server.CRASHED);
    constants.put("LAUNCHED", Server.LAUNCHED);
    constants.put("TERMINATED", Server.TERMINATED);

    return constants;
  }

  @ReactMethod
  public void getLocalIpAddress(Promise promise) {
    try {
      Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces();
      while(en.hasMoreElements()) {
        NetworkInterface intf = en.nextElement();
        Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses();
        while(enumIpAddr.hasMoreElements()) {
          InetAddress inetAddress = enumIpAddr.nextElement();
          if (!inetAddress.isLoopbackAddress()) {
            String ip = inetAddress.getHostAddress();
            if(InetAddressUtils.isIPv4Address(ip)) {
              promise.resolve(ip);
              return;
            }
          }
        }
      }
      promise.resolve("localhost");
    } catch (Exception e) {
      Errors.FAIL_GET_LOCAL_IP_ADDRESS.reject(promise);
    }
  }

  @ReactMethod
  public void start(
    double id, // Server ID for backward communication with JS layer.
    String configPath,
    Promise promise
  ) {
    Log.i(LOGTAG, "Starting...");

    if (server != null) {
      Errors.ANOTHER_INSTANCE_IS_ACTIVE.log().reject(promise);
      return;
    }

    DeviceEventManagerModule.RCTDeviceEventEmitter emitter =
      getReactApplicationContext()
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class);

    server = new Server(
      configPath,
      new Consumer<String>() {
        private boolean settled = false;
        public void accept(String signal) {
          if (!settled) {
            settled = true;
            if (signal == Server.LAUNCHED) promise.resolve(null);
            else Errors.LAUNCH_FAILURE.reject(promise);
          }
          WritableMap event = Arguments.createMap();
          event.putDouble("serverId", id);
          event.putString("event", signal);
          emitter.emit("RNStaticServer", event);
        }
      }
    );
    server.start();
  }

  @ReactMethod
  public void getOpenPort(Promise promise) {
    try {
      ServerSocket socket = new ServerSocket(0);
      int port = socket.getLocalPort();
      socket.close();
      promise.resolve(port);
    } catch (Exception e) {
      Errors.FAIL_GET_OPEN_PORT.log(e).reject(promise);
    }
  }

  @ReactMethod
  public void stop(Promise promise) {
    try {
      Log.i(LOGTAG, "stop() triggered.");
      if (server != null) {
        server.interrupt();
        server.join();
        server = null;
        Log.i(LOGTAG, "Active server stopped");
      } else Log.i(LOGTAG, "No active server");
      if (promise != null) promise.resolve(null);
    } catch (Exception e) {
      Errors.STOP_FAILURE.log(e).reject(promise);
    }
  }

  @ReactMethod
  public void addListener(String eventName) {
    // NOOP
  }

  @ReactMethod
  public void removeListeners(double count) {
    // NOOP
  }

  @ReactMethod
  public void isRunning(Promise promise) {
    promise.resolve(server != null && server.isAlive());
  }

  // NOTE: Pause/resume operations, if opted, are managed in JS layer.
  @Override
  public void onHostResume() {}

  @Override
  public void onHostPause() {}

  @Override
  public void onHostDestroy() {
    stop(null);
  }
}
