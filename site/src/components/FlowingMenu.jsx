'use client';

import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import './FlowingMenu.css';

const ROOT = 'flowing-menu';
const LIST = 'flowing-menu__list';
const ITEM = 'flowing-menu__item';
const DIVIDER = 'flowing-menu__divider';
const LINK = 'flowing-menu__link';
const INDEX = 'flowing-menu__index';
const LABEL = 'flowing-menu__label';
const LABEL_TEXT = 'flowing-menu__label-text';
const DOT = 'flowing-menu__dot';
const END = 'flowing-menu__end';
const META = 'flowing-menu__meta';
const ARROW = 'flowing-menu__arrow';
const BAND = 'flowing-menu__band';
const TRACK = 'flowing-menu__track';
const PART = 'flowing-menu__part';
const PART_TEXT = 'flowing-menu__part-text';
const IMAGE = 'flowing-menu__image';
const FLOAT = 'flowing-menu__float';
const FLOAT_LAYER = 'flowing-menu__float-layer';

const DIRECTIONS = ['left', 'right', 'alternate'];
const SHAPES = ['pill', 'rounded', 'circle'];
const EASE = 'cubic-bezier(0.2, 0.9, 0.2, 1)';

const useIsoLayoutEffect = typeof window === 'undefined' ? useEffect : useLayoutEffect;

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const prefersReduced = () =>
  typeof window !== 'undefined' && (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false);

function FlowingMenu({
  items = [],
  speed = 60,
  direction = 'left',
  followCursor = 0.4,
  duration = 0.5,
  stretch = 0.6,
  magnet = 0.25,
  bandInset = 0,
  bandRadius = 0,
  carryContent = false,
  textColor = '#ffffff',
  bgColor = '#120F17',
  marqueeBgColor = '#ffffff',
  marqueeTextColor = '#120F17',
  borderColor = 'rgba(255, 255, 255, 0.14)',
  dividers = true,
  dimInactive = false,
  align = 'center',
  showIndex = false,
  showArrow = false,
  imageShape = 'pill',
  intro = true,
  columns = 1,
  startIndex = 0,
  activeIndex,
  onItemClick,
  ariaLabel = 'Menu',
  className = '',
  style
}) {
  const rootRef = useRef(null);
  const listRef = useRef(null);
  const rows = useRef([]);
  const marquees = useRef([]);
  const metrics = useRef([]);
  const band = useRef({
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    vTop: 0,
    vBottom: 0,
    vLeft: 0,
    vRight: 0,
    toTop: 0,
    toBottom: 0,
    toLeft: 0,
    toRight: 0,
    leadY: 1,
    leadX: 1,
    shown: false,
    index: -1,
    restY: 0,
    restX: 0
  });
  const cursor = useRef({ x: 0, lx: 0, y: null, t: 0, vx: 0 });
  const engine = useRef({ raf: 0, last: 0, timers: [], touched: false, touch: false });
  const [copies, setCopies] = useState([]);
  const floatRef = useRef(null);
  const layerRefs = useRef([]);
  const layerTracks = useRef([]);
  const roll = useRef({ current: 0, p: 1, dir: 1, slots: [-1, -1], fromOpacity: 0, fromOffset: 0 });
  const [slots, setSlots] = useState([-1, -1]);

  const settings = {
    speed: Math.max(0, speed),
    direction: DIRECTIONS.includes(direction) ? direction : 'left',
    followCursor: clamp(followCursor, 0, 1),
    duration: Math.max(0.1, duration),
    stretch: clamp(stretch, 0, 1),
    magnet: clamp(magnet, 0, 1),
    bandInset: Math.max(0, bandInset),
    bandRadius: Math.max(0, bandRadius),
    carryContent,
    dimInactive,
    columns: Math.max(1, Math.round(columns) || 1),
    onItemClick
  };
  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  const marqueeAt = index => {
    if (!marquees.current[index]) marquees.current[index] = { x: 0, part: 0, spin: 0, covered: false };
    return marquees.current[index];
  };

  const insetFor = height => Math.min(settingsRef.current.bandInset, Math.max(0, height / 2 - 2));

  const markRows = () => {
    const b = band.current;
    const dim = settingsRef.current.dimInactive && b.index >= 0;
    rows.current.forEach((row, index) => {
      if (!row?.item) return;
      if (index === b.index) row.item.setAttribute('data-current', '');
      else row.item.removeAttribute('data-current');
      if (dim && index !== b.index) row.item.setAttribute('data-dimmed', '');
      else row.item.removeAttribute('data-dimmed');
    });
  };

  const rowHeight = () => metrics.current.find(Boolean)?.height ?? 0;

  const paintFloat = () => {
    const b = band.current;
    const s = settingsRef.current;
    const r = roll.current;
    const el = floatRef.current;
    const list = listRef.current;
    if (!el || !list) return;
    if (!b.shown || b.bottom - b.top < 0.25) {
      el.style.visibility = 'hidden';
      return;
    }
    const height = rowHeight();
    const side = Math.min(s.bandInset, Math.max(0, height / 2 - 2));
    const radius = Math.min(s.bandRadius, (b.bottom - b.top) / 2, Math.max(0, list.clientWidth / 2 - side));
    el.style.visibility = 'visible';
    el.style.clipPath = `inset(${b.top.toFixed(2)}px ${side}px ${(list.clientHeight - b.bottom).toFixed(2)}px ${side}px round ${radius.toFixed(2)}px)`;
    const center = (b.top + b.bottom) / 2;
    const eased = 1 - Math.pow(1 - r.p, 3);
    const travel = height * 0.8 * r.dir;
    [0, 1].forEach(slot => {
      const layer = layerRefs.current[slot];
      const index = r.slots[slot];
      if (!layer) return;
      const current = slot === r.current;
      const visible = index >= 0 && (current || r.p < 1);
      layer.style.visibility = visible ? 'visible' : 'hidden';
      if (!visible) return;
      const offset = current ? (1 - eased) * travel : r.fromOffset - eased * travel;
      const opacity = current ? eased : r.fromOpacity * (1 - eased);
      layer.style.height = `${height}px`;
      layer.style.opacity = opacity.toFixed(3);
      layer.style.transform = `translate3d(0, ${(center - height / 2 + offset).toFixed(2)}px, 0)`;
      const state = marqueeAt(index);
      state.covered = true;
      const track = layerTracks.current[slot];
      if (track) track.style.transform = `translate3d(${state.x.toFixed(2)}px, 0, 0)`;
    });
  };

  const paint = () => {
    const b = band.current;
    const s = settingsRef.current;
    const height = Math.max(0, b.bottom - b.top);
    rows.current.forEach((row, index) => {
      const m = metrics.current[index];
      if (!row?.band || !m) return;
      const state = marqueeAt(index);
      state.covered = false;
      const from = Math.max(b.top, m.top);
      const to = Math.min(b.bottom, m.top + m.height);
      const overlapX = Math.min(b.right, m.left + m.width) - Math.max(b.left, m.left);
      if (s.carryContent || !b.shown || to - from < 0.25 || overlapX < 0.25) {
        row.band.style.visibility = 'hidden';
      } else {
        const radius = Math.min(
          s.bandRadius,
          height / 2,
          Math.max(0, (b.right - b.left) / 2, (row.item?.clientWidth ?? 0) / 2)
        );
        const clipTop = Math.max(0, b.top - m.top);
        const clipRight = Math.max(0, m.left + m.width - b.right);
        const clipBottom = Math.max(0, m.top + m.height - b.bottom);
        const clipLeft = Math.max(0, b.left - m.left);
        row.band.style.visibility = 'visible';
        row.band.style.clipPath = `inset(${clipTop.toFixed(2)}px ${clipRight.toFixed(2)}px ${clipBottom.toFixed(2)}px ${clipLeft.toFixed(2)}px round ${radius.toFixed(2)}px)`;
        state.covered = (to - from) / m.height > 0.04 && overlapX / m.width > 0.04;
      }
      if (row.track) row.track.style.transform = `translate3d(${state.x.toFixed(2)}px, 0, 0)`;
    });
    if (s.carryContent) paintFloat();
    else if (floatRef.current) floatRef.current.style.visibility = 'hidden';
  };

  const frame = now => {
    const loop = engine.current;
    loop.raf = 0;
    const s = settingsRef.current;
    const b = band.current;
    const c = cursor.current;
    const reduced = prefersReduced();
    const elapsed = clamp((now - loop.last) / 1000, 0, 1 / 20);
    loop.last = now;
    let busy = false;

    if (b.shown) {
      const current = b.index >= 0 ? metrics.current[b.index] : null;
      if (current) {
        const inset = insetFor(current.height);
        const side = Math.min(s.bandInset, Math.max(0, current.width / 2 - 2));
        const leanY =
          c.y === null || reduced
            ? 0
            : clamp((c.y - (current.top + current.height / 2)) * s.magnet, -current.height * 0.3, current.height * 0.3);
        const leanX =
          reduced
            ? 0
            : clamp((c.lx - (current.left + current.width / 2)) * s.magnet, -current.width * 0.3, current.width * 0.3);
        b.toTop = current.top + inset + leanY;
        b.toBottom = current.top + current.height - inset + leanY;
        b.toLeft = current.left + side + leanX;
        b.toRight = current.left + current.width - side + leanX;
      } else if (b.index < 0) {
        b.toTop = b.toBottom = b.restY;
        b.toLeft = b.toRight = b.restX;
      }
      const gapY = (b.toTop + b.toBottom) / 2 - (b.top + b.bottom) / 2;
      const gapX = (b.toLeft + b.toRight) / 2 - (b.left + b.right) / 2;
      if (Math.abs(gapY) > 2) b.leadY = gapY > 0 ? 1 : -1;
      if (Math.abs(gapX) > 2) b.leadX = gapX > 0 ? 1 : -1;
      if (reduced) {
        b.top = b.toTop;
        b.bottom = b.toBottom;
        b.left = b.toLeft;
        b.right = b.toRight;
        b.vTop = b.vBottom = b.vLeft = b.vRight = 0;
      } else {
        const omega = (Math.PI * 2) / s.duration;
        const fast = omega * (1 + 1.1 * s.stretch);
        const slow = omega * (1 - 0.4 * s.stretch);
        const zeta = 1 - 0.3 * s.stretch;
        const wTop = b.leadY > 0 ? slow : fast;
        const wBottom = b.leadY > 0 ? fast : slow;
        const wLeft = b.leadX > 0 ? slow : fast;
        const wRight = b.leadX > 0 ? fast : slow;
        const steps = Math.max(1, Math.ceil(elapsed / (1 / 240)));
        const dt = elapsed / steps;
        for (let i = 0; i < steps; i++) {
          b.vTop += (-wTop * wTop * (b.top - b.toTop) - 2 * zeta * wTop * b.vTop) * dt;
          b.vBottom += (-wBottom * wBottom * (b.bottom - b.toBottom) - 2 * zeta * wBottom * b.vBottom) * dt;
          b.vLeft += (-wLeft * wLeft * (b.left - b.toLeft) - 2 * zeta * wLeft * b.vLeft) * dt;
          b.vRight += (-wRight * wRight * (b.right - b.toRight) - 2 * zeta * wRight * b.vRight) * dt;
          b.top += b.vTop * dt;
          b.bottom += b.vBottom * dt;
          b.left += b.vLeft * dt;
          b.right += b.vRight * dt;
          if (b.bottom < b.top) {
            const mid = (b.top + b.bottom) / 2;
            const v = (b.vTop + b.vBottom) / 2;
            b.top = b.bottom = mid;
            b.vTop = b.vBottom = v;
          }
          if (b.right < b.left) {
            const mid = (b.left + b.right) / 2;
            const v = (b.vLeft + b.vRight) / 2;
            b.left = b.right = mid;
            b.vLeft = b.vRight = v;
          }
        }
      }
      const resting =
        Math.abs(b.top - b.toTop) < 0.1 &&
        Math.abs(b.bottom - b.toBottom) < 0.1 &&
        Math.abs(b.left - b.toLeft) < 0.1 &&
        Math.abs(b.right - b.toRight) < 0.1 &&
        Math.abs(b.vTop) < 2 &&
        Math.abs(b.vBottom) < 2 &&
        Math.abs(b.vLeft) < 2 &&
        Math.abs(b.vRight) < 2;
      if (resting) {
        b.top = b.toTop;
        b.bottom = b.toBottom;
        b.left = b.toLeft;
        b.right = b.toRight;
        b.vTop = b.vBottom = b.vLeft = b.vRight = 0;
        if (b.index < 0 && b.bottom - b.top < 0.5) b.shown = false;
      } else busy = true;
    }

    const r = roll.current;
    if (r.p < 1) {
      r.p = reduced ? 1 : Math.min(1, r.p + elapsed / (s.duration * 0.8));
      busy = true;
    }

    c.vx *= Math.exp(-elapsed / 0.3);
    const push = clamp(c.vx * s.followCursor * 0.55, -1600, 1600);

    const settled =
      !b.shown ||
      (Math.abs(b.vTop) + Math.abs(b.vBottom) + Math.abs(b.vLeft) + Math.abs(b.vRight) < 40 &&
        Math.abs(b.top - b.toTop) + Math.abs(b.left - b.toLeft) < 8);

    marquees.current.forEach((state, index) => {
      if (!state) return;
      const goal = !state.covered ? 0 : settled ? 1 : 0.12;
      state.spin += (goal - state.spin) * (1 - Math.exp(-elapsed / 0.35));
      if (Math.abs(goal - state.spin) < 0.002) state.spin = goal;
      if (!state.covered && state.spin === 0) return;
      busy = true;
      if (state.part <= 0 || reduced) return;
      const flow = s.direction === 'alternate' ? (index % 2 ? 1 : -1) : s.direction === 'right' ? 1 : -1;
      state.x += (flow * s.speed + push) * state.spin * elapsed;
      state.x = (((state.x % state.part) + state.part) % state.part) - state.part;
    });

    paint();
    if (busy) loop.raf = requestAnimationFrame(frame);
  };

  const kick = () => {
    const loop = engine.current;
    if (loop.raf || typeof window === 'undefined') return;
    loop.last = performance.now();
    loop.raf = requestAnimationFrame(frame);
  };

  const goTo = (index, from) => {
    const m = metrics.current[index];
    if (!m) return;
    const b = band.current;
    const inset = insetFor(m.height);
    const side = Math.min(settingsRef.current.bandInset, Math.max(0, m.width / 2 - 2));
    const top = m.top + inset;
    const bottom = m.top + m.height - inset;
    const left = m.left + side;
    const right = m.left + m.width - side;
    const r = roll.current;
    const showing = r.slots[r.current];
    if (settingsRef.current.carryContent && showing !== index) {
      if (!b.shown || showing < 0) {
        r.slots[r.current] = index;
        r.p = 1;
      } else {
        const eased = 1 - Math.pow(1 - r.p, 3);
        r.fromOpacity = eased;
        r.fromOffset = (1 - eased) * m.height * 0.8 * r.dir;
        r.dir = index > showing ? 1 : -1;
        r.current = 1 - r.current;
        r.slots[r.current] = index;
        r.p = 0;
      }
      setSlots([...r.slots]);
    }
    if (!b.shown) {
      const startY = from === 'bottom' ? bottom : from === 'center' ? (top + bottom) / 2 : top;
      const startX =
        cursor.current.lx < m.left + m.width / 2 ? left : right;
      b.top = b.bottom = startY;
      b.left = b.right = startX;
      b.vTop = b.vBottom = b.vLeft = b.vRight = 0;
      b.shown = true;
    }
    const shiftY = (top + bottom) / 2 - (b.top + b.bottom) / 2;
    const shiftX = (left + right) / 2 - (b.left + b.right) / 2;
    if (Math.abs(shiftY) > 0.5) b.leadY = shiftY > 0 ? 1 : -1;
    else b.leadY = from === 'bottom' ? -1 : 1;
    if (Math.abs(shiftX) > 0.5) b.leadX = shiftX > 0 ? 1 : -1;
    b.toTop = top;
    b.toBottom = bottom;
    b.toLeft = left;
    b.toRight = right;
    b.index = index;
    markRows();
    kick();
  };

  const release = toward => {
    const b = band.current;
    if (!b.shown) return;
    const pointY = toward === 'top' ? b.toTop : toward === 'bottom' ? b.toBottom : (b.toTop + b.toBottom) / 2;
    const pointX = (b.toLeft + b.toRight) / 2;
    b.leadY = toward === 'top' ? -1 : 1;
    b.restY = pointY;
    b.restX = pointX;
    b.toTop = b.toBottom = pointY;
    b.toLeft = b.toRight = pointX;
    b.index = -1;
    cursor.current.y = null;
    markRows();
    kick();
  };

  const rowAt = (clientX, clientY) => {
    const list = listRef.current;
    if (!list) return -1;
    const rect = list.getBoundingClientRect();
    const y = clientY - rect.top;
    const x = clientX - rect.left;
    return metrics.current.findIndex(
      m => m && y >= m.top && y < m.top + m.height && x >= m.left && x < m.left + m.width
    );
  };

  const halfOf = (clientY, index) => {
    const list = listRef.current;
    const m = metrics.current[index];
    if (!list || !m) return 'top';
    return clientY - list.getBoundingClientRect().top - m.top < m.height / 2 ? 'top' : 'bottom';
  };

  const stopIntro = () => {
    const loop = engine.current;
    loop.touched = true;
    loop.timers.forEach(clearTimeout);
    loop.timers = [];
  };

  const measure = () => {
    const list = listRef.current;
    metrics.current = rows.current.map(row =>
      row?.item
        ? {
            top: row.item.offsetTop,
            height: row.item.offsetHeight,
            left: row.item.offsetLeft,
            width: row.item.offsetWidth
          }
        : null
    );
    if (list && metrics.current[0]) {
      const height = metrics.current[0].height;
      const inset = insetFor(height);
      rootRef.current?.style.setProperty('--flowing-menu-band', String(height ? (height - inset * 2) / height : 1));
    }
    const next = rows.current.map((row, index) => {
      const state = marqueeAt(index);
      const part = row?.track?.firstElementChild;
      const width = part?.getBoundingClientRect().width ?? 0;
      const total = row?.item?.getBoundingClientRect().width ?? 0;
      if (width > 0) {
        state.part = width;
        state.x = (((state.x % width) + width) % width) - width;
      }
      return width > 0 ? Math.max(2, Math.ceil(total / width) + 1) : 3;
    });
    setCopies(current =>
      current.length === next.length && current.every((value, index) => value === next[index]) ? current : next
    );
    const b = band.current;
    if (b.shown && b.index >= 0) {
      const m = metrics.current[b.index];
      if (m) {
        const inset = insetFor(m.height);
        const side = Math.min(settingsRef.current.bandInset, Math.max(0, m.width / 2 - 2));
        b.toTop = m.top + inset;
        b.toBottom = m.top + m.height - inset;
        b.toLeft = m.left + side;
        b.toRight = m.left + m.width - side;
      }
    }
    paint();
    kick();
  };
  const measureRef = useRef(measure);
  measureRef.current = measure;

  useIsoLayoutEffect(() => {
    measureRef.current();
    const root = rootRef.current;
    if (!root || typeof ResizeObserver === 'undefined') return undefined;
    const observer = new ResizeObserver(() => measureRef.current());
    observer.observe(root);
    rows.current.forEach(row => {
      const part = row?.track?.firstElementChild;
      if (part) observer.observe(part);
    });
    return () => observer.disconnect();
  }, [items, bandInset]);

  useIsoLayoutEffect(() => {
    rows.current.length = items.length;
    marquees.current.length = items.length;
    paint();
  });

  const goToRef = useRef(goTo);
  goToRef.current = goTo;
  const releaseRef = useRef(release);
  releaseRef.current = release;

  useIsoLayoutEffect(() => {
    if (!intro || prefersReduced()) return undefined;
    const root = rootRef.current;
    if (!root) return undefined;

    const play = () => {
      if (engine.current.touched) return;
      root.querySelectorAll('[data-intro-line]').forEach((node, index) => {
        node.animate([{ transform: 'translateY(110%)' }, { transform: 'none' }], {
          duration: 900,
          delay: index * 70,
          easing: EASE,
          fill: 'backwards'
        });
      });
      root.querySelectorAll('[data-intro-fade]').forEach((node, index) => {
        node.animate([{ opacity: 0 }, { opacity: 1 }], {
          duration: 700,
          delay: 200 + index * 40,
          easing: 'ease',
          fill: 'backwards'
        });
      });
      root.querySelectorAll('[data-intro-rule]').forEach((node, index) => {
        node.animate([{ transform: 'scaleX(0)' }, { transform: 'none' }], {
          duration: 1100,
          delay: index * 70,
          easing: EASE,
          fill: 'backwards'
        });
      });
      const loop = engine.current;
      const count = rows.current.filter(Boolean).length;
      const cols = Math.max(1, settingsRef.current.columns);
      const demo = Math.min(count, Math.ceil(count / cols));
      const start = 400 + demo * 40;
      for (let index = 0; index < demo; index++) {
        loop.timers.push(
          setTimeout(() => {
            if (!loop.touched) goToRef.current(index, 'top');
          }, start + index * 140)
        );
      }
      loop.timers.push(
        setTimeout(() => {
          if (!loop.touched) releaseRef.current('bottom');
        }, start + demo * 140 + 180)
      );
    };

    if (typeof IntersectionObserver === 'undefined') {
      play();
      return () => {
        engine.current.timers.forEach(clearTimeout);
        engine.current.timers = [];
      };
    }

    const observer = new IntersectionObserver(
      entries => {
        if (!entries.some(entry => entry.isIntersecting && entry.intersectionRatio >= 0.28)) return;
        observer.disconnect();
        play();
      },
      { threshold: [0.28] }
    );
    observer.observe(root);
    return () => {
      observer.disconnect();
      engine.current.timers.forEach(clearTimeout);
      engine.current.timers = [];
    };
  }, []);

  useEffect(() => {
    const loop = engine.current;
    const onKeyDown = () => {
      loop.touch = false;
    };
    const onDocumentPointerDown = event => {
      if (event.pointerType !== 'touch') return;
      if (rootRef.current?.contains(event.target)) return;
      releaseRef.current('bottom');
    };
    window.addEventListener('keydown', onKeyDown, { passive: true });
    document.addEventListener('pointerdown', onDocumentPointerDown, { passive: true });
    return () => {
      cancelAnimationFrame(loop.raf);
      window.removeEventListener('keydown', onKeyDown);
      document.removeEventListener('pointerdown', onDocumentPointerDown);
    };
  }, []);

  const onPointerMove = event => {
    if (event.pointerType === 'touch') return;
    engine.current.touch = false;
    stopIntro();
    const c = cursor.current;
    const now = performance.now();
    const gap = (now - c.t) / 1000;
    if (gap > 0 && gap < 0.1) {
      const instant = (event.clientX - c.x) / gap;
      c.vx += (instant - c.vx) * (1 - Math.exp(-gap / 0.08));
    }
    c.x = event.clientX;
    c.t = now;
    const list = listRef.current;
    if (list) {
      const rect = list.getBoundingClientRect();
      c.lx = event.clientX - rect.left;
      c.y = event.clientY - rect.top;
    }
    const index = rowAt(event.clientX, event.clientY);
    if (index >= 0 && index !== band.current.index) goTo(index, halfOf(event.clientY, index));
    else kick();
  };

  const onPointerLeave = event => {
    if (event.pointerType === 'touch') return;
    const list = listRef.current;
    const b = band.current;
    if (!list || b.index < 0) return;
    const rect = list.getBoundingClientRect();
    if (event.clientY <= rect.top) release('top');
    else if (event.clientY >= rect.bottom) release('bottom');
    else release(halfOf(event.clientY, b.index));
  };

  const linkHandlers = (item, index) => ({
    onPointerDown: event => {
      if (event.pointerType !== 'touch') {
        engine.current.touch = false;
        return;
      }
      engine.current.touch = true;
      stopIntro();
      goTo(index, halfOf(event.clientY, index));
    },
    onFocus: event => {
      if (!event.currentTarget.matches(':focus-visible')) return;
      stopIntro();
      goTo(index, 'top');
    },
    onBlur: event => {
      if (engine.current.touch) return;
      const next = event.relatedTarget;
      if (next && listRef.current?.contains(next)) return;
      release('bottom');
    },
    onClick: event => settingsRef.current.onItemClick?.(item, index, event)
  });

  const shape = SHAPES.includes(imageShape) ? imageShape : 'pill';

  return (
    <nav
      ref={rootRef}
      className={[ROOT, className].filter(Boolean).join(' ')}
      style={{
        backgroundColor: bgColor,
        color: textColor,
        '--flowing-menu-border': borderColor,
        '--flowing-menu-rows': String(Math.ceil(items.length / Math.max(1, settings.columns))),
        '--t-move': `${settings.duration}s`,
        ...style
      }}
      aria-label={ariaLabel}
      data-align={align === 'left' ? 'left' : 'center'}
      data-shape={shape}
      data-columns={String(settings.columns)}
    >
      <ul ref={listRef} className={LIST} onPointerMove={onPointerMove} onPointerLeave={onPointerLeave}>
        {items.map((item, index) => {
          const active = index === activeIndex;
          const handlers = linkHandlers(item, index);
          const content = (
            <>
              <span className={INDEX} data-intro-fade="" aria-hidden="true">
                {showIndex ? String(index + startIndex + 1).padStart(2, '0') : null}
              </span>
              <span className={LABEL}>
                <span className={LABEL_TEXT} data-intro-line="">
                  {item.label ?? item.text}
                </span>
                {active && <span className={DOT} aria-hidden="true" />}
              </span>
              <span className={END} data-intro-fade="" aria-hidden="true">
                {item.meta ? <span className={META}>{item.meta}</span> : null}
                {showArrow ? (
                  <span className={ARROW}>
                    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
                      <path d="M7 17 17 7M9 7h8v8" />
                    </svg>
                  </span>
                ) : null}
              </span>
            </>
          );
          return (
            <li
              key={`${item.text}-${index}`}
              ref={node => {
                rows.current[index] = { ...rows.current[index], item: node };
              }}
              className={ITEM}
            >
              {dividers &&
                index > 0 &&
                index % Math.ceil(items.length / Math.max(1, settings.columns)) !== 0 && (
                  <span className={DIVIDER} data-intro-rule="" aria-hidden="true" />
                )}
              {item.link ? (
                <a
                  className={LINK}
                  href={item.link}
                  aria-label={item.ariaLabel}
                  aria-current={active ? 'page' : undefined}
                  {...handlers}
                >
                  {content}
                </a>
              ) : (
                <button
                  type="button"
                  className={LINK}
                  aria-label={item.ariaLabel}
                  aria-current={active ? 'page' : undefined}
                  {...handlers}
                >
                  {content}
                </button>
              )}
              <div
                className={BAND}
                aria-hidden="true"
                style={{ backgroundColor: marqueeBgColor, color: marqueeTextColor }}
                ref={node => {
                  rows.current[index] = { ...rows.current[index], band: node };
                }}
              >
                <div
                  className={TRACK}
                  ref={node => {
                    rows.current[index] = { ...rows.current[index], track: node };
                  }}
                >
                  {Array.from({ length: copies[index] ?? 3 }, (_, copy) => (
                    <div className={PART} key={copy}>
                      <span className={PART_TEXT}>{item.marquee ?? item.text}</span>
                      {item.image && <span className={IMAGE} style={{ backgroundImage: `url(${item.image})` }} />}
                    </div>
                  ))}
                </div>
              </div>
            </li>
          );
        })}
      </ul>
      {carryContent && (
        <div
          className={FLOAT}
          aria-hidden="true"
          ref={floatRef}
          style={{ backgroundColor: marqueeBgColor, color: marqueeTextColor }}
        >
          {[0, 1].map(slot => {
            const item = slots[slot] >= 0 ? items[slots[slot]] : null;
            return (
              <div
                key={slot}
                className={FLOAT_LAYER}
                ref={node => {
                  layerRefs.current[slot] = node;
                }}
              >
                <div
                  className={TRACK}
                  ref={node => {
                    layerTracks.current[slot] = node;
                  }}
                >
                  {item &&
                    Array.from({ length: copies[slots[slot]] ?? 3 }, (_, copy) => (
                      <div className={PART} key={copy}>
                        <span className={PART_TEXT}>{item.marquee ?? item.text}</span>
                        {item.image && <span className={IMAGE} style={{ backgroundImage: `url(${item.image})` }} />}
                      </div>
                    ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </nav>
  );
}

export default FlowingMenu;
