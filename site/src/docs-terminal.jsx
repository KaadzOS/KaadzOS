import { createRoot } from 'react-dom/client';

import FaultyTerminal from './components/FaultyTerminal';

const mount = document.getElementById('docs-terminal');
if (mount) {
  createRoot(mount).render(
    <FaultyTerminal
      tint="#1c1d1f"
      glyphs="characters"
      scale={2.1}
      digitSize={1.15}
      timeScale={0.4}
      brightness={1.2}
      glow={1.35}
      persistence={0.5}
      mouseStrength={0.3}
      mouseGlow={0.25}
      curvature={0.44}
      vignette={0.22}
      clickEffect="glitch"
      scramble={0.9}
      scanlineIntensity={0.5}
      glitchAmount={1}
      flickerAmount={1}
      noiseAmp={1}
      chromaticAberration={0}
      mouseReact
      pageLoadAnimation
      pause={false}
      lightMode={false}
    />
  );
}
