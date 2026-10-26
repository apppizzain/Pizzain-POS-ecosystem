(function () {
  "use strict";

  const SUPABASE_URL = "https://veifszvxdfkzpcxhbqlu.supabase.co";
  const SUPABASE_ANON_KEY = "sb_publishable_sFeKaDZ84lUC5YAaMlUzKA_bYdfxf4o";
  const SUPABASE_JS_CDN = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";

  const loadedScripts = new Map();

  function loadScriptOnce(id, src) {
    if (loadedScripts.has(id)) return loadedScripts.get(id);
    const existing = document.getElementById(id);
    if (existing?.dataset.loaded === "1") return Promise.resolve(existing);
    const script = existing || document.createElement("script");
    script.id = id;
    script.src = src;
    script.async = true;
    const promise = new Promise((resolve, reject) => {
      script.addEventListener("load", () => {
        script.dataset.loaded = "1";
        resolve(script);
      }, { once: true });
      script.addEventListener("error", () => reject(new Error(`Gagal memuat ${src}`)), { once: true });
    });
    if (!existing) document.head.appendChild(script);
    loadedScripts.set(id, promise);
    return promise;
  }

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, char => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    }[char]));
  }

  function money(value) {
    return `Rp${Number(value || 0).toLocaleString("id-ID")}`;
  }

  function cleanPhone(value) {
    let phone = String(value || "").replace(/[^0-9]/g, "");
    if (phone.startsWith("0")) phone = `62${phone.slice(1)}`;
    return phone;
  }

  function shortDateTime(value) {
    const date = new Date(value || "");
    if (Number.isNaN(date.getTime())) return "-";
    return date.toLocaleString("id-ID", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  const DriverSupabase = {
    client: null,
    loading: null,
    async ready() {
      if (this.client) return this.client;
      if (!this.loading) {
        this.loading = loadScriptOnce("supabase-js-cdn", SUPABASE_JS_CDN).then(async () => {
          if (!window.supabase?.createClient) throw new Error("Library Supabase belum siap.");
          this.client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            auth: { persistSession: true, autoRefreshToken: true }
          });
          const { data } = await this.client.from("store_settings")
            .select("store_name,delivery:self_order_settings->delivery")
            .eq("id", "bed47e3f-cb3b-472b-b697-7c1fb31e5257")
            .maybeSingle();
          if (data) {
            window.DriverAppConfig.storeName = data.store_name;
            window.DriverAppConfig.storeLatitude = data.delivery?.latitude ?? window.DriverAppConfig.storeLatitude;
            window.DriverAppConfig.storeLongitude = data.delivery?.longitude ?? window.DriverAppConfig.storeLongitude;
          }
          return this.client;
        });
      }
      return this.loading;
    }
  };

  window.DriverAppConfig = {
    supabaseUrl: SUPABASE_URL,
    supabaseAnonKey: SUPABASE_ANON_KEY,
    refreshMs: 15000,
    storeLatitude: window.DELIVERY_STORE_LATITUDE ?? null,
    storeLongitude: window.DELIVERY_STORE_LONGITUDE ?? null
  };
  window.DriverUtils = { escapeHtml, money, cleanPhone, shortDateTime };
  window.DriverSupabase = DriverSupabase;
}());
