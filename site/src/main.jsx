import { createRoot } from 'react-dom/client';

import CursorGrid from './components/CursorGrid';
import FlowingMenu from './components/FlowingMenu';
import GradientASCII from './components/GradientASCII';
import TechText from './components/TechText';

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

const gridMount = document.getElementById('cursor-grid');
if (gridMount) {
  createRoot(gridMount).render(
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <CursorGrid
        cellSize={36}
        color="#ffffff"
        highlight="area"
        gridStyle="lines"
        radius={150}
        holdTime={500}
        fadeDuration={1100}
        fillOpacity={0.025}
        gridOpacity={0.03}
        spotlight={0.8}
        ambient={0.015}
        edgeFade={0.24}
        intro={false}
        clickPulse
      />
    </div>
  );
}

const packItems = [
  { text: 'admin', meta: '~45 MB', ariaLabel: 'Admin pack, about 45 MB. Copy the install command.' },
  { text: 'ai', meta: '~5 GB', ariaLabel: 'AI pack, about 5 GB. Copy the install command.' },
  { text: 'android', meta: '~3 GB', ariaLabel: 'Android pack, about 3 GB. Copy the install command.' },
  { text: 'cloudflare', meta: '~60 MB', ariaLabel: 'Cloudflare pack, about 60 MB. Copy the install command.' },
  { text: 'creative', meta: '~3 GB', ariaLabel: 'Creative pack, about 3 GB. Copy the install command.' },
  { text: 'dev', meta: '~900 MB', ariaLabel: 'Dev pack, about 900 MB. Copy the install command.' },
  { text: 'fonts', meta: '~55 MB', ariaLabel: 'Fonts pack, about 55 MB. Copy the install command.' },
  { text: 'gaming', meta: '~2 GB', ariaLabel: 'Gaming pack, about 2 GB. Copy the install command.' },
  { text: 'hardware', meta: '~300 MB', ariaLabel: 'Hardware pack, about 300 MB. Copy the install command.' },
  { text: 'input', meta: '~20 MB', ariaLabel: 'Input pack, about 20 MB. Copy the install command.' },
  { text: 'network', meta: '~40 MB', ariaLabel: 'Network pack, about 40 MB. Copy the install command.' },
  { text: 'opencode', meta: '~250 MB', ariaLabel: 'OpenCode pack, about 250 MB. Copy the install command.' },
  { text: 'printing', meta: '~250 MB', ariaLabel: 'Printing pack, about 250 MB. Copy the install command.' },
  { text: 'privacy', meta: '~150 MB', ariaLabel: 'Privacy pack, about 150 MB. Copy the install command.' },
  { text: 'security', meta: '~10 MB', ariaLabel: 'Security pack, about 10 MB. Copy the install command.' },
  { text: 'windows', meta: '~4 GB', ariaLabel: 'Windows pack, about 4 GB. Copy the install command.' }
];

const packColumns = [packItems.slice(0, 8), packItems.slice(8)];

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

const packMenuProps = {
  speed: 75,
  stretch: 0.3,
  magnet: 0.06,
  followCursor: 0.4,
  textColor: '#ffffff',
  bgColor: '#000000',
  marqueeBgColor: '#ffffff',
  marqueeTextColor: '#000000',
  borderColor: 'rgba(255, 255, 255, 0.16)',
  direction: 'alternate',
  duration: 0.45,
  bandInset: 0,
  bandRadius: 0,
  carryContent: false,
  dividers: true,
  dimInactive: true,
  align: 'left',
  showIndex: true,
  showArrow: false,
  intro: false
};

const packsMount = document.getElementById('packs-menu');
if (packsMount) {
  createRoot(packsMount).render(
    <div className="packs-menu__columns">
      {packColumns.map((items, column) => (
        <FlowingMenu
          key={column}
          items={items}
          startIndex={column * 8}
          ariaLabel={`Packs ${column * 8 + 1} to ${column * 8 + items.length}. Select a pack to copy its install command.`}
          {...packMenuProps}
          onItemClick={copyPackCommand}
        />
      ))}
    </div>
  );
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
