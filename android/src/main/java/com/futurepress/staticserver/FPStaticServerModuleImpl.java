
package com.futurepress.staticserver;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.Promise;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
import java.net.ServerSocket;

import android.util.Log;

import fi.iki.elonen.SimpleWebServer;

public class FPStaticServerModuleImpl {
  private final ReactApplicationContext reactContext;

  public static final String NAME = "StaticServer";

  private File www_root = null;
  private int port = 9999;
  private boolean localhost_only = false;
  private boolean keep_alive = false;

  private String localPath = "";
  private SimpleWebServer server = null;
  private String	url = "";

  public FPStaticServerModuleImpl(ReactApplicationContext reactContext) {
    this.reactContext = reactContext;
  }

  private String __getLocalIpAddress() {
    try {
      for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements();) {
        NetworkInterface intf = en.nextElement();
        for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements();) {
          InetAddress inetAddress = enumIpAddr.nextElement();
          if (! inetAddress.isLoopbackAddress()) {
            String ip = inetAddress.getHostAddress();
            if(InetAddressUtils.isIPv4Address(ip)) {
              Log.w(NAME, "local IP: "+ ip);
              return ip;
            }
          }
        }
      }
    } catch (SocketException ex) {
      Log.e(NAME, ex.toString());
    }

    return "127.0.0.1";
  }

  public void start(String _port, String root, Boolean localhost, Boolean keepAlive, Promise promise) {

    if (server != null){
      promise.resolve(url);
      return;
    }

    if (_port != null) {
      try {
        port = Integer.parseInt(_port);

        if (port == 0) {
          try {
            port = this.findRandomOpenPort();
          } catch (IOException e) {
            port = 9999;
          }
        }
      } catch(NumberFormatException nfe) {
        try {
          port = this.findRandomOpenPort();
        } catch (IOException e) {
          port = 9999;
        }
      }
    }

    if(root != null && (root.startsWith("/") || root.startsWith("file:///"))) {
      www_root = new File(root);
      localPath = www_root.getAbsolutePath();
    } else {
      www_root = new File(this.reactContext.getFilesDir(), root);
      localPath = www_root.getAbsolutePath();
    }

    if (localhost != null) {
      localhost_only = localhost;
    }

    if (keepAlive != null) {
      keep_alive = keepAlive;
    }

    try {
      if(localhost_only) {
        server = new WebServer("localhost", port, www_root);
      } else {
        server = new WebServer(__getLocalIpAddress(), port, www_root);
      }

      if (localhost_only) {
        url = "http://localhost:" + port;
      } else {
        url = "http://" + __getLocalIpAddress() + ":" + port;
      }

      server.start();
      promise.resolve(url);
    } catch (IOException e) {
      String msg = e.getMessage();

      // Server doesn't stop on refresh
      if (server != null && msg.equals("bind failed: EADDRINUSE (Address already in use)")){
        promise.resolve(url);
      } else {
        promise.reject(null, msg);
      }
    }
  }

  private Integer findRandomOpenPort() throws IOException {
    try {
      ServerSocket socket = new ServerSocket(0);
      int port = socket.getLocalPort();
      Log.w(NAME, "port:" + port);
      socket.close();
      return port;
    } catch (IOException e) {
      return 0;
    }
  }

  public void stop(Promise promise) {
    if (server != null) {
      Log.w(NAME, "Stopped Server");
      server.stop();
      server = null;

      // TODO: Not sure, whether it is fine to resolve the promise just like
      // this, or should we do something to wait for the server to actually
      // stop. Should be double-checked in the underlying server docs.
      promise.resolve("");
    }
  }

  // TODO: A version without Promise argument, it should be combined with the
  // version above.
  public void stop() {
    if (server != null) {
      Log.w(NAME, "Stopped Server");
      server.stop();
      server = null;
    }
  }

  public void origin(Promise promise) {
    if (server != null) {
      promise.resolve(url);
    } else {
      promise.resolve("");
    }
  }

  public void isRunning(Promise promise) {
    promise.resolve(server != null && server.isAlive());
  }
}
