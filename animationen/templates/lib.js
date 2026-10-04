// Shared helpers. Every template defines window.DURATION (seconds) and
// window.render(t), which must draw the frame for time t deterministically
// (no CSS animations, no Date.now(), no Math.random()).

const P = new URLSearchParams(location.search);
const param = (k, d) => (P.has(k) ? P.get(k) : d);
const num = (k, d) => (P.has(k) ? parseFloat(P.get(k)) : d);

if (param("bg", "dark") === "green") document.body.classList.add("green");
if (param("bg", "dark") === "transparent") {
  document.documentElement.classList.add("transparent");
  document.body.classList.add("transparent");
}

const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
// Progress of t inside [a, b], clamped to 0..1.
const prog = (t, a, b) => clamp((t - a) / (b - a));
const lerp = (a, b, k) => a + (b - a) * k;

const ease = {
  outCubic: (k) => 1 - Math.pow(1 - k, 3),
  inOutCubic: (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2),
  outExpo: (k) => (k === 1 ? 1 : 1 - Math.pow(2, -10 * k)),
  // Apple-like spring with a small overshoot.
  outBack: (k) => {
    const c1 = 1.4, c3 = c1 + 1;
    return 1 + c3 * Math.pow(k - 1, 3) + c1 * Math.pow(k - 1, 2);
  },
};

const fmt = (v, decimals = 0) =>
  v.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });

// Deterministic pseudo random numbers (mulberry32).
function rng(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let r = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

const $ = (s) => document.querySelector(s);
