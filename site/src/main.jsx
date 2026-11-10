import { createRoot } from 'react-dom/client';

import GradientASCII from './components/GradientASCII';
import TechText from './components/TechText';

const asciiMount = document.getElementById('ascii-hero');
if (asciiMount) {
  createRoot(asciiMount).render(
    <GradientASCII
      colors={['#1e3fd8', '#f6f8ff', '#a5d8ff', '#38bdf8']}
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
