import { createRoot } from 'react-dom/client';

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
      density={0.85}
      glyphOpacity={0.9}
      glow={0.45}
      depthOfField={0.4}
      flicker={0.35}
      softness={0.6}
      scale={1}
      flow={0.8}
      speed={1.25}
      gradientOpacity={0.9}
      grain={0.12}
      variation={0.5}
      mouseInteraction
      scrambleRadius={0.22}
      clickEffect="wave"
      intro
      lightMode={false}
      aria-hidden="true"
    />
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
