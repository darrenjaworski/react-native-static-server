import {
  AppState,
  AppStateStatus,
  NativeEventSubscription,
  NativeModules,
  Platform,
} from 'react-native';

declare global {
  var __turboModuleProxy: object | undefined;
}

// This selects between TurboModule and legacy RN library implementation.
const FPStaticServer = global.__turboModuleProxy
  ? require('./NativeStaticServer').default
  : NativeModules.StaticServer;

type Options = {
  keepAlive?: boolean;
  localOnly?: boolean;
};

class StaticServer {
  // Note: could be a private method, and we tried it, but it turns out that
  // Babel's @babel/plugin-proposal-private-methods causes many troubles in RN.
  // See: https://github.com/birdofpreyru/react-native-static-server/issues/6
  // and: https://github.com/birdofpreyru/react-native-static-server/issues/9
  _appStateSub?: NativeEventSubscription;

  _origin?: string;

  keepAlive: boolean;
  localOnly: boolean;

  // NOTE: It was type-defed as "number" prior to v0.6.0, but it was wrong,
  // the value was "string" all along.
  port: string = '';

  root: null | string;
  running: boolean = false;
  started: boolean = false;

  /**
   * Creates a new StaticServer instance.
   *
   * Because the legacy, the following alternative signatures are supported,
   * and the overall constructor implementation is thus subpar.
   *
   * new StaticServer(port, root, opts);
   * new StaticServer(port, opts);
   * new StaticServer(port, root);
   * new StaticServer(opts);
   * new StaticServer(port);
   * new StaticServer();
   *
   * @param portOrOpts
   * @param rootOrOpts
   * @param opts
   */
  constructor(
    portOrOpts?: number | Options,
    rootOrOpts?: Options | string,
    opts?: Options,
  ) {
    switch (arguments.length) {
      case 3:
        this.port = `${portOrOpts}`;

        if (typeof rootOrOpts === 'string') this.root = rootOrOpts || null;
        else if (!rootOrOpts) this.root = null;
        else throw Error('Invalid "root" type');

        this.localOnly = (opts && opts.localOnly) || false;
        this.keepAlive = (opts && opts.keepAlive) || false;
        break;
      case 2:
        this.port = `${portOrOpts}`;

        if (typeof rootOrOpts === 'string') {
          this.root = rootOrOpts;
          this.localOnly = false;
          this.keepAlive = false;
        } else {
          this.root = null;
          this.localOnly = (rootOrOpts && rootOrOpts.localOnly) || false;
          this.keepAlive = (rootOrOpts && rootOrOpts.keepAlive) || false;
        }
        break;
      case 1:
        if (typeof portOrOpts === 'number') {
          this.port = `${portOrOpts}`;
          this.root = null;
          this.localOnly = false;
          this.keepAlive = false;
        } else {
          this.port = '';
          this.root = null;
          this.localOnly = (portOrOpts && portOrOpts.localOnly) || false;
          this.keepAlive = (portOrOpts && portOrOpts.keepAlive) || false;
        }
        break;
      default:
        this.port = '';
        this.root = null;
        this.localOnly = false;
        this.keepAlive = false;
    }
  }

  start(): Promise<string> {
    if (this.running) {
      return Promise.resolve(this.origin!);
    }

    this.started = true;
    this.running = true;

    if (!this.keepAlive && Platform.OS === 'android') {
      this._appStateSub = AppState.addEventListener(
        'change',
        this._handleAppStateChange.bind(this),
      );
    }

    return FPStaticServer.start(
      this.port,
      this.root,
      this.localOnly,
      this.keepAlive,
    ).then((origin: string) => {
      this._origin = origin;
      return origin;
    });
  }

  stop(): Promise<void> {
    this.running = false;

    return FPStaticServer.stop();
  }

  kill() {
    this.stop();
    this.started = false;
    this._origin = undefined;
    if (this._appStateSub) this._appStateSub.remove();
  }

  _handleAppStateChange(appState: AppStateStatus) {
    if (!this.started) {
      return;
    }

    if (appState === 'active' && !this.running) {
      this.start();
    }

    if (appState === 'background' && this.running) {
      this.stop();
    }

    if (appState === 'inactive' && this.running) {
      this.stop();
    }
  }

  get origin() {
    return this._origin;
  }

  isRunning(): Promise<boolean> {
    return FPStaticServer.isRunning().then((running: boolean) => {
      this.running = running;
      return this.running;
    });
  }
}

export default StaticServer;
