import { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';

import FlowingMenu from './components/FlowingMenu';
import GradientASCII from './components/GradientASCII';
import TechText from './components/TechText';
import WaypointField from './components/WaypointField';
import { setupSiteMotion } from './motion';

const asciiMount = document.getElementById('ascii-hero');
if (asciiMount) {
  createRoot(asciiMount).render(
    <GradientASCII
      colors={['#000000', '#ffffff', '#ffffff', '#000000']}
      shape="horizon"
      characters=" =+xX0S8#@"
      cellSize={18}
      density={0.8}
      glyphOpacity={0.85}
      glow={0.2}
      depthOfField={0}
      flicker={0.2}
      softness={0.5}
      scale={1}
      flow={0.5}
      speed={1}
      gradientOpacity={0.9}
      grain={0.08}
      variation={0}
      mouseInteraction
      scrambleRadius={0.1}
      clickEffect="wave"
      intro
      lightMode={false}
      aria-hidden="true"
    />
  );
}

const waypointMount = document.getElementById('waypoint-field');
if (waypointMount) {
  createRoot(waypointMount).render(
    <WaypointField spacing={34} radius={190} baseOpacity={0.22} pointerOpacity={0.62} revealDuration={700} />
  );
}

const pack = (text, meta) => ({
  text,
  meta,
  ariaLabel: `${text} pack, about ${meta}. Copy the install command.`
});

const packGroups = [
  {
    label: 'Build',
    startIndex: 0,
    items: [
      pack('ai', '~5 GB'),
      pack('dev', '~900 MB'),
      pack('opencode', '~250 MB'),
      pack('cloudflare', '~60 MB')
    ]
  },
  {
    label: 'Play',
    startIndex: 4,
    items: [
      pack('gaming', '~2 GB'),
      pack('creative', '~3 GB'),
      pack('android', '~3 GB'),
      pack('windows', '~4 GB')
    ]
  },
  {
    label: 'Tune',
    startIndex: 8,
    items: [
      pack('admin', '~45 MB'),
      pack('hardware', '~300 MB'),
      pack('network', '~40 MB'),
      pack('printing', '~250 MB')
    ]
  },
  {
    label: 'Extend',
    startIndex: 12,
    items: [
      pack('privacy', '~150 MB'),
      pack('security', '~10 MB'),
      pack('fonts', '~55 MB'),
      pack('input', '~20 MB')
    ]
  }
];

const packMenuProps = {
  speed: 55,
  stretch: 0.24,
  magnet: 0.04,
  followCursor: 0.3,
  textColor: '#ffffff',
  bgColor: '#000000',
  marqueeBgColor: '#070707',
  marqueeTextColor: '#ffffff',
  borderColor: 'rgba(255, 255, 255, 0.16)',
  direction: 'alternate',
  duration: 0.38,
  bandInset: 0,
  bandRadius: 0,
  carryContent: false,
  dividers: true,
  dimInactive: true,
  align: 'left',
  showIndex: true,
  showArrow: false,
  intro: false,
  bandPrefix: 'kaadzos add ',
  showCopy: true
};

let packStatusTimer;
const copyPackCommand = async item => {
  const command = `kaadzos add ${item.text}`;
  const status = document.getElementById('pack-copy-status');
  let copied = false;

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(command);
      copied = true;
    }
  } catch {
    copied = false;
  }

  if (!copied) {
    const field = document.createElement('textarea');
    field.value = command;
    field.setAttribute('readonly', '');
    field.style.position = 'fixed';
    field.style.top = '-1000px';
    field.style.opacity = '0';
    document.body.appendChild(field);
    field.select();
    try {
      copied = document.execCommand('copy');
    } catch {
      copied = false;
    }
    field.remove();
  }

  if (!status) return;
  clearTimeout(packStatusTimer);
  status.textContent = copied ? `Copied — ${command}` : `Run ${command}`;
  status.classList.add('is-visible');
  packStatusTimer = setTimeout(() => {
    status.classList.remove('is-visible');
    packStatusTimer = setTimeout(() => {
      status.textContent = '';
    }, 300);
  }, 3600);
};

function PacksMenu() {
  const rootRef = useRef(null);
  const [entered, setEntered] = useState(false);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return undefined;
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
      setEntered(true);
      return undefined;
    }
    const observer = new IntersectionObserver(
      entries => {
        if (!entries.some(entry => entry.isIntersecting)) return;
        setEntered(true);
        observer.disconnect();
      },
      { rootMargin: '0px 0px -12% 0px', threshold: 0.12 }
    );
    observer.observe(root);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={rootRef} className="packs-menu__columns" data-entrance={entered ? 'in' : 'pending'}>
      {[0, 1].map(column => (
        <div className="packs-column" key={column}>
          {packGroups.slice(column * 2, column * 2 + 2).map((group, index) => {
            const groupIndex = column * 2 + index;
            return (
              <section
                className="pack-group"
                key={group.label}
                style={{ '--enter-delay': `${groupIndex * 90}ms` }}
                aria-labelledby={`pack-group-${group.label.toLowerCase()}`}
              >
                <p className="mono pack-group-label" id={`pack-group-${group.label.toLowerCase()}`}>
                  {group.label}
                </p>
                <FlowingMenu
                  items={group.items}
                  startIndex={group.startIndex}
                  ariaLabel={`${group.label} packs. Select a pack to copy its install command.`}
                  {...packMenuProps}
                  onItemClick={copyPackCommand}
                />
              </section>
            );
          })}
        </div>
      ))}
    </div>
  );
}

const packsMount = document.getElementById('packs-menu');
if (packsMount) {
  createRoot(packsMount).render(<PacksMenu />);
}

const footerMount = document.getElementById('footer-tech');
if (footerMount) {
  createRoot(footerMount).render(
    <TechText
      text="KAADZOS"
      fontWeight={600}
      fontSize={150}
      reveal="letter"
      dashLength={4}
      dashGap={2}
      specks={15}
      intro="none"
      introDuration={2}
      clickKick
      guides={false}
      fontFamily=""
      letterSpacing={-0.05}
      accentColor="currentColor"
      reach={200}
      softness={0.7}
      lineStyle="dashed"
      strokeWidth={1.5}
      speed={1}
      bounce={0.4}
      selection
      labels
      color="currentColor"
      align="center"
      draggable
      sweep
    />
  );
}

setupSiteMotion();
