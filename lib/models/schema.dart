import 'field_spec.dart';
import 'help_text.dart';
import 'vpn_config.dart';

/// Shared predicates. The preview computes these from `cfg` on every refresh;
/// they live here so a field's `show`/`enabledWhen` can use them directly.
bool isWhite(VpnConfig c) => c.textOf('engine') == 'white';
bool isDns(VpnConfig c) => c.textOf('engine') == 'dns';
bool isDnsServer(VpnConfig c) => isDnsServerMode(c);
bool isDnsServerMode(VpnConfig c) => c.textOf('dnsServerMode') == 'custom';
bool isDnsCotten(VpnConfig c) => c.textOf('dnsEngine') == 'cotten';
bool isDnsSockAuth(VpnConfig c) => c.boolOf('dnsSockAuth');
bool isDnsHttpOn(VpnConfig c) => c.boolOf('dnsHttpEnabled');
bool isDnsLocalDns(VpnConfig c) => c.boolOf('dnsLocalDns');
bool isDnsWarmup(VpnConfig c) => c.boolOf('dnsWarmup');
bool isDnsSplitOn(VpnConfig c) => c.textOf('dnsSplit') != 'off';
bool isDnsVpnMode(VpnConfig c) => c.textOf('dnsConnMode') == 'vpn';

String wayOf(VpnConfig c) {
  final String engine = c.textOf('engine');
  if (engine == 'psiphon') return c.textOf('psWay');
  if (engine == 'tor') return c.textOf('torWay');
  return 'warp';
}

bool isReverse(VpnConfig c) =>
    c.textOf('engine') != 'aether' &&
    c.textOf('engine') != 'white' &&
    wayOf(c) == 'reverse';

bool usesWarp(VpnConfig c) =>
    c.textOf('engine') == 'aether' ||
    (c.textOf('engine') != 'white' && wayOf(c) != 'only');

bool isTransport(VpnConfig c, String value) => c.textOf('transport') == value;

bool isHttp2(VpnConfig c) => c.textOf('carrier') == 'h2';

/// Help for a value of a key, straight out of the Persian table.
String helpFor(String key, String value) => kHelp['$key.$value'] ?? '';

/// Look up a field by its config key, across both lists.
FieldSpec? findField(String key) {
  for (final SectionSpec section in kMethodSections) {
    for (final FieldSpec field in section.fields) {
      if (field.key == key) return field;
    }
  }
  for (final SectionSpec section in kAdvancedSections) {
    for (final FieldSpec field in section.fields) {
      if (field.key == key) return field;
    }
  }
  return null;
}

/// Segmented options. The preview keeps these beside the schema so the value,
/// the label and the help line travel together.
const List<List<String>> kScanOptions = <List<String>>[
  <String>['turbo', 'توربو'],
  <String>['balanced', 'متعادل'],
  <String>['thorough', 'دقیق'],
  <String>['stealth', 'پنهان'],
  <String>['verified', 'تأییدشده'],
  <String>['ironclad', 'آهنین'],
];

const List<List<String>> kNoizeOptions = <List<String>>[
  <String>['off', 'خاموش'],
  <String>['light', 'سبک'],
  <String>['firewall', 'Firewall'],
  <String>['balanced', 'متعادل'],
  <String>['gfw', 'GFW'],
  <String>['aggressive', 'سنگین'],
];

/// The "روش اتصال" accordion: one section per engine, shown only when that
/// engine is selected, exactly as the preview decides visibility.
final List<SectionSpec> kMethodSections = <SectionSpec>[
  SectionSpec(
    id: 'psiphon',
    title: 'Psiphon (سایفون)',
    open: true,
    show: (VpnConfig c) => c.textOf('engine') == 'psiphon',
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'seg',
        key: 'psWay',
        label: 'نحوه اتصال',
        flag: '--psiphon-only / --psiphon / --psiphon-reverse',
        columns: 1,
        options: <List<String>>[
          <String>['only', 'به‌تنهایی'],
          <String>['chain', 'داخل WARP'],
          <String>['reverse', 'WARP داخل Psiphon'],
        ],
        helpKey: 'psWay',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'psShape',
        label: 'شکل اتصال',
        flag: '--psiphon-mode',
        columns: 3,
        options: <List<String>>[
          <String>['auto', 'خودکار'],
          <String>['cdn', 'فقط CDN'],
          <String>['direct', 'مستقیم'],
        ],
        helpKey: 'psShape',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psRegion',
        label: 'کشور خروجی',
        flag: '--psiphon-region',
        placeholder: 'مثلاً DE',
        help: 'کد دو حرفی کشور. فهرست کشورهای موجود در AvailableEgressRegions خروجی Psiphon آمده است.',
      ),
      const FieldSpec(
        type: 'area',
        key: 'psCdnIps',
        label: 'آدرس‌های CDN',
        flag: '--psiphon-cdn-ips',
        placeholder: 'با کاما یا فاصله جدا کنید',
        help: 'اگر خالی باشد از فهرست داخلی Psiphon استفاده می‌شود.',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psCdnSni',
        label: 'نام سرور (SNI) برای CDN',
        flag: '--psiphon-cdn-sni',
        placeholder: 'example.com',
      ),
      FieldSpec(
        type: 'text',
        key: 'psBind',
        label: 'آدرس پروکسی Psiphon',
        flag: '--psiphon-bind',
        placeholder: '127.0.0.1:1821',
        help: 'با حالت «داخل WARP» و «WARP داخل Psiphon» استفاده می‌شود.',
        show: (VpnConfig c) => c.textOf('psWay') != 'only',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psHttp',
        label: 'پروکسی HTTP برای Psiphon',
        flag: '--psiphon-http',
        placeholder: 'خالی = خاموش',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psConfig',
        label: 'فایل تنظیمات JSON دلخواه',
        flag: '--psiphon-config',
        placeholder: '/path/psiphon.json',
        help: 'فقط برای استفاده از اعتبارنامه یا فهرست سرور متفاوت.',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psDir',
        label: 'پوشه داده Psiphon',
        flag: '--psiphon-dir',
        placeholder: 'پیش‌فرض کنار فایل هویت',
      ),
      const FieldSpec(
        type: 'text',
        key: 'psBin',
        label: 'مسیر psiphon-tunnel-core',
        flag: '--psiphon-bin',
        placeholder: 'اگر کنار برنامه نیست',
      ),
    ],
  ),
  SectionSpec(
    id: 'tor',
    title: 'Tor (تور)',
    open: true,
    note: 'Tor فقط در نسخه‌ای کار می‌کند که با قابلیت tor ساخته شده باشد.',
    show: (VpnConfig c) => c.textOf('engine') == 'tor',
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'seg',
        key: 'torWay',
        label: 'نحوه اتصال',
        flag: '--tor-only / --tor / --tor-reverse',
        columns: 1,
        options: <List<String>>[
          <String>['only', 'به‌تنهایی'],
          <String>['chain', 'Tor داخل WARP'],
          <String>['reverse', 'WARP داخل Tor'],
        ],
        helpKey: 'torWay',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'torBridges',
        label: 'پل‌ها (Bridge)',
        flag: '--tor-bridges / --no-tor-bridges / --tor-bridge',
        columns: 2,
        options: <List<String>>[
          <String>['auto', 'خودکار'],
          <String>['force', 'همیشه پل'],
          <String>['never', 'بدون پل'],
          <String>['custom', 'پل دلخواه'],
        ],
        helpKey: 'torBridges',
      ),
      FieldSpec(
        type: 'area',
        key: 'torBridgeLines',
        label: 'خط‌های پل',
        flag: '--tor-bridge',
        placeholder: 'obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0',
        help: 'هر پل در یک خط.',
        show: (VpnConfig c) => c.textOf('torBridges') == 'custom',
      ),
      FieldSpec(
        type: 'text',
        key: 'torBridgeFile',
        label: 'فایل پل‌ها',
        flag: '--tor-bridge-file',
        placeholder: '/path/bridges.txt',
        show: (VpnConfig c) => c.textOf('torBridges') != 'never',
      ),
      FieldSpec(
        type: 'text',
        key: 'torPt',
        label: 'ترنسپورت (Pluggable Transport)',
        flag: '--tor-pt',
        placeholder: 'snowflake=/path/snowflake-client',
        help: 'به‌طور پیش‌فرض obfs4 فرض می‌شود و باینری‌ها خودکار پیدا می‌شوند.',
        show: (VpnConfig c) => c.textOf('torBridges') != 'never',
      ),
      FieldSpec(
        type: 'text',
        key: 'torPtDir',
        label: 'پوشه ترنسپورت‌ها',
        flag: '--tor-pt-dir',
        placeholder: 'پیش‌فرض pt/ کنار برنامه',
        show: (VpnConfig c) => c.textOf('torBridges') != 'never',
      ),
      FieldSpec(
        type: 'seg',
        key: 'torRelays',
        label: 'رله‌های Onionoo',
        flag: '--tor-relays',
        columns: 3,
        options: <List<String>>[
          <String>['auto', 'خودکار'],
          <String>['only', 'فقط رله'],
          <String>['off', 'خاموش'],
        ],
        helpKey: 'torRelays',
        show: (VpnConfig c) => c.textOf('torBridges') != 'never',
      ),
      FieldSpec(
        type: 'num',
        key: 'torRelayCount',
        label: 'تعداد رله (اختیاری)',
        flag: '--tor-relays <n>',
        placeholder: 'مثلاً 80',
        show: (VpnConfig c) =>
            c.textOf('torBridges') != 'never' && c.textOf('torRelays') != 'off',
      ),
      FieldSpec(
        type: 'seg',
        key: 'torRelayPorts',
        label: 'پورت رله‌ها',
        flag: '--tor-relay-ports',
        columns: 2,
        options: <List<String>>[
          <String>['web', 'وب (۸۰ و ۴۴۳)'],
          <String>['any', 'همه'],
        ],
        help: '«وب» پورت‌هایی است که فایروال‌های سخت‌گیر معمولاً باز می‌گذارند.',
        show: (VpnConfig c) =>
            c.textOf('torBridges') != 'never' && c.textOf('torRelays') != 'off',
      ),
      FieldSpec(
        type: 'text',
        key: 'torBind',
        label: 'آدرس پروکسی Tor',
        flag: '--tor-bind',
        placeholder: '127.0.0.1:1820',
        show: (VpnConfig c) => c.textOf('torWay') != 'only',
      ),
      const FieldSpec(
        type: 'text',
        key: 'torHttp',
        label: 'پروکسی HTTP برای Tor',
        flag: '--tor-http',
        placeholder: 'خالی = خاموش',
      ),
      const FieldSpec(
        type: 'text',
        key: 'torDir',
        label: 'پوشه داده Tor',
        flag: '--tor-dir',
        placeholder: 'پیش‌فرض کنار فایل هویت',
      ),
    ],
  ),
  SectionSpec(
    id: 'warp',
    title: 'تونل WARP',
    open: true,
    show: usesWarp,
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'note',
        text: 'در این حالت فقط MASQUE روی HTTP/2 ممکن است؛ WireGuard و Gool و MASQUE-in-MASQUE غیرفعال شدند.',
        show: isReverse,
      ),
      const FieldSpec(
        type: 'seg',
        key: 'transport',
        label: 'نوع تونل',
        flag: '--masque / --wg / --gool / --mim',
        columns: 2,
        options: <List<String>>[
          <String>['masque', 'MASQUE'],
          <String>['wg', 'WireGuard'],
          <String>['gool', 'WARP-in-WARP'],
          <String>['mim', 'MASQUE-in-MASQUE'],
        ],
        helpKey: 'transport',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'scan',
        label: 'حالت جست‌وجوی آدرس',
        flag: '--scan',
        columns: 3,
        options: kScanOptions,
        helpKey: 'scan',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'noize',
        label: 'پروفایل استتار (Noize)',
        flag: '--noize',
        columns: 3,
        options: kNoizeOptions,
        helpKey: 'noize',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'ip',
        label: 'نسخه IP',
        flag: '-4 / -6 / --dual',
        columns: 3,
        options: <List<String>>[
          <String>['4', 'IPv4'],
          <String>['6', 'IPv6'],
          <String>['both', 'هر دو'],
        ],
        help: 'اگر شبکه شما IPv6 ندارد روی IPv4 بمانید.',
      ),
      FieldSpec(
        type: 'text',
        key: 'peer',
        label: 'آدرس سرور مشخص',
        flag: '--peer',
        placeholder: '162.159.196.1:443',
        help: 'اسکن رد می‌شود.',
        show: (VpnConfig c) => isTransport(c, 'masque') || isTransport(c, 'wg'),
      ),
      FieldSpec(
        type: 'text',
        key: 'wiwOuter',
        label: 'هاپ بیرونی',
        flag: '--wiw-outer',
        placeholder: '162.159.192.1:2408',
        help: 'همان که شبکه شما می‌بیند. پورت الزامی است.',
        show: (VpnConfig c) => isTransport(c, 'gool'),
      ),
      FieldSpec(
        type: 'text',
        key: 'wiwInner',
        label: 'هاپ داخلی',
        flag: '--wiw-inner',
        placeholder: '188.114.96.1:2408',
        help: 'از داخل هاپ بیرونی رسیده می‌شود و باید آدرسش فرق کند.',
        show: (VpnConfig c) => isTransport(c, 'gool'),
      ),
      FieldSpec(
        type: 'text',
        key: 'mimOuter',
        label: 'هاپ بیرونی',
        flag: '--mim-outer',
        placeholder: '162.159.192.1:443',
        show: (VpnConfig c) => isTransport(c, 'mim'),
      ),
      FieldSpec(
        type: 'text',
        key: 'mimInner',
        label: 'هاپ داخلی',
        flag: '--mim-inner',
        placeholder: '162.159.204.1:443',
        help: 'دو هاپ باید آدرس متفاوت داشته باشند.',
        show: (VpnConfig c) => isTransport(c, 'mim'),
      ),
      const FieldSpec(
        type: 'sw',
        key: 'quick',
        label: 'اتصال مجدد سریع',
        flag: '--quick-reconnect',
        help: 'از آخرین آدرس سالم استفاده کن و اسکن نکن.',
      ),
    ],
  ),
  SectionSpec(
    id: 'masque',
    title: 'MASQUE',
    show: (VpnConfig c) =>
        usesWarp(c) && (isTransport(c, 'masque') || isTransport(c, 'mim')),
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'seg',
        key: 'carrier',
        label: 'نسخه پروتکل',
        flag: '--h3 / --h2',
        columns: 2,
        options: <List<String>>[
          <String>['h3', 'HTTP/3 (QUIC)'],
          <String>['h2', 'HTTP/2 (TCP)'],
        ],
        help: 'اگر UDP پورت ۴۴۳ مسدود است HTTP/2 را انتخاب کنید.',
      ),
      const FieldSpec(
        type: 'sw',
        key: 'quicV2',
        label: 'شروع‌کننده QUIC v2',
        flag: '--no-quic-v2',
        help: 'مسیر HTTP/3 را روی شبکه‌هایی که QUIC v1 را می‌بندند باز می‌کند.',
      ),
      const FieldSpec(
        type: 'text',
        key: 'h2Peer',
        label: 'آدرس سرور برای HTTP/2',
        flag: '--h2-peer',
        placeholder: '162.159.196.1:443',
        show: isHttp2,
      ),
      const FieldSpec(
        type: 'sw',
        key: 'fragment',
        label: 'تکه‌تکه کردن ClientHello',
        flag: '--fragment',
        help: 'SNI را از بازرسی‌هایی که یک بسته را می‌خوانند پنهان می‌کند.',
        show: isHttp2,
      ),
      FieldSpec(
        type: 'text',
        key: 'fragSize',
        label: 'اندازه تکه‌ها (بایت)',
        flag: '--fragment-size',
        placeholder: '16-32',
        show: (VpnConfig c) => isHttp2(c) && c.boolOf('fragment'),
      ),
      FieldSpec(
        type: 'text',
        key: 'fragDelay',
        label: 'فاصله بین تکه‌ها (میلی‌ثانیه)',
        flag: '--fragment-delay',
        placeholder: '2-10',
        show: (VpnConfig c) => isHttp2(c) && c.boolOf('fragment'),
      ),
      const FieldSpec(
        type: 'sw',
        key: 'ech',
        label: 'Encrypted Client Hello',
        flag: '--ech auto',
        help: 'SNI را کاملاً پنهان می‌کند، اگر شبکه اجازه بدهد.',
      ),
    ],
  ),
  SectionSpec(
    id: 'wg',
    title: 'WireGuard',
    show: (VpnConfig c) =>
        usesWarp(c) && (isTransport(c, 'wg') || isTransport(c, 'gool')),
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'num',
        key: 'keepalive',
        label: 'فاصله Keepalive (ثانیه)',
        flag: '--keepalive',
        placeholder: '5',
      ),
      const FieldSpec(
        type: 'sw',
        key: 'noRetry',
        label: 'امتحان نکردن پروفایل‌های دیگر',
        flag: '--no-profile-retry',
        help: 'در اسکن، پروفایل‌های استتار دیگر را دوباره امتحان نکن.',
      ),
    ],
  ),
  SectionSpec(
    id: 'health',
    title: 'پایداری و بررسی داده',
    show: usesWarp,
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'sw',
        key: 'dataCheck',
        label: 'بررسی سرتاسری مسیر داده',
        flag: '--no-data-check',
        help: 'قبل از باز شدن پروکسی، یک آدرس باید ترافیک واقعی رد کند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'validateSecs',
        label: 'مهلت بررسی (ثانیه)',
        flag: '--validate-secs',
        placeholder: '10',
        show: (VpnConfig c) => c.boolOf('dataCheck'),
      ),
      FieldSpec(
        type: 'num',
        key: 'startupSecs',
        label: 'مهلت راه‌اندازی (ثانیه)',
        flag: '--startup-secs',
        placeholder: '30',
        show: (VpnConfig c) => isTransport(c, 'masque') || isTransport(c, 'mim'),
      ),
      const FieldSpec(
        type: 'num',
        key: 'reconnectSecs',
        label: 'تأخیر اتصال دوباره (ثانیه)',
        flag: '--reconnect-secs',
        placeholder: '2',
      ),
      const FieldSpec(
        type: 'text',
        key: 'dns',
        label: 'DNS داخل تونل',
        flag: '--dns',
        placeholder: '1.1.1.1,1.0.0.1',
      ),
    ],
  ),
  SectionSpec(
    id: 'white',
    title: 'White (وایت)',
    open: true,
    show: isWhite,
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'note',
        text: 'وایت با هسته Mihomo کار می‌کند و از سابسکریپشن داخلی یا لینک خودتان سرور انتخاب می‌کند.',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whSub',
        label: 'منبع اتصال',
        flag: '--subscription',
        columns: 2,
        options: <List<String>>[
          <String>['builtin', 'داخلی وایت'],
          <String>['personal', 'شخصی'],
        ],
        helpKey: 'whSub',
      ),
      FieldSpec(
        type: 'text',
        key: 'whSubUrl',
        label: 'لینک سابسکریپشن',
        flag: '--sub-url',
        placeholder: 'https://…',
        help: 'URL، YAML، JSON یا فهرست لینک‌های VLESS، VMess، Trojan، Hysteria2، Shadowsocks، WireGuard یا SOCKS5.',
        show: (VpnConfig c) => c.textOf('whSub') == 'personal',
      ),
      const FieldSpec(
        type: 'servers',
        key: 'whServer',
        label: 'انتخاب سرور',
        flag: '--proxy',
        helpKey: 'whServerPick',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whSort',
        label: 'ترتیب فهرست',
        flag: '--sort',
        columns: 3,
        options: <List<String>>[
          <String>['low', 'کمترین تأخیر'],
          <String>['fast', 'سریع‌ترین'],
          <String>['sub', 'ترتیب سابسکریپشن'],
        ],
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whChain',
        label: 'زنجیره اتصال',
        flag: '--chain',
        columns: 2,
        options: <List<String>>[
          <String>['direct', 'مستقیم'],
          <String>['warp', 'WARP → سرور'],
        ],
        helpKey: 'whChain',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whRoute',
        label: 'حالت مسیریابی',
        flag: '--routing',
        columns: 3,
        options: <List<String>>[
          <String>['sub', 'قوانین اشتراک'],
          <String>['iran', 'عبور مستقیم ایران'],
          <String>['global', 'پروکسی سراسری'],
        ],
        helpKey: 'whRoute',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whDns',
        label: 'حالت DNS',
        flag: '--dns-mode',
        columns: 4,
        options: <List<String>>[
          <String>['auto', 'خودکار'],
          <String>['doh', 'DoH'],
          <String>['dot', 'DoT'],
          <String>['doq', 'DoQ'],
        ],
        helpKey: 'whDns',
      ),
      FieldSpec(
        type: 'text',
        key: 'whDnsAddr',
        label: 'آدرس سرور DNS',
        flag: '--dns-server',
        placeholder: '1.1.1.1',
        show: (VpnConfig c) => c.textOf('whDns') != 'auto',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'whNoise',
        label: 'نویز و بسته‌های DPI',
        flag: '--amnezia-noise',
        columns: 3,
        options: <List<String>>[
          <String>['off', 'خاموش'],
          <String>['light', 'سبک'],
          <String>['full', 'کامل'],
        ],
        helpKey: 'whNoise',
      ),
      const FieldSpec(
        type: 'text',
        key: 'whFronting',
        label: 'جایگذاری IP (IP Fronting)',
        flag: '--fronting',
        placeholder: '198.51.100.10:443',
        help: 'ترافیک روی یک IP معتبر دیگر پنهان می‌شود تا بازرسی آن را نبیند.',
      ),
    ],
  ),
  const SectionSpec(
    id: 'dns',
    title: 'DNS (SOFT400)',
    open: true,
    show: isDns,
    note: 'حالت DNS با کلاینت tunnelling وایت‌دی‌ان‌اس کار می‌کند: همه ترافیک داخل درخواست‌ها و پاسخ‌های DNS جاسازی می‌شود؛ در شبکه‌هایی که فقط پورت ۵۳ باز است هم راه باز می‌کند.',
    fields: <FieldSpec>[
      FieldSpec(
        type: 'seg',
        key: 'dnsConnMode',
        label: 'حالت اتصال',
        flag: 'Proxy Mode / Full VPN',
        columns: 2,
        options: <List<String>>[
          <String>['proxy', 'پروکسی محلی'],
          <String>['vpn', 'وی‌پی‌ان کامل'],
        ],
        help: 'در حالت پروکسی فقط یک SOCKS5 محلی باز می‌شود؛ در حالت وی‌پی‌ان کامل همه ترافیک دستگاه داخل تونل می‌رود.',
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsEngine',
        label: 'موتور تونل',
        flag: 'StormDNS / CottenDns',
        columns: 2,
        options: <List<String>>[
          <String>['storm', 'StormDNS'],
          <String>['cotten', 'CottenDns'],
        ],
        help: 'هر دو موتور، تونل را روی درخواست‌های DNS می‌سازند؛ اگر یکی در شبکه شما نتیجه نداد، دیگری را امتحان کنید.',
      ),
      FieldSpec(
        type: 'text',
        key: 'dnsDomain',
        label: 'دامنه سرور',
        flag: 'DOMAINS',
        placeholder: 'tun.example.com',
        help: 'دامنه‌ای که تونل از طریق آن از رزولورها عبور می‌کند. چند دامنه را با کاما جدا کنید.',
      ),
      FieldSpec(
        type: 'text',
        key: 'dnsKey',
        label: 'کلید رمزنگاری',
        flag: 'ENCRYPTION_KEY',
        placeholder: 'master_dns_vpn',
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsEncMethod',
        label: 'روش رمزنگاری داده',
        flag: 'DATA_ENCRYPTION_METHOD',
        columns: 3,
        options: <List<String>>[
          <String>['0', 'بدون رمز'],
          <String>['1', 'XOR'],
          <String>['2', 'ChaCha20'],
          <String>['3', 'AES-128-GCM'],
          <String>['4', 'AES-192-GCM'],
          <String>['5', 'AES-256-GCM'],
        ],
      ),
      FieldSpec(
        type: 'area',
        key: 'dnsResolverText',
        label: 'ری‌زالورها',
        flag: 'resolvers',
        placeholder: '1.2.3.4:53',
        help: 'هر رزولور در یک خط به شکل ip:port. اگر خالی باشد کلاینت خودش جست‌وجو می‌کند.',
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsBalancing',
        label: 'استراتژی توازن بار',
        flag: 'RESOLVER_BALANCING_STRATEGY',
        columns: 2,
        options: <List<String>>[
          <String>['1', 'تصادفی'],
          <String>['2', 'نوبتی'],
          <String>['3', 'کمترین خطا'],
          <String>['4', 'کمترین تأخیر'],
        ],
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsLogLevel',
        label: 'سطح لاگ',
        flag: 'LOG_LEVEL',
        columns: 3,
        options: <List<String>>[
          <String>['DEBUG', 'DEBUG'],
          <String>['INFO', 'INFO'],
          <String>['WARN', 'WARN'],
          <String>['ERROR', 'ERROR'],
        ],
      ),
    ],
  ),
];

/// The "تنظیمات پیشرفته" accordion.
final List<SectionSpec> kAdvancedSections = <SectionSpec>[
  const SectionSpec(
    id: 'local',
    title: 'پروکسی محلی',
    open: true,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'text',
        key: 'bind',
        label: 'آدرس SOCKS5',
        flag: '--bind',
        placeholder: '127.0.0.1:1819',
        help: 'روی 0.0.0.0 فقط وقتی بگذارید که بخواهید تونل را با شبکه به اشتراک بگذارید؛ چیزی کاربران را احراز هویت نمی‌کند.',
      ),
      FieldSpec(
        type: 'sw',
        key: 'httpOn',
        label: 'پروکسی HTTP CONNECT',
        flag: '--http-proxy',
        help: 'برای برنامه‌هایی که SOCKS ندارند.',
      ),
      FieldSpec(
        type: 'text',
        key: 'httpAddr',
        label: 'آدرس پروکسی HTTP',
        flag: '--http-proxy',
        placeholder: '127.0.0.1:1822',
        show: boolHttpOn,
      ),
    ],
  ),
  const SectionSpec(
    id: 'exit',
    title: 'کشور خروجی و پروکسی بالادست',
    fields: <FieldSpec>[
      FieldSpec(
        type: 'text',
        key: 'exitLoc',
        label: 'فیلتر کشور خروجی',
        flag: '--exit-loc',
        placeholder: '!IR,RU یا DE,SE',
        help: 'با ! کشورها را ممنوع کنید، بدون ! فقط همان‌ها مجازند. تا وقتی پر نکنید هیچ بررسی‌ای انجام نمی‌شود.',
      ),
      FieldSpec(
        type: 'num',
        key: 'exitLocSecs',
        label: 'فاصله بررسی مجدد (ثانیه)',
        flag: '--exit-loc-secs',
        placeholder: '60',
        show: boolExitLoc,
      ),
      FieldSpec(
        type: 'text',
        key: 'upstream',
        label: 'پروکسی بالادست',
        flag: '--upstream',
        placeholder: 'socks5://127.0.0.1:1080',
        help: 'همه اتصال‌ها از پشت پروکسی‌ای که از قبل اجرا است می‌روند. HTTP فقط با HTTP/2 کار می‌کند.',
      ),
      FieldSpec(
        type: 'text',
        key: 'mark',
        label: 'Firewall mark',
        flag: '--mark',
        placeholder: '0xff',
        help: 'فقط لینوکس و اندروید و نیازمند دسترسی root.',
      ),
    ],
  ),
  const SectionSpec(
    id: 'routing',
    title: 'قوانین مسیریابی',
    fields: <FieldSpec>[
      FieldSpec(
        type: 'area',
        key: 'routeBlock',
        label: 'مسدود شود',
        flag: '--route-block',
        placeholder: 'ads.example.com, port:25, keyword:doubleclick',
        help: 'اتصال به این مقصدها کاملاً رد می‌شود. هر مورد در یک خط یا با کاما.',
      ),
      FieldSpec(
        type: 'area',
        key: 'routeDirect',
        label: 'مستقیم (بدون تونل)',
        flag: '--route-direct',
        placeholder: 'private, bank.ir',
        help: 'برای بانک‌ها، شبکه محلی و سایت‌های داخلی که آدرس خارجی را نمی‌پذیرند. «private» یعنی شبکه محلی.',
      ),
      FieldSpec(
        type: 'sw',
        key: 'routeSniff',
        label: 'خواندن نام از اولین بایت‌ها',
        flag: 'AETHER_ROUTE_SNIFF',
        help: 'وقتی برنامه فقط آدرس IP می‌دهد، نام را از TLS یا Host می‌خواند تا قوانین نام کار کنند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'routeSniffMs',
        label: 'مهلت خواندن (میلی‌ثانیه)',
        flag: 'AETHER_ROUTE_SNIFF_MS',
        placeholder: '400',
        show: boolRouteSniff,
      ),
    ],
  ),
  SectionSpec(
    id: 'whSplit',
    title: 'تقسیم تونل',
    show: isWhite,
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'seg',
        key: 'whSplit',
        label: 'حالت تقسیم تونل',
        flag: '--split-tunnel',
        columns: 1,
        options: <List<String>>[
          <String>['off', 'خاموش'],
          <String>['bypass', 'برنامه‌های انتخاب‌شده خارج از VPN'],
          <String>['vpnonly', 'فقط برنامه‌های انتخاب‌شده داخل VPN'],
        ],
        helpKey: 'whSplit',
      ),
      FieldSpec(
        type: 'num',
        key: 'whSplitCount',
        label: 'تعداد برنامه‌های انتخاب‌شده',
        flag: '--split-count',
        placeholder: '۰',
        show: (VpnConfig c) => c.textOf('whSplit') != 'off',
      ),
    ],
  ),
  const SectionSpec(
    id: 'whLan',
    title: 'اشتراک‌گذاری در شبکه',
    show: isWhite,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'sw',
        key: 'whShare',
        label: 'اشتراک وی‌پی‌ان در شبکه',
        flag: '--lan-sharing',
        help: 'دستگاه‌های دیگر با پروکسی HTTP یا SOCKS5 از وایت استفاده کنند.',
      ),
      FieldSpec(
        type: 'sw',
        key: 'whPass',
        label: 'نیاز به رمز عبور',
        flag: '--lan-password',
        help: 'دسترسی را با نام کاربری و رمز ساخته‌شده محافظت کنید.',
        show: boolWhShare,
      ),
      FieldSpec(
        type: 'sw',
        key: 'whClean',
        label: 'پاک‌سازی آدرس‌های آلوده',
        flag: '--clean-ip',
        help: 'آدرس‌های مشکوک در فهرست سرورها کنار گذاشته می‌شوند.',
      ),
    ],
  ),
  const SectionSpec(
    id: 'dnsLocal',
    title: 'پروکسی محلی DNS',
    show: isDns,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'text',
        key: 'dnsListenIp',
        label: 'آدرس شنود SOCKS5',
        flag: 'LISTEN_IP',
        placeholder: '127.0.0.1',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsListenPort',
        label: 'پورت پروکسی DNS',
        flag: 'LISTEN_PORT',
        placeholder: '10886',
      ),
      FieldSpec(
        type: 'sw',
        key: 'dnsHttpEnabled',
        label: 'پل HTTP',
        flag: 'HTTP_PROXY_ENABLED',
        help: 'همان‌طور که WhiteDNS انجام می‌دهد، یک پورت HTTP هم باز می‌شود.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsHttpPort',
        label: 'پورت پل HTTP',
        flag: 'HTTP_PROXY_PORT',
        placeholder: '10887',
        show: isDnsHttpOn,
      ),
      FieldSpec(
        type: 'sw',
        key: 'dnsSockAuth',
        label: 'احراز هویت SOCKS5',
        flag: 'SOCKS5_AUTH',
      ),
      FieldSpec(
        type: 'text',
        key: 'dnsSockUser',
        label: 'نام کاربری SOCKS5',
        flag: 'SOCKS5_USER',
        placeholder: 'master_dns_vpn',
        show: isDnsSockAuth,
      ),
      FieldSpec(
        type: 'text',
        key: 'dnsSockPass',
        label: 'رمز عبور SOCKS5',
        flag: 'SOCKS5_PASS',
        placeholder: 'master_dns_vpn',
        show: isDnsSockAuth,
      ),
    ],
  ),
  const SectionSpec(
    id: 'dnsTunnel',
    title: 'عملکرد تونل DNS',
    show: isDns,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'num',
        key: 'dnsDupUp',
        label: 'تکرار بسته ارسال',
        flag: 'UPLOAD_PACKET_DUPLICATION_COUNT',
        placeholder: '3',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsDupDown',
        label: 'تکرار بسته دریافت',
        flag: 'DOWNLOAD_PACKET_DUPLICATION_COUNT',
        placeholder: '7',
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsCompUp',
        label: 'فشرده‌سازی ارسال',
        flag: 'UPLOAD_COMPRESSION_TYPE',
        columns: 2,
        options: <List<String>>[
          <String>['0', 'خاموش'],
          <String>['1', 'ZSTD'],
          <String>['2', 'LZ4'],
          <String>['3', 'ZLIB'],
        ],
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsCompDown',
        label: 'فشرده‌سازی دریافت',
        flag: 'DOWNLOAD_COMPRESSION_TYPE',
        columns: 2,
        options: <List<String>>[
          <String>['0', 'خاموش'],
          <String>['1', 'ZSTD'],
          <String>['2', 'LZ4'],
          <String>['3', 'ZLIB'],
        ],
      ),
      FieldSpec(
        type: 'sw',
        key: 'dnsBaseEncode',
        label: 'BASE64 همه داده‌ها',
        flag: 'BASE_ENCODE_DATA',
        help: 'قابل مطالعه‌کردن داده برای رزولورهایی که کاراکترهای خاص را نگه نمی‌دارند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMinUpMtu',
        label: 'کمترین MTU ارسال',
        flag: 'MIN_UPLOAD_MTU',
        placeholder: '40',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMinDownMtu',
        label: 'کمترین MTU دریافت',
        flag: 'MIN_DOWNLOAD_MTU',
        placeholder: '300',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMaxUpMtu',
        label: 'بیشترین MTU ارسال',
        flag: 'MAX_UPLOAD_MTU',
        placeholder: '140',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMaxDownMtu',
        label: 'بیشترین MTU دریافت',
        flag: 'MAX_DOWNLOAD_MTU',
        placeholder: '3000',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuRetriesResolvers',
        label: 'تلاش اسکن MTU (رزولورها)',
        flag: 'MTU_TEST_RETRIES_RESOLVERS',
        placeholder: '3',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuTimeoutResolvers',
        label: 'مهلت اسکن MTU (رزولورها)',
        flag: 'MTU_TEST_TIMEOUT_RESOLVERS',
        placeholder: '2.5',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuParallelismResolvers',
        label: 'تعداد همزمان اسکن MTU (رزولورها)',
        flag: 'MTU_TEST_PARALLELISM_RESOLVERS',
        placeholder: '100',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuRetriesLogs',
        label: 'تلاش اسکن MTU (لاگ‌ها)',
        flag: 'MTU_TEST_RETRIES_LOGS',
        placeholder: '5',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuTimeoutLogs',
        label: 'مهلت اسکن MTU (لاگ‌ها)',
        flag: 'MTU_TEST_TIMEOUT_LOGS',
        placeholder: '2.5',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMtuParallelismLogs',
        label: 'تعداد همزمان اسکن MTU (لاگ‌ها)',
        flag: 'MTU_TEST_PARALLELISM_LOGS',
        placeholder: '32',
      ),
    ],
  ),
  const SectionSpec(
    id: 'dnsStreams',
    title: 'کارگرها و ظرفیت نشست‌ها',
    show: isDns,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'num',
        key: 'dnsRxTxWorkers',
        label: 'کارگرهای ارسال/دریافت',
        flag: 'RX_TX_WORKERS',
        placeholder: '4',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsTunnelWorkers',
        label: 'کارگرهای تونل',
        flag: 'TUNNEL_PROCESS_WORKERS',
        placeholder: '4',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsPacketTimeout',
        label: 'مهلت بسته تونل (ثانیه)',
        flag: 'TUNNEL_PACKET_TIMEOUT_SECONDS',
        placeholder: '10.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsIdlePoll',
        label: 'فاصله نظرسنجی کارگشا',
        flag: 'DISPATCHER_IDLE_POLL_INTERVAL_SECONDS',
        placeholder: '0.020',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsTxChannel',
        label: 'ظرفیت کانال ارسال',
        flag: 'TX_CHANNEL_SIZE',
        placeholder: '2048',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsRxChannel',
        label: 'ظرفیت کانال دریافت',
        flag: 'RX_CHANNEL_SIZE',
        placeholder: '2048',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsResolverPool',
        label: 'ظرفیت استخر اتصال رزولور',
        flag: 'RESOLVER_UDP_CONNECTION_POOL_SIZE',
        placeholder: '64',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsStreamQueue',
        label: 'ظرفیت صف نشست',
        flag: 'STREAM_QUEUE_INITIAL_CAPACITY',
        placeholder: '128',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsOrphanQueue',
        label: 'ظرفیت صف بسته‌های بی‌سرپرست',
        flag: 'ORPHAN_QUEUE_INITIAL_CAPACITY',
        placeholder: '32',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsFragmentStore',
        label: 'ظرفیت انبار قطعات پاسخ',
        flag: 'DNS_RESPONSE_FRAGMENT_STORE_CAPACITY',
        placeholder: '256',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsMaxStreams',
        label: 'بیشترین نشست فعال',
        flag: 'MAX_ACTIVE_STREAMS',
        placeholder: '2048',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsHandshakeTimeout',
        label: 'مهلت دست‌دهی محلی (ثانیه)',
        flag: 'LOCAL_HANDSHAKE_TIMEOUT_SECONDS',
        placeholder: '5.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsUdpAssociateTimeout',
        label: 'مهلت UDP ASSOCIATE (ثانیه)',
        flag: 'SOCKS_UDP_ASSOCIATE_READ_TIMEOUT_SECONDS',
        placeholder: '30.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsStreamRetention',
        label: 'ماندگاری نشست بسته شده (ثانیه)',
        flag: 'CLIENT_TERMINAL_STREAM_RETENTION_SECONDS',
        placeholder: '45.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsCancelledRetention',
        label: 'ماندگاری راه‌اندازی لغوشده (ثانیه)',
        flag: 'CLIENT_CANCELLED_SETUP_RETENTION_SECONDS',
        placeholder: '120.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsRetryBase',
        label: 'تأخیر تلاش راه‌اندازی (شروع)',
        flag: 'SESSION_INIT_RETRY_BASE_SECONDS',
        placeholder: '1.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsRetryStep',
        label: 'گام تأخیر تلاش راه‌اندازی',
        flag: 'SESSION_INIT_RETRY_STEP_SECONDS',
        placeholder: '1.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsRetryLinearAfter',
        label: 'خطی‌شدن تأخیر پس از این تلاش',
        flag: 'SESSION_INIT_RETRY_LINEAR_AFTER',
        placeholder: '5',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsRetryMax',
        label: 'بیشترین تأخیر تلاش راه‌اندازی (ثانیه)',
        flag: 'SESSION_INIT_RETRY_MAX_SECONDS',
        placeholder: '60.0',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsBusyRetry',
        label: 'فاصله راه‌اندازی در حالت اشغال (ثانیه)',
        flag: 'SESSION_INIT_BUSY_RETRY_INTERVAL_SECONDS',
        placeholder: '60.0',
      ),
    ],
  ),
  const SectionSpec(
    id: 'dnsLife',
    title: 'شروع و نظارت DNS',
    show: isDns,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'sw',
        key: 'dnsLocalDns',
        label: 'DNS محلی',
        flag: 'LOCAL_DNS_ENABLED',
        help: 'یک گرداننده DNS روی دستگاه هم باز می‌شود؛ برای نرم‌افزارهایی که نمی‌توانند پروکسی گرفته شوند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsLocalDnsPort',
        label: 'پورت DNS محلی',
        flag: 'LOCAL_DNS_PORT',
        placeholder: '53',
        show: isDnsLocalDns,
      ),
      FieldSpec(
        type: 'seg',
        key: 'dnsStartupMode',
        label: 'حالت شروع',
        flag: 'STARTUP_MODE',
        columns: 3,
        options: <List<String>>[
          <String>['ask', 'پرسش در هر بار'],
          <String>['resolvers', 'اسکن کامل'],
          <String>['logs', 'از لاگ (سریع)'],
        ],
        help: 'چطور آخرین رزولورهای سالم یادآوری می‌شوند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsWatchdog',
        label: 'نگهبان پینگ (ثانیه)',
        flag: 'PING_WATCHDOG_TIMEOUT_SECONDS',
        placeholder: '300',
        help: 'اگر پینگ از این حد گذشت، تونل از سر گرفته می‌شود.',
      ),
      FieldSpec(
        type: 'sw',
        key: 'dnsWarmup',
        label: 'گرم‌کردن ترافیک',
        flag: 'TRAFFIC_WARMUP_ENABLED',
        help: 'چند درخواست واقعی قبل از اعلام اتصال داده می‌شود تا بازرسی مسیر را گول بزند.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsWarmupProbes',
        label: 'تعداد درخواست گرم‌کردن',
        flag: 'TRAFFIC_WARMUP_PROBE_COUNT',
        placeholder: '4',
        show: isDnsWarmup,
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsKeepalive',
        label: 'فاصله keepalive ترافیک (ثانیه)',
        flag: 'TRAFFIC_KEEPALIVE_INTERVAL_SECONDS',
        placeholder: '5',
      ),
      FieldSpec(
        type: 'sw',
        key: 'dnsAutoTune',
        label: 'تنظیم خودکار (AutoTune)',
        flag: 'AUTO_TUNE_ENABLED',
        help: 'چند پیکربندی موازی امتحان می‌شود و بهترین خودکار نگه داشته می‌شود.',
      ),
    ],
  ),
  const SectionSpec(
    id: 'dnsSplit',
    title: 'تقسیم تونل DNS',
    show: isDns,
    fields: <FieldSpec>[
      FieldSpec(
        type: 'seg',
        key: 'dnsSplit',
        label: 'به کدام برنامه‌ها اتصال برسد',
        flag: 'SPLIT_TUNNEL_MODE',
        columns: 3,
        options: <List<String>>[
          <String>['off', 'همه برنامه‌ها'],
          <String>['include', 'تنها انتخاب‌شده‌ها'],
          <String>['exclude', 'برنامه‌های مستثنا'],
        ],
        show: isDnsVpnMode,
        help: 'فقط در حالت وی‌پی‌ان کامل کار می‌کند؛ حالت انتخاب‌شده‌ها و مستثناها در حالت پروکسی محلی معنا ندارد.',
      ),
      FieldSpec(
        type: 'num',
        key: 'dnsSplitCount',
        label: 'تعداد برنامه‌های انتخاب‌شده',
        flag: 'SPLIT_TUNNEL_COUNT',
        placeholder: '0',
        show: isDnsSplitOn,
      ),
    ],
  ),
  SectionSpec(
    id: 'zt',
    title: 'Zero Trust (WARP برای سازمان‌ها)',
    show: usesWarp,
    fields: <FieldSpec>[
      const FieldSpec(
        type: 'text',
        key: 'team',
        label: 'نام تیم',
        flag: '--team',
        placeholder: 'acme',
        help: 'به‌جای دستگاه ناشناس، دستگاه مدیریت‌شده سازمان می‌شوید.',
      ),
      const FieldSpec(
        type: 'seg',
        key: 'ztMethod',
        label: 'روش ورود',
        flag: '',
        columns: 3,
        options: <List<String>>[
          <String>['email', 'کد ایمیل'],
          <String>['token', 'توکن سرویس'],
          <String>['jwt', 'توکن موجود'],
        ],
        show: boolTeam,
      ),
      FieldSpec(
        type: 'text',
        key: 'ztEmail',
        label: 'ایمیل',
        flag: '--access-email',
        placeholder: 'me@example.com',
        help: 'کلادفلر یک کد یک‌بارمصرف می‌فرستد؛ سه بار فرصت دارید.',
        show: (VpnConfig c) => boolTeam(c) && c.textOf('ztMethod') == 'email',
      ),
      FieldSpec(
        type: 'text',
        key: 'ztId',
        label: 'شناسه سرویس',
        flag: '--access-id',
        show: (VpnConfig c) => boolTeam(c) && c.textOf('ztMethod') == 'token',
      ),
      FieldSpec(
        type: 'text',
        key: 'ztSecret',
        label: 'رمز سرویس',
        flag: '--access-secret',
        show: (VpnConfig c) => boolTeam(c) && c.textOf('ztMethod') == 'token',
      ),
      FieldSpec(
        type: 'area',
        key: 'ztJwt',
        label: 'توکن',
        flag: '--access-token',
        placeholder: 'eyJ…',
        show: (VpnConfig c) => boolTeam(c) && c.textOf('ztMethod') == 'jwt',
      ),
      const FieldSpec(
        type: 'sw',
        key: 'gateway',
        label: 'عبور HTTP از Gateway سازمان',
        flag: '--gateway',
        help: 'فیلتر و ثبت سازمان اعمال می‌شود و مرورتان ثبت می‌شود. پیش‌فرض خاموش است.',
        show: boolTeam,
      ),
    ],
  ),
  const SectionSpec(
    id: 'limits',
    title: 'محدودیت‌ها و عملکرد',
    fields: <FieldSpec>[
      FieldSpec(
        type: 'seg',
        key: 'perf',
        label: 'پروفایل عملکرد',
        flag: 'AETHER_PERF_PROFILE',
        columns: 3,
        options: <List<String>>[
          <String>['low', 'کم'],
          <String>['medium', 'متوسط'],
          <String>['high', 'زیاد'],
        ],
      ),
      FieldSpec(
        type: 'num',
        key: 'maxClients',
        label: 'حداکثر کلاینت همزمان',
        flag: 'AETHER_MAX_CLIENTS',
        placeholder: 'خودکار (۵۱۲ تا ۸۱۹۲)',
      ),
      FieldSpec(
        type: 'num',
        key: 'halfClose',
        label: 'مهلت اتصال نیمه‌بسته (ثانیه)',
        flag: 'AETHER_HALF_CLOSE_SECS',
        placeholder: '30',
      ),
      FieldSpec(
        type: 'num',
        key: 'tcpKeepalive',
        label: 'Keepalive شبکه (ثانیه)',
        flag: 'AETHER_TCP_KEEPALIVE_SECS',
        placeholder: '60',
      ),
      FieldSpec(
        type: 'num',
        key: 'tcpConnect',
        label: 'مهلت باز شدن اتصال (ثانیه)',
        flag: 'AETHER_TCP_CONNECT_SECS',
        placeholder: '30',
      ),
    ],
  ),
  const SectionSpec(
    id: 'misc',
    title: 'آمار و هویت دستگاه',
    fields: <FieldSpec>[
      FieldSpec(
        type: 'sw',
        key: 'stats',
        label: 'نمایش آمار مصرف',
        flag: '--stats',
        help: 'تأخیر و حجم دریافت و ارسال روی صفحه خانه.',
      ),
      FieldSpec(
        type: 'num',
        key: 'statsSecs',
        label: 'فاصله به‌روزرسانی آمار (ثانیه)',
        flag: '--stats-secs',
        placeholder: '60',
        show: boolStats,
      ),
      FieldSpec(
        type: 'sw',
        key: 'reprovision',
        label: 'جایگزینی خودکار هویت رد‌شده',
        flag: 'AETHER_REPROVISION',
        help: 'اگر کلادفلر دستگاه ذخیره‌شده را نپذیرد، دستگاه تازه ثبت می‌شود.',
      ),
    ],
  ),
];

/// Predicates that are easier to read as named functions than as closures
/// inside a `const` list.
bool boolHttpOn(VpnConfig c) => c.boolOf('httpOn');
bool boolExitLoc(VpnConfig c) => c.textOf('exitLoc').trim().isNotEmpty;
bool boolRouteSniff(VpnConfig c) => c.boolOf('routeSniff');
bool boolWhShare(VpnConfig c) => c.boolOf('whShare');
bool boolTeam(VpnConfig c) => c.textOf('team').trim().isNotEmpty;
bool boolStats(VpnConfig c) => c.boolOf('stats');
