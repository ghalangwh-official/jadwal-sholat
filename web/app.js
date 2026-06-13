(function () {
  const API = {
    cityList: "../list_kota.json",
    localSchedule: "../jadwal_sholat.json",
    localRandomQuran: "../random_quran.json",
    selectedCity: "../.selected_id.dat",
    jadwal: "https://api.myquran.com/v2/sholat/jadwal",
    citySearch: "https://api.myquran.com/v3/sholat/kabkota/cari",
    quranIndex: "https://api.myquran.com/v3/quran",
    quranSearch: "https://api.myquran.com/v3/quran/search",
    quranAyat: (surah, ayah) => `https://api.myquran.com/v3/quran/${surah}/${ayah}`,
    quranSurah: (surah) => `https://api.myquran.com/v3/quran/${surah}`,
    quranRandom: "https://api.myquran.com/v3/quran/random",
    murotal: (surah) => `https://quran-api.santrikoding.com/api/surah/${surah}`,
  };

  const STORE = {
    lastCityId: "jadwal:lastCityId",
    lastCityName: "jadwal:lastCityName",
    lastDate: "jadwal:lastDate",
    quranCache: "jadwal:quranCache",
    murotalCache: "jadwal:murotalCache",
  };

  const el = {
    connectionPill: document.getElementById("connectionPill"),
    hijriPill: document.getElementById("hijriPill"),
    cityPill: document.getElementById("cityPill"),
    reloadLocalBtn: document.getElementById("reloadLocalBtn"),
    reloadOnlineBtn: document.getElementById("reloadOnlineBtn"),
    cityQuery: document.getElementById("cityQuery"),
    cityId: document.getElementById("cityId"),
    scheduleDate: document.getElementById("scheduleDate"),
    clockNow: document.getElementById("clockNow"),
    cityResults: document.getElementById("cityResults"),
    scheduleLocation: document.getElementById("scheduleLocation"),
    scheduleDateLabel: document.getElementById("scheduleDateLabel"),
    nextPrayer: document.getElementById("nextPrayer"),
    scheduleGrid: document.getElementById("scheduleGrid"),
    scheduleSource: document.getElementById("scheduleSource"),
    surahInput: document.getElementById("surahInput"),
    loadMurotalBtn: document.getElementById("loadMurotalBtn"),
    murotalTitle: document.getElementById("murotalTitle"),
    murotalMeta: document.getElementById("murotalMeta"),
    murotalAudio: document.getElementById("murotalAudio"),
    cachePreview: document.getElementById("cachePreview"),
    mushafPrevBtn: document.getElementById("mushafPrevBtn"),
    mushafNextBtn: document.getElementById("mushafNextBtn"),
    mushafLoadBtn: document.getElementById("mushafLoadBtn"),
    mushafSurahInput: document.getElementById("mushafSurahInput"),
    mushafIndex: document.getElementById("mushafIndex"),
    mushafTitle: document.getElementById("mushafTitle"),
    mushafMeta: document.getElementById("mushafMeta"),
    mushafAudioShell: document.getElementById("mushafAudioShell"),
    mushafAudio: document.getElementById("mushafAudio"),
    mushafVerses: document.getElementById("mushafVerses"),
    mushafPlayBtn: document.getElementById("mushafPlayBtn"),
    mushafCacheBtn: document.getElementById("mushafCacheBtn"),
    mushafAudioToggleBtn: document.getElementById("mushafAudioToggleBtn"),
    mushafSearchInput: document.getElementById("mushafSearchInput"),
    mushafDescription: document.getElementById("mushafDescription"),
    mushafIndexCount: document.getElementById("mushafIndexCount"),
    mushafQuicklinks: document.getElementById("mushafQuicklinks"),
  };

  const state = {
    cityList: [],
    currentSchedule: null,
    currentCity: null,
    currentMurotal: null,
    currentMushaf: null,
    mushafCache: readJsonValue("jadwal:mushafCache", {}),
    mushafPlaying: false,
    mushafPlaybackKind: "surah",
    mushafPlayingIndex: null,
    mushafSurahAudioUrl: "",
    mushafIndex: [],
  };

  function nowDate() {
    return new Date();
  }

  function toYmd(date) {
    return date.toISOString().slice(0, 10);
  }

  function readJsonValue(key, fallback = null) {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch {
      return fallback;
    }
  }

  function writeJsonValue(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // ignore storage quota / private mode errors
    }
  }

  function text(value) {
    return value == null ? "" : String(value);
  }

  function escapeHtml(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function setConnectionBadge() {
    const online = navigator.onLine;
    el.connectionPill.textContent = online ? "Online ✓" : "Offline • cache lokal";
    el.connectionPill.style.borderColor = online ? "rgba(111, 224, 176, 0.3)" : "rgba(255, 141, 141, 0.3)";
    el.connectionPill.style.color = online ? "var(--accent)" : "var(--danger)";
  }

  function setClock() {
    const date = nowDate();
    el.clockNow.value = new Intl.DateTimeFormat("id-ID", {
      dateStyle: "full",
      timeStyle: "short",
    }).format(date);

    try {
      const hijri = new Intl.DateTimeFormat("id-ID-u-ca-islamic-nu-latn", {
        dateStyle: "full",
      }).format(date);
      el.hijriPill.textContent = `Hijriyah: ${hijri}`;
    } catch {
      el.hijriPill.textContent = "Hijriyah: tidak didukung browser ini";
    }
  }

  function formatMinutes(total) {
    const hours = Math.floor(total / 60);
    const mins = total % 60;
    return `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
  }

  function computeNextPrayer(schedule) {
    if (!schedule || !schedule.data || !schedule.data.jadwal) {
      return "-";
    }
    const prayers = ["subuh", "dzuhur", "ashar", "maghrib", "isya"];
    const now = nowDate();
    const current = now.getHours() * 60 + now.getMinutes();
    let best = null;

    for (const prayer of prayers) {
      const value = schedule.data.jadwal[prayer];
      if (!value) continue;
      const [h, m] = value.split(":").map(Number);
      const minutes = h * 60 + m;
      if (minutes >= current) {
        const diff = minutes - current;
        if (!best || diff < best.diff) {
          best = { prayer, time: value, diff };
        }
      }
    }

    if (!best) {
      return "Semua waktu utama hari ini lewat";
    }
    return `${best.prayer} (${best.time}) dalam ${best.diff} menit`;
  }

  function normalizeSchedule(payload) {
    if (!payload || payload.status !== true || !payload.data || !payload.data.jadwal) {
      throw new Error("Format jadwal tidak valid");
    }
    return payload;
  }

  function showLoading(container, message = "Memuat...") {
    if (!container) return;
    container.innerHTML = `<div class="loading-pulse">${escapeHtml(message)}</div>`;
  }

  function renderSchedule(schedule, sourceLabel = "lokal") {
    state.currentSchedule = schedule;
    const data = schedule.data;
    const hijriMode = new Intl.DateTimeFormat("id-ID-u-ca-islamic-nu-latn", { dateStyle: "full" });

    el.scheduleLocation.textContent = `${text(data.daerah)}, ${text(data.lokasi)}`;
    el.scheduleDateLabel.textContent = `${text(schedule.request?.path?.split("/").at(-1) || schedule.info?.date || toYmd(nowDate()))} • ${sourceLabel}`;
    el.nextPrayer.textContent = computeNextPrayer(schedule);
    el.scheduleSource.textContent = sourceLabel === "online" ? "API online" : "Cache lokal";
    el.cityPill.textContent = `Kota: ${text(data.lokasi)} (${text(data.id)})`;
    try {
      el.hijriPill.textContent = `Hijriyah: ${hijriMode.format(nowDate())}`;
    } catch {
      // keep previous text
    }

    const times = data.jadwal || {};
    const prayers = [
      ["Imsak", times.imsak],
      ["Subuh", times.subuh],
      ["Terbit", times.terbit],
      ["Dhuha", times.dhuha],
      ["Dzuhur", times.dzuhur],
      ["Ashar", times.ashar],
      ["Maghrib", times.maghrib],
      ["Isya", times.isya],
    ];

    const nowMinutes = nowDate().getHours() * 60 + nowDate().getMinutes();
    const nextPrayerText = el.nextPrayer.textContent.toLowerCase();

    el.scheduleGrid.innerHTML = prayers
      .map(([name, time]) => {
        let classes = "prayer-chip";
        if (time) {
          const [h, m] = time.split(":").map(Number);
          const minutes = h * 60 + m;
          if (minutes <= nowMinutes) {
            classes += " active";
          }
          if (nextPrayerText.includes(name.toLowerCase())) {
            classes += " next";
          }
        }

        return `
          <div class="${classes}">
            <div class="name">${name}</div>
            <div class="time">${time || "-"}</div>
          </div>
        `;
      })
      .join("");
  }

  async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
      headers: options.headers || {},
      ...options,
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} untuk ${url}`);
    }
    return response.json();
  }

  async function fetchText(url) {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} untuk ${url}`);
    }
    return response.text();
  }

  async function loadLocalSchedule() {
    const savedCityId = readJsonValue(STORE.lastCityId);
    const savedCityName = readJsonValue(STORE.lastCityName);

    try {
      const schedule = normalizeSchedule(await fetchJson(API.localSchedule));
      renderSchedule(schedule, "lokal");
      if (savedCityId) {
        el.cityId.value = savedCityId;
        if (savedCityName) {
          el.cityQuery.value = savedCityName;
        }
      } else {
        el.cityId.value = text(schedule.data.id || "");
        el.cityQuery.value = text(schedule.data.lokasi || "");
      }
    } catch (error) {
      el.scheduleLocation.textContent = "Jadwal lokal belum siap";
      el.scheduleDateLabel.textContent = "Gunakan refresh online untuk memuat jadwal";
      el.nextPrayer.textContent = "-";
      el.scheduleGrid.innerHTML = `<div class="result-card">Cache jadwal lokal belum valid: ${escapeHtml(text(error.message))}</div>`;
      try {
        const cityId = (await fetchText(API.selectedCity)).trim();
        if (cityId) {
          el.cityId.value = cityId;
        }
      } catch {
        // ignore missing selected city file
      }
      if (!el.cityQuery.value) {
        el.cityQuery.value = savedCityName || "";
      }
    }

    if (!el.scheduleDate.value) {
      el.scheduleDate.value = readJsonValue(STORE.lastDate) || toYmd(nowDate());
    }
  }

  async function loadLocalCacheExtras() {
    try {
      const cachedRandom = await fetchJson(API.localRandomQuran);
      if (!readJsonValue(STORE.quranCache)) {
        writeJsonValue(STORE.quranCache, cachedRandom);
      }
    } catch {
      // ignore if cache file missing
    }
    renderCachePreview();
  }

  async function loadMushafIndex() {
    try {
      const payload = await fetchJson(API.quranIndex);
      state.mushafIndex = Array.isArray(payload?.data) ? payload.data : [];
      el.mushafIndexCount.textContent = `${state.mushafIndex.length} surah`;
      renderMushafQuicklinks();
      renderMushafIndex(Number(el.mushafSurahInput.value || 1));
    } catch {
      state.mushafIndex = Array.from({ length: 114 }, (_, i) => ({
        number: i + 1,
        name_latin: `Surah ${i + 1}`,
        translation: "",
        number_of_ayahs: "",
      }));
      el.mushafIndexCount.textContent = "114 surah";
      renderMushafQuicklinks();
      renderMushafIndex(Number(el.mushafSurahInput.value || 1));
    }
  }

  function renderMushafQuicklinks() {
    const picks = [1, 18, 36, 55, 67, 78, 112, 114];
    const items = picks
      .map((number) => state.mushafIndex.find((item) => Number(item.number) === number))
      .filter(Boolean);

    el.mushafQuicklinks.innerHTML = items
      .map(
        (item) => `
          <button class="quicklink-chip" data-mushaf-number="${item.number}">${escapeHtml(text(item.name_latin))}</button>
        `
      )
      .join("");

    el.mushafQuicklinks.querySelectorAll("button[data-mushaf-number]").forEach((button) => {
      button.addEventListener("click", () => {
        const number = Number(button.getAttribute("data-mushaf-number"));
        el.mushafSurahInput.value = String(number);
        loadMushafSurah(number);
      });
    });
  }

  function syncMushafPlaybackUi() {
    if (!el.mushafPlayBtn || !el.mushafAudio) return;

    const playing = Boolean(el.mushafAudio.src) && !el.mushafAudio.paused && !el.mushafAudio.ended;
    const isSurahSource = Boolean(state.mushafSurahAudioUrl) && el.mushafAudio.src === state.mushafSurahAudioUrl;
    const label = playing && isSurahSource ? "Pause surah" : "Play surah";

    el.mushafPlayBtn.textContent = label;
    el.mushafPlayBtn.disabled = !state.mushafSurahAudioUrl;

    el.mushafVerses.querySelectorAll(".ayah-card").forEach((card) => {
      const index = Number(card.getAttribute("data-ayah-index"));
      const button = card.querySelector("button[data-ayah-play]");
      const isActive = playing && state.mushafPlaybackKind === "ayah" && state.mushafPlayingIndex === index;
      card.classList.toggle("playing", isActive);
      if (button) {
        button.textContent = isActive ? "Pause ayat" : "Play ayat";
      }
    });
  }

  function renderCachePreview() {
    const mushafCache = readMushafCache();
    const preview = {
      city: {
        id: readJsonValue(STORE.lastCityId),
        name: readJsonValue(STORE.lastCityName),
        date: readJsonValue(STORE.lastDate),
      },
      quranCache: readJsonValue(STORE.quranCache),
      murotalCache: readJsonValue(STORE.murotalCache),
      mushafCache: {
        last: mushafCache.last || null,
        cachedSurahs: Object.keys(mushafCache.items || {}).slice(0, 8),
      },
    };
    el.cachePreview.textContent = JSON.stringify(preview, null, 2);
  }

  async function loadCityList() {
    try {
      const payload = await fetchJson(API.cityList);
      state.cityList = Array.isArray(payload?.data) ? payload.data : [];
    } catch (error) {
      state.cityList = [];
      el.cityResults.innerHTML = `<div class="result-card">Gagal memuat daftar kota lokal: ${text(error.message)}</div>`;
    }
  }

  function renderCityResults(keyword) {
    const query = keyword.trim().toLowerCase();
    const matches = state.cityList
      .filter((item) => {
        const lokasi = text(item.lokasi).toLowerCase();
        const id = text(item.id).toLowerCase();
        return !query || lokasi.includes(query) || id.includes(query);
      })
      .slice(0, 12);

    if (!matches.length) {
      el.cityResults.innerHTML = `<div class="result-card">Tidak ada kota yang cocok.</div>`;
      return;
    }

    el.cityResults.innerHTML = matches
      .map(
        (item) => `
        <div class="result-card">
          <div class="result-head">
            <div class="result-title">${escapeHtml(text(item.lokasi))}</div>
            <div class="muted">${escapeHtml(text(item.id))}</div>
          </div>
          <button class="ghost" data-city-id="${escapeHtml(text(item.id))}" data-city-name="${escapeHtml(text(item.lokasi))}">Pilih kota ini</button>
        </div>
      `
      )
      .join("");

    el.cityResults.querySelectorAll("button[data-city-id]").forEach((button) => {
      button.addEventListener("click", () => {
        const cityId = button.getAttribute("data-city-id");
        const cityName = button.getAttribute("data-city-name");
        el.cityId.value = cityId;
        el.cityQuery.value = cityName;
        writeJsonValue(STORE.lastCityId, cityId);
        writeJsonValue(STORE.lastCityName, cityName);
        renderCachePreview();
      });
    });
  }

  async function refreshOnlineSchedule() {
    const cityId = el.cityId.value.trim();
    const date = el.scheduleDate.value || toYmd(nowDate());
    if (!cityId) {
      throw new Error("Pilih kota dulu");
    }
    showLoading(el.scheduleGrid, "Memuat jadwal online...");
    const schedule = normalizeSchedule(await fetchJson(`${API.jadwal}/${encodeURIComponent(cityId)}/${date}`));
    renderSchedule(schedule, "online");
    writeJsonValue(STORE.lastCityId, cityId);
    writeJsonValue(STORE.lastCityName, schedule.data.lokasi || el.cityQuery.value.trim());
    writeJsonValue(STORE.lastDate, date);
    renderCachePreview();
  }

  async function loadMurotal(surahNumber) {
    const n = Number(surahNumber);
    if (!Number.isInteger(n) || n < 1 || n > 114) {
      throw new Error("Nomor surah harus 1-114");
    }
    showLoading(el.murotalMeta.parentElement?.querySelector(".detail-card") || el.murotalMeta, "Memuat murotal...");
    const payload = await fetchJson(API.murotal(n));
    const data = payload?.data || payload;
    state.currentMurotal = data;
    const title = `${text(data.nama_latin || data.name || "Surah")} (${text(data.arti || data.translation || "")})`;
    el.murotalTitle.textContent = title;
    el.murotalMeta.textContent = `Surah ${n} • audio tersedia dari API online`;
    const audioUrl = data.audio || data.audio_url || "";
    if (audioUrl) {
      el.murotalAudio.src = audioUrl;
      writeJsonValue(STORE.murotalCache, { surah: n, audioUrl, title });
    } else {
      el.murotalAudio.removeAttribute("src");
    }
    renderCachePreview();
  }

  function readMushafCache() {
    const cached = state.mushafCache && typeof state.mushafCache === "object" ? state.mushafCache : {};
    cached.items = cached.items && typeof cached.items === "object" ? cached.items : {};
    return cached;
  }

  function writeMushafCache(cache) {
    state.mushafCache = cache;
    writeJsonValue("jadwal:mushafCache", cache);
    renderCachePreview();
  }

  function normalizeSurahPayload(payload, number) {
    const raw = payload?.data || payload || {};
    const verses = normalizeAyahList(raw);
    return {
      number,
      title: text(raw.nama_latin || raw.name_latin || raw.name || raw.surah?.name_latin || `Surah ${number}`),
      translation: text(raw.arti || raw.translation || raw.surah?.translation || ""),
      audioUrl: text(raw.audio || raw.audio_url || raw.audioFull || raw.audio_full || ""),
      verses,
      raw,
    };
  }

  function normalizeAyahList(raw) {
    const source = Array.isArray(raw?.ayat)
      ? raw.ayat
      : Array.isArray(raw?.ayahs)
        ? raw.ayahs
        : Array.isArray(raw?.verses)
          ? raw.verses
          : Array.isArray(raw?.data)
            ? raw.data
            : [];

    return source.map((verse, index) => ({
      number: text(verse.no || verse.ayah_number || verse.number || verse.verse_number || index + 1),
      arab: text(verse.ar || verse.arab || verse.text_arab || verse.textArab || verse.teks_arab || verse.ayah || ""),
      translation: text(verse.translation || verse.tr || verse.text || verse.arti || ""),
      audio_url: text(verse.audio_url || verse.audioUrl || verse.audio || ""),
      juz: verse.juz || verse.meta?.juz || "",
      page: verse.page || verse.meta?.page || "",
      surah: verse.surah || verse.surah_number || verse.meta?.surah || "",
      raw: verse,
    }));
  }

  async function fetchAyahFallback(surahNumber, ayahCount) {
    const total = Number(ayahCount);
    if (!Number.isInteger(total) || total < 1 || total > 20) {
      return [];
    }

    const tasks = Array.from({ length: total }, (_, index) => {
      const ayah = index + 1;
      return fetchJson(API.quranAyat(surahNumber, ayah))
        .then((payload) => normalizeAyahList(payload?.data || payload))
        .then((items) => items[0] || null)
        .catch(() => null);
    });

    const results = await Promise.all(tasks);
    return results.filter(Boolean);
  }

  function hasMushafVerses(data) {
    return Boolean(
      data &&
      (
        (Array.isArray(data.verses) && data.verses.length > 0) ||
        (Array.isArray(data.raw?.ayahs) && data.raw.ayahs.length > 0) ||
        (Array.isArray(data.raw?.ayat) && data.raw.ayat.length > 0) ||
        (Array.isArray(data.raw?.verses) && data.raw.verses.length > 0)
      )
    );
  }

  function renderMushafIndex(activeNumber) {
    const active = Number(activeNumber) || 1;
    const query = (el.mushafSearchInput?.value || "").trim().toLowerCase();
    const source = state.mushafIndex.length ? state.mushafIndex : Array.from({ length: 114 }, (_, i) => ({
      number: i + 1,
      name_latin: `Surah ${i + 1}`,
      translation: "",
      number_of_ayahs: "",
    }));

    const filtered = source.filter((item) => {
      if (!query) return true;
      return (
        text(item.name_latin || item.name).toLowerCase().includes(query) ||
        text(item.translation).toLowerCase().includes(query) ||
        text(item.number).includes(query)
      );
    });

    el.mushafIndex.innerHTML = filtered
      .map((item) => {
        const number = Number(item.number);
        const classes = number === active ? "surah-item active" : "surah-item";
        return `
          <button class="${classes}" data-mushaf-number="${number}">
            <div class="surah-number">${number}</div>
            <div class="surah-label">
              <strong>${escapeHtml(text(item.name_latin || item.name || `Surah ${number}`))}</strong>
              <span>${escapeHtml(text(item.translation || ""))}</span>
            </div>
            <div class="surah-count">${escapeHtml(text(item.number_of_ayahs || ""))} ayat</div>
          </button>
        `;
      })
      .join("");

    el.mushafIndex.querySelectorAll("button[data-mushaf-number]").forEach((button) => {
      button.addEventListener("click", () => {
        const number = Number(button.getAttribute("data-mushaf-number"));
        el.mushafSurahInput.value = String(number);
        loadMushafSurah(number);
      });
    });
  }

  function renderMushafVerses(data) {
    const verses = Array.isArray(data.verses) ? data.verses : [];
    if (!verses.length) {
      el.mushafVerses.innerHTML = `<div class="result-card">Surah ini belum menyediakan daftar ayat di respon API. Audio surah tetap bisa diputar kalau tersedia.</div>`;
      return;
    }

    el.mushafVerses.innerHTML = verses
      .map((verse, index) => {
        const number = text(verse.no || verse.ayah_number || verse.number || verse.verse_number || index + 1);
        const arabic = text(verse.ar || verse.arab || verse.text_arab || verse.textArab || verse.teks_arab || verse.ayah || "");
        const translation = text(verse.translation || verse.tr || verse.text || verse.arti || "");
        const metaParts = [
          verse.juz ? `Juz ${verse.juz}` : "",
          verse.page ? `Hal ${verse.page}` : "",
          verse.surah ? `Surah ${verse.surah}` : "",
        ].filter(Boolean);

        return `
          <article class="ayah-card" data-ayah-index="${index}">
            <div class="ayah-meta">
              <span class="ayah-number">${number}</span>
              ${metaParts.map((part) => `<span>${escapeHtml(text(part))}</span>`).join("")}
            </div>
            <div class="ayah-arabic">${escapeHtml(arabic || "—")}</div>
            <div class="ayah-translation">${escapeHtml(translation || "Terjemahan belum tersedia di respon API.")}</div>
            <div class="ayah-actions">
              <button class="ghost" data-ayah-play="${index}">Play ayat</button>
            </div>
          </article>
        `;
      })
      .join("");

    el.mushafVerses.querySelectorAll("button[data-ayah-play]").forEach((button) => {
      button.addEventListener("click", () => {
        const index = Number(button.getAttribute("data-ayah-play"));
        const verse = data.verses[index];
        const audioUrl = verse?.audio_url || verse?.audioUrl || verse?.audio || "";
        if (!audioUrl) return;
        state.mushafPlaybackKind = "ayah";
        state.mushafPlayingIndex = index;
        el.mushafAudio.src = audioUrl;
        el.mushafAudio.play().catch(() => {});
        state.mushafPlaying = true;
        syncMushafPlaybackUi();
      });
    });

    syncMushafPlaybackUi();
  }

  async function loadMushafSurah(number, options = {}) {
    const n = Number(number);
    if (!Number.isInteger(n) || n < 1 || n > 114) {
      throw new Error("Nomor surah harus 1-114");
    }

    const cache = readMushafCache();
    const cached = cache.items?.[String(n)];
    let data;

    showLoading(el.mushafVerses, `Memuat surah ${n}...`);

    if (options.preferCache !== false && cached && hasMushafVerses(cached)) {
      data = cached;
    } else {
      try {
        const payload = await fetchJson(API.quranSurah(n));
        data = normalizeSurahPayload(payload, n);
      } catch (error) {
        if (cached) {
          data = cached;
        } else {
          throw error;
        }
      }
    }

    if (!hasMushafVerses(data)) {
      try {
        const payload = await fetchJson(API.quranSurah(n));
        data = normalizeSurahPayload(payload, n);
      } catch {
        // keep fallback data if any
      }
    }

    if (!hasMushafVerses(data)) {
      const ayahCount = Number(data.raw?.number_of_ayahs || data.raw?.ayahs?.length || data.raw?.ayat?.length || data.raw?.verses?.length || 0);
      if (ayahCount > 0 && ayahCount <= 20 && navigator.onLine) {
        const fallbackVerses = await fetchAyahFallback(n, ayahCount);
        if (fallbackVerses.length) {
          data.verses = fallbackVerses;
        }
      }
    }

    if (!hasMushafVerses(data)) {
      el.mushafVerses.innerHTML = `<div class="result-card">Ayat untuk surah ini belum terbaca dari API atau cache lokal. Coba refresh online atau hard refresh browser.</div>`;
      el.mushafDescription.textContent = "";
      state.mushafSurahAudioUrl = data.audioUrl || "";
      el.mushafAudio.src = state.mushafSurahAudioUrl || "";
      syncMushafPlaybackUi();
      return data;
    }

    state.currentMushaf = data;
    renderMushafIndex(n);
    el.mushafSurahInput.value = String(n);
    el.mushafTitle.textContent = `${data.title}`;
    const ayahCount = data.raw?.number_of_ayahs || data.raw?.ayahs?.length || data.verses?.length || "";
    el.mushafMeta.textContent = `Surah ${n}${data.translation ? ` • ${data.translation}` : ""}${ayahCount ? ` • ${ayahCount} ayat` : ""}`;
    el.mushafDescription.textContent = text(data.raw?.description || "");
    state.mushafSurahAudioUrl = data.audioUrl || "";
    el.mushafAudio.src = state.mushafSurahAudioUrl || "";
    el.mushafAudioShell.classList.add("hidden");
    el.mushafAudioToggleBtn.textContent = "Audio opsional";
    state.mushafPlaybackKind = "surah";
    state.mushafPlayingIndex = null;
    state.mushafPlaying = false;
    el.mushafPlayBtn.onclick = () => {
      if (!state.mushafSurahAudioUrl) return;
      if (el.mushafAudio.src !== state.mushafSurahAudioUrl) {
        el.mushafAudio.src = state.mushafSurahAudioUrl;
        state.mushafPlaybackKind = "surah";
        state.mushafPlayingIndex = null;
      }
      if (el.mushafAudio.paused) {
        el.mushafAudio.play().catch(() => {});
        state.mushafPlaying = true;
      } else {
        el.mushafAudio.pause();
        state.mushafPlaying = false;
      }
      syncMushafPlaybackUi();
    };
    el.mushafAudio.onpause = () => {
      if (state.currentMushaf) {
        state.mushafPlaying = false;
        syncMushafPlaybackUi();
      }
    };
    el.mushafAudio.onended = () => {
      state.mushafPlaying = false;
      syncMushafPlaybackUi();
    };
    renderMushafVerses(data);

    cache.items = cache.items || {};
    cache.items[String(n)] = data;
    cache.last = n;
    writeMushafCache(cache);

    requestAnimationFrame(() => {
      el.mushafTitle.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    return data;
  }

  function hydrateFromLocalSchedule() {
    const current = state.currentSchedule;
    if (!current) return;
    const data = current.data;
    const savedId = readJsonValue(STORE.lastCityId) || text(data.id || "");
    const savedName = readJsonValue(STORE.lastCityName) || text(data.lokasi || "");
    el.cityId.value = savedId;
    el.cityQuery.value = savedName;
    el.scheduleDate.value = readJsonValue(STORE.lastDate) || toYmd(nowDate());
  }

  function bindEvents() {
    el.reloadLocalBtn.addEventListener("click", async () => {
      await loadLocalSchedule();
      hydrateFromLocalSchedule();
    });

    el.reloadOnlineBtn.addEventListener("click", async () => {
      await refreshOnlineSchedule();
    });

    el.cityQuery.addEventListener("input", () => renderCityResults(el.cityQuery.value));

    el.loadMurotalBtn.addEventListener("click", async () => {
      await loadMurotal(el.surahInput.value);
    });

    el.mushafLoadBtn.addEventListener("click", async () => {
      await loadMushafSurah(el.mushafSurahInput.value);
    });

    el.mushafAudioToggleBtn.addEventListener("click", () => {
      const hidden = el.mushafAudioShell.classList.contains("hidden");
      if (hidden) {
        el.mushafAudioShell.classList.remove("hidden");
        el.mushafAudioToggleBtn.textContent = "Sembunyikan audio";
      } else {
        el.mushafAudioShell.classList.add("hidden");
        el.mushafAudioToggleBtn.textContent = "Audio opsional";
      }
    });

    if (el.mushafSearchInput) {
      el.mushafSearchInput.addEventListener("input", () => {
        renderMushafIndex(Number(el.mushafSurahInput.value || 1));
      });
    }

    el.mushafPrevBtn.addEventListener("click", async () => {
      const next = Math.max(1, Number(el.mushafSurahInput.value || 1) - 1);
      await loadMushafSurah(next);
    });

    el.mushafNextBtn.addEventListener("click", async () => {
      const next = Math.min(114, Number(el.mushafSurahInput.value || 1) + 1);
      await loadMushafSurah(next);
    });

    el.mushafCacheBtn.addEventListener("click", async () => {
      const n = Number(el.mushafSurahInput.value || 1);
      const cache = readMushafCache();
      if (cache.items?.[String(n)]) {
        await loadMushafSurah(n, { preferCache: true });
      } else {
        await loadMushafSurah(n, { preferCache: false });
      }
    });

    window.addEventListener("online", setConnectionBadge);
    window.addEventListener("offline", setConnectionBadge);
  }

  async function boot() {
    setConnectionBadge();
    setClock();
    setInterval(setClock, 60_000);
    await Promise.all([loadCityList(), loadLocalSchedule(), loadLocalCacheExtras()]);
    await loadMushafIndex();
    hydrateFromLocalSchedule();
    renderCityResults(el.cityQuery.value);
    bindEvents();

    if (!state.currentSchedule && navigator.onLine && el.cityId.value) {
      try {
        await refreshOnlineSchedule();
      } catch {
        // keep local fallback if online refresh fails
      }
    }

    renderCachePreview();

    try {
      await loadMushafSurah(1);
    } catch {
      el.mushafTitle.textContent = "Al-Fatihah";
      el.mushafMeta.textContent = "Surah 1 • belum tersedia cache/API";
      renderMushafIndex(1);
    }
  }

  boot().catch((error) => {
    console.error("Boot gagal:", error);
  });
})();
