/// Help lines for the values a segmented control can take, keyed by
/// `<configKey>.<value>` so a field can look its own help up by key alone.
///
/// Every string here is Persian source text; the translator carries it to the
/// other five languages exactly the way it carries a label.
const Map<String, String> kHelp = <String, String>{
  'engine.aether': 'کلاینت WARP کلادفلر؛ پیش‌فرض و معمولاً سریع‌ترین.',
  'engine.psiphon': 'ابزار عبور از فیلتر با روش‌های پوشش خودش، از جمله CDN.',
  'engine.tor': 'شبکه Tor؛ کندتر است ولی خروجی و مسیر کاملاً متفاوتی می‌دهد.',
  'engine.white': 'وایت؛ هسته Mihomo با سابسکریپشن داخلی یا لینک خودتان.',
  'engine.s4': 'حالت S4 ساخت SOFT400؛ تونل امن با آیکون رسمی S4VPN.',

  'transport.masque':
      'مدرن‌ترین حالت؛ ترافیک شبیه وب معمولی است. اگر مطمئن نیستید از اینجا شروع کنید.',
  'transport.wg': 'سبک و سریع؛ مناسب شبکه‌هایی که فقط آدرس‌های شناخته‌شده را می‌بندند.',
  'transport.gool': 'دو تونل WireGuard تو در تو؛ کندتر است ولی وقتی یک لایه کافی نیست کمک می‌کند.',
  'transport.mim': 'دو تونل MASQUE تو در تو؛ آدرس خروجی شما را عوض می‌کند.',

  'scan.turbo': 'سریع؛ به اولین آدرسی که جواب بدهد راضی می‌شود.',
  'scan.balanced': 'پیش‌فرض؛ چند آدرس جمع می‌کند و سریع‌ترین را نگه می‌دارد.',
  'scan.thorough': 'کل بازه‌ها را می‌گردد؛ وقتی همه‌چیز بسته به نظر می‌رسد.',
  'scan.stealth': 'آرام و صبور؛ برای شبکه‌هایی که اسکن را تشخیص می‌دهند.',
  'scan.verified':
      'فقط آدرس‌هایی که جواب‌دادنشان اندازه‌گیری شده. روی gool و mim دو هاپ را در بازه‌های جدا نگه می‌دارد.',
  'scan.ironclad':
      'کندترین ولی مطمئن‌ترین؛ برای هر آدرس یک تونل و یک درخواست HTTP واقعی می‌سازد.',

  'noize.off': 'بدون استتار؛ فقط برای شبکه باز یا آزمایش.',
  'noize.light': 'حداقل استتار با کمترین سربار.',
  'noize.firewall': 'پیش‌فرض MASQUE؛ متعادل و پیشنهادی برای ایران.',
  'noize.balanced': 'پیش‌فرض WireGuard و Gool؛ نقطه تعادل سرعت و پنهان‌کاری.',
  'noize.gfw': 'سنگین‌تر؛ وقتی firewall جواب نداد.',
  'noize.aggressive': 'سنگین‌ترین؛ وقتی دست‌دهی شناسایی می‌شود.',

  'psWay.only': 'بدون WARP؛ پروکسی همان Psiphon ساده است.',
  'psWay.chain':
      'ترافیک اول از WARP و بعد از Psiphon می‌گذرد. شبکه شما Psiphon را نمی‌بیند و خروجی، Psiphon است.',
  'psWay.reverse':
      'ترافیک اول از Psiphon و بعد از WARP می‌گذرد. شبکه شما WARP را نمی‌بیند.',

  'psShape.auto': 'Psiphon خودش بهترین را انتخاب می‌کند.',
  'psShape.cdn': 'فقط meek پشت CDN؛ برای شبکه‌هایی که بقیه روش‌ها را می‌بندند.',
  'psShape.direct': 'بدون پوشش CDN.',

  'torWay.only': 'بدون WARP؛ پروکسی همان Tor ساده است.',
  'torWay.chain':
      'ترافیک اول از WARP و بعد از Tor می‌گذرد. شبکه‌ای که Tor را مسدود کرده آن را نمی‌بیند.',
  'torWay.reverse':
      'ترافیک اول از Tor و بعد از WARP می‌گذرد. شبکه شما WARP را نمی‌بیند. فقط MASQUE روی HTTP/2 و Tor باید از قبل در دسترس باشد.',

  'torBridges.auto':
      'ابتدا مستقیم امتحان می‌کند؛ اگر نشد از BridgeDB پل می‌گیرد (obfs4، سپس webtunnel، سپس snowflake).',
  'torBridges.force': 'بدون امتحان مستقیم، یکراست سراغ پل‌ها می‌رود.',
  'torBridges.never': 'هرگز از پل استفاده نمی‌کند، حتی اگر شبکه بسته باشد.',
  'torBridges.custom': 'پل‌های خودتان را جایگزین پل‌های دریافتی می‌کنید.',

  'torRelays.auto': 'رله‌های Onionoo کنار BridgeDB به‌عنوان پل ساده استفاده می‌شوند.',
  'torRelays.only': 'فقط رله‌های Onionoo؛ استخر بسیار بزرگ‌تری از BridgeDB است.',
  'torRelays.off': 'رله‌ها استفاده نمی‌شوند.',

  'whSub.builtin': 'سابسکریپشن‌های داخلی وایت؛ بدون نیاز به لینک، همیشه به‌روز.',
  'whSub.personal': 'لینک سابسکریپشن خودتان؛ YAML، JSON یا فهرست لینک پروکسی.',

  'whServerPick.auto': 'هر بار سریع‌ترین سرور تست‌شده انتخاب می‌شود.',
  'whServerPick.manual': 'یک سرور مشخص از فهرست انتخاب می‌کنید.',

  'whChain.direct': 'ترافیک مستقیم به سرور انتخابی می‌رود.',
  'whChain.warp': 'اول از WARP و بعد به سرور؛ وقتی سرور مستقیم بسته است.',

  'whRoute.sub': 'قوانین داخل سابسکریپشن فعال استفاده می‌شود.',
  'whRoute.iran': 'فقط سایت‌های ایرانی از مسیر ایران رد می‌شوند؛ بقیه از وایت.',
  'whRoute.global': 'همه ترافیک از پروکسی رد می‌شود.',

  'whDns.auto': 'پیکربندی خودکار بر اساس سابسکریپشن.',
  'whDns.doh': 'DNS رمزنگاری‌شده روی HTTPS.',
  'whDns.dot': 'DNS رمزنگاری‌شده روی TLS.',
  'whDns.doq': 'DNS رمزنگاری‌شده روی QUIC؛ سریع‌ترین حالت روی شبکه‌هایی که UDP را باز نگه می‌دارند.',

  'whNoise.off': 'بدون بسته اضافه؛ سربار صفر.',
  'whNoise.light': 'حداقل بسته‌های نویز برای گمراه‌کردن DPI.',
  'whNoise.full': 'بسته‌های کامل نویز و بسته‌های گمراه‌کننده DPI.',

  'whSplit.off': 'همه برنامه‌ها از VPN رد می‌شوند.',
  'whSplit.bypass': 'برنامه‌های انتخاب‌شده بدون VPN کار می‌کنند.',
  'whSplit.vpnonly': 'فقط برنامه‌های انتخاب‌شده از VPN رد می‌شوند.',
};
