const REDUCED = '(prefers-reduced-motion: reduce)';
const ENTER_EASE = 'cubic-bezier(0.22, 1, 0.36, 1)';

const sectionLabels = {
  image: '01 / The image',
  desktop: '02 / The desktop',
  packs: '03 / The packs',
  proof: '04 / The proof',
  download: '05 / Download'
};

const copyText = async value => {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(value);
      return true;
    }
  } catch {
    // Fall through to the selection-based path.
  }

  const field = document.createElement('textarea');
  field.value = value;
  field.setAttribute('readonly', '');
  field.style.position = 'fixed';
  field.style.top = '-1000px';
  field.style.opacity = '0';
  document.body.appendChild(field);
  field.select();
  let copied = false;
  try {
    copied = document.execCommand('copy');
  } catch {
    copied = false;
  }
  field.remove();
  return copied;
};

const setupReveals = () => {
  if (window.matchMedia?.(REDUCED).matches || !('IntersectionObserver' in window)) return;
  const chapters = [...document.querySelectorAll('.chapter-body.reveal')];
  if (!chapters.length) return;

  const observer = new IntersectionObserver(
    entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        observer.unobserve(entry.target);
        entry.target.dataset.revealed = 'true';
        const children = [...entry.target.children];
        children.forEach((child, index) => {
          if (!(child instanceof HTMLElement)) return;
          child.animate(
            [
              { opacity: 0, transform: 'translate3d(0, 16px, 0)' },
              { opacity: 1, transform: 'translate3d(0, 0, 0)' }
            ],
            {
              duration: 760,
              delay: index * 45,
              easing: ENTER_EASE,
              fill: 'backwards'
            }
          );
        });
      });
    },
    { rootMargin: '0px 0px -14% 0px', threshold: 0.08 }
  );
  chapters.forEach(chapter => observer.observe(chapter));
};

const setupMasthead = () => {
  const current = document.getElementById('masthead-current');
  const progress = document.documentElement;
  const sections = [...document.querySelectorAll('main section[id]')];
  const links = [...document.querySelectorAll('.masthead-nav a[href^="#"]')];
  if (!sections.length) return;

  const activate = id => {
    if (current) current.textContent = sectionLabels[id] || '00 / Top';
    links.forEach(link => {
      if (link.getAttribute('href') === `#${id}`) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    });
  };

  let ticking = false;
  const update = () => {
    ticking = false;
    const max = document.documentElement.scrollHeight - window.innerHeight;
    const ratio = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    progress.style.setProperty('--scroll-progress', ratio.toFixed(5));
    const marker = window.scrollY + window.innerHeight * 0.24;
    let positional = null;
    sections.forEach(section => {
      if (section.getBoundingClientRect().top + window.scrollY <= marker) positional = section.id;
    });
    activate(window.scrollY < 40 ? null : positional);
  };
  const requestUpdate = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(update);
  };

  const observer = new IntersectionObserver(
    entries => {
      const visible = entries.filter(entry => entry.isIntersecting);
      if (!visible.length) return;
      const best = visible.sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      activate(best.target.id);
      requestUpdate();
    },
    { rootMargin: '-12% 0px -62% 0px', threshold: [0, 0.01, 0.2, 0.5, 1] }
  );
  sections.forEach(section => observer.observe(section));

  window.addEventListener('scroll', requestUpdate, { passive: true });
  window.addEventListener('scrollend', requestUpdate, { passive: true });
  window.addEventListener('resize', requestUpdate, { passive: true });
  requestUpdate();
};

const setupCopyButtons = () => {
  document.querySelectorAll('[data-copy]').forEach(button => {
    button.addEventListener('click', async () => {
      const value = button.getAttribute('data-copy');
      if (!value) return;
      const original = button.textContent;
      const copied = await copyText(value);
      button.textContent = copied ? 'Copied' : 'Select + copy';
      button.classList.toggle('is-copied', copied);
      window.setTimeout(() => {
        button.textContent = original;
        button.classList.remove('is-copied');
      }, 1800);
    });
  });
};

export const setupSiteMotion = () => {
  setupReveals();
  setupMasthead();
  setupCopyButtons();
};
