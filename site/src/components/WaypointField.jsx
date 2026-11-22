'use client';

import { useEffect, useRef } from 'react';
import './WaypointField.css';

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const smoothstep = t => {
  const x = clamp(t, 0, 1);
  return x * x * (3 - 2 * x);
};

const hash = (x, y) => {
  let value = Math.imul(x + 0x9e3779b9, 374761393) ^ Math.imul(y + 0x85ebca6b, 668265263);
  value = Math.imul(value ^ (value >>> 13), 1274126177);
  return ((value ^ (value >>> 16)) >>> 0) / 4294967295;
};

const WaypointField = ({
  spacing = 34,
  radius = 190,
  baseOpacity = 0.2,
  pointerOpacity = 0.62,
  revealDuration = 700,
  dpr,
  className = ''
}) => {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const root = canvas?.parentElement;
    if (!canvas || !root) return undefined;

    const context = canvas.getContext('2d', { alpha: true });
    if (!context) return undefined;

    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    const state = {
      width: 0,
      height: 0,
      ratio: 1,
      points: [],
      pointer: { x: 0, y: 0, inside: false },
      target: { x: 0, y: 0 },
      current: { x: 0, y: 0 },
      reveal: reduce ? 1 : 0,
      revealStart: 0,
      visible: false,
      raf: 0,
      last: 0
    };

    const build = () => {
      const width = Math.max(1, root.clientWidth);
      const height = Math.max(1, root.clientHeight);
      const ratio = Math.min(dpr || window.devicePixelRatio || 1, 2);
      state.width = width;
      state.height = height;
      state.ratio = ratio;
      canvas.width = Math.max(1, Math.round(width * ratio));
      canvas.height = Math.max(1, Math.round(height * ratio));
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      context.setTransform(ratio, 0, 0, ratio, 0, 0);

      const size = Math.max(18, spacing);
      const offsetX = (width % size) / 2;
      const offsetY = (height % size) / 2;
      const points = [];
      let column = 0;
      for (let x = offsetX; x <= width; x += size, column++) {
        let row = 0;
        for (let y = offsetY; y <= height; y += size, row++) {
          const noise = hash(column, row);
          if (noise < 0.08) continue;
          const major = column % 4 === 0 && row % 4 === 0;
          points.push({
            x,
            y,
            major,
            weight: 0.48 + noise * 0.52
          });
        }
      }
      state.points = points;
    };

    const edgeFade = (x, y) => {
      const horizontal = smoothstep(Math.min(x, state.width - x) / (state.width * 0.18));
      const vertical = smoothstep(Math.min(y, state.height - y) / (state.height * 0.2));
      return horizontal * vertical;
    };

    const draw = () => {
      const { points, width, height, ratio } = state;
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      context.clearRect(0, 0, width, height);
      if (!points.length) return;

      const progress = reduce ? 1 : smoothstep(state.reveal);
      const radiusSq = radius * radius;
      const pointerX = state.current.x;
      const pointerY = state.current.y;
      const pointerActive = state.pointer.inside && !reduce;

      context.fillStyle = '#ffffff';
      for (const point of points) {
        const edge = edgeFade(point.x, point.y);
        if (edge <= 0) continue;

        let alpha = baseOpacity * point.weight * edge;
        let dotRadius = point.major ? 1.05 : 0.62;

        if (pointerActive) {
          const dx = point.x - pointerX;
          const dy = point.y - pointerY;
          const distanceSq = dx * dx + dy * dy;
          if (distanceSq < radiusSq) {
            const distance = Math.sqrt(distanceSq);
            const glow = 1 - distance / radius;
            const falloff = glow * glow * (3 - 2 * glow);
            const boost = falloff * pointerOpacity;
            alpha = Math.max(alpha, boost * edge);
            dotRadius += falloff * 1.35;
          }
        }

        alpha *= progress;
        if (alpha < 0.004) continue;
        context.globalAlpha = Math.min(1, alpha);
        context.beginPath();
        context.arc(point.x, point.y, dotRadius, 0, Math.PI * 2);
        context.fill();
      }
      context.globalAlpha = 1;
    };

    const frame = now => {
      state.raf = 0;
      if (!state.visible || document.hidden) return;
      const delta = state.last ? clamp((now - state.last) / 1000, 0, 1 / 20) : 1 / 60;
      state.last = now;

      if (state.reveal < 1 && !reduce) {
        state.reveal = Math.min(1, state.reveal + delta / (revealDuration / 1000));
      }

      const follow = 1 - Math.exp(-delta / 0.075);
      state.current.x += (state.target.x - state.current.x) * follow;
      state.current.y += (state.target.y - state.current.y) * follow;

      draw();

      const moving = Math.abs(state.current.x - state.target.x) + Math.abs(state.current.y - state.target.y) > 0.25;
      if (state.reveal < 1 || moving) state.raf = requestAnimationFrame(frame);
    };

    const wake = () => {
      if (!state.raf && state.visible && !document.hidden) {
        state.last = 0;
        state.raf = requestAnimationFrame(frame);
      }
    };

    const reveal = () => {
      if (reduce) {
        state.reveal = 1;
        draw();
        return;
      }
      state.reveal = 0;
      state.last = 0;
      wake();
    };

    const locate = event => {
      const rect = root.getBoundingClientRect();
      return {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
        inside: event.clientX >= rect.left && event.clientX <= rect.right && event.clientY >= rect.top && event.clientY <= rect.bottom
      };
    };

    const onPointerMove = event => {
      if (!state.visible) return;
      const point = locate(event);
      state.pointer.inside = point.inside;
      if (!point.inside) return;
      state.target.x = point.x;
      state.target.y = point.y;
      wake();
    };

    const onPointerLeave = () => {
      state.pointer.inside = false;
      wake();
    };

    const onVisibility = () => {
      if (!document.hidden) wake();
    };

    const resizeObserver = new ResizeObserver(() => {
      build();
      draw();
      if (state.visible) wake();
    });
    resizeObserver.observe(root);

    const intersection = new IntersectionObserver(
      entries => {
        const entry = entries[0];
        state.visible = Boolean(entry?.isIntersecting);
        if (state.visible) {
          if (state.reveal < 1) reveal();
          else wake();
        } else if (state.raf) {
          cancelAnimationFrame(state.raf);
          state.raf = 0;
        }
      },
      { rootMargin: '120px' }
    );
    intersection.observe(root);

    window.addEventListener('pointermove', onPointerMove, { passive: true });
    document.documentElement.addEventListener('pointerleave', onPointerLeave);
    document.addEventListener('visibilitychange', onVisibility);

    build();
    draw();
    root.dataset.ready = 'true';

    return () => {
      if (state.raf) cancelAnimationFrame(state.raf);
      resizeObserver.disconnect();
      intersection.disconnect();
      window.removeEventListener('pointermove', onPointerMove);
      document.documentElement.removeEventListener('pointerleave', onPointerLeave);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [baseOpacity, dpr, pointerOpacity, radius, revealDuration, spacing]);

  return (
    <>
      <canvas ref={canvasRef} className={`waypoint-field__canvas${className ? ` ${className}` : ''}`} aria-hidden="true" />
      <div className="waypoint-field__fallback" aria-hidden="true" />
    </>
  );
};

export default WaypointField;
