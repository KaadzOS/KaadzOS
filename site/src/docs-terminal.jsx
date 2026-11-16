import { createRoot } from 'react-dom/client';

import FaultyTerminal from './components/FaultyTerminal';

const mount = document.getElementById('docs-terminal');
if (mount) {
  createRoot(mount).render(
    <FaultyTerminal
      tint="#1c1d1f"
      glyphs="characters"
      scale={2.4}
      digitSize={1.1}
      timeScale={0.5}
      brightness={1.25}
      glow={1.5}
      persistence={0.5}
      mouseStrength={0.5}
      mouseGlow={0.6}
      curvature={0.48}
      vignette={0.25}
      clickEffect="glitch"
      scramble={0.9}
      scanlineIntensity={0.5}
      glitchAmount={1}
      flickerAmount={1}
      noiseAmp={1}
      chromaticAberration={0}
      mouseReact={false}
      pageLoadAnimation={false}
      pause={false}
      lightMode={false}
    />
  );
}
