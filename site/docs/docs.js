/* KaadzOS documentation behaviour.
   Progressive enhancement only: every section is readable without this file.
   Adds the mobile contents drawer, search, scrollspy, heading anchors and
   copy buttons. No dependencies. */

document.documentElement.classList.add('js');

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const article = $('.docs-article');
const side = $('.docs-side');
const menu = $('.docs-menu');

/* ------------------------------------------------------------ mobile nav */
if (menu && side) {
  menu.addEventListener('click', () => {
    const open = side.dataset.open === 'true';
    side.dataset.open = String(!open);
    menu.setAttribute('aria-expanded', String(!open));
  });

  side.addEventListener('click', (event) => {
    if (!event.target.closest('a')) return;
    if (!window.matchMedia('(max-width: 900px)').matches) return;
    side.dataset.open = 'false';
    menu.setAttribute('aria-expanded', 'false');
  });
}

/* --------------------------------------------------------------- headings */
const headings = article ? $$('h2[id], h3[id]', article) : [];
const sectionFor = (heading) => heading.closest('section');

// Search targets: h2 sections by their section id (the sidebar anchors), h3
// subsections by their own id.
const searchEntries = headings.map((heading) => {
  const section = sectionFor(heading);
  const groupHeading = section ? $('h2', section) : null;
  return {
    id: heading.tagName === 'H2' && section?.id ? section.id : heading.id,
    title: heading.textContent.trim(),
    group: groupHeading ? groupHeading.textContent.trim() : '',
    text: (section || heading).textContent.replace(/\s+/g, ' ').trim()
  };
});

// Add a quiet permalink to every heading after the index is built.
for (const heading of headings) {
  const section = sectionFor(heading);
  const target = heading.tagName === 'H2' && section?.id ? section.id : heading.id;
  const anchor = document.createElement('a');
  anchor.className = 'anchor';
  anchor.href = '#' + target;
  anchor.setAttribute('aria-label', 'Link to ' + heading.textContent.trim());
  anchor.textContent = '#';
  heading.append(anchor);
}

/* ----------------------------------------------------------------- search */
const search = $('.docs-search');
const input = $('#docs-search-input');
const results = $('#docs-search-results');

function highlight(text, query) {
  const fragment = document.createDocumentFragment();
  if (!query) {
    fragment.append(text);
    return fragment;
  }
  const lower = text.toLowerCase();
  let cursor = 0;
  while (cursor < text.length) {
    const at = lower.indexOf(query, cursor);
    if (at === -1) {
      fragment.append(text.slice(cursor));
      break;
    }
    if (at > cursor) fragment.append(text.slice(cursor, at));
    const mark = document.createElement('mark');
    mark.textContent = text.slice(at, at + query.length);
    fragment.append(mark);
    cursor = at + query.length;
  }
  return fragment;
}

function snippetFor(entry, query) {
  const lower = entry.text.toLowerCase();
  const at = lower.indexOf(query);
  if (at === -1) return '';
  const start = Math.max(0, at - 42);
  const end = Math.min(entry.text.length, at + query.length + 92);
  return (start > 0 ? '…' : '') + entry.text.slice(start, end).trim() + (end < entry.text.length ? '…' : '');
}

function renderResults(query) {
  if (!results) return;
  results.replaceChildren();

  if (!query) {
    results.hidden = true;
    return;
  }

  const matches = searchEntries
    .map((entry) => {
      const title = entry.title.toLowerCase();
      const text = entry.text.toLowerCase();
      let score = 0;
      if (title === query) score = 4;
      else if (title.startsWith(query)) score = 3;
      else if (title.includes(query)) score = 2;
      else if (text.includes(query)) score = 1;
      return { entry, score };
    })
    .filter((match) => match.score > 0)
    .sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title))
    .slice(0, 10);

  if (matches.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'docs-result-empty';
    empty.textContent = 'No sections match “' + query + '”.';
    results.append(empty);
  } else {
    for (const { entry } of matches) {
      const link = document.createElement('a');
      link.href = '#' + entry.id;

      const group = document.createElement('span');
      group.className = 'docs-result-group mono';
      group.textContent = entry.group;

      const title = document.createElement('span');
      title.className = 'docs-result-title';
      title.append(highlight(entry.title, query));

      link.append(group, title);

      const snippet = snippetFor(entry, query);
      if (snippet) {
        const detail = document.createElement('span');
        detail.className = 'docs-result-snippet';
        detail.append(highlight(snippet, query));
        link.append(detail);
      }

      link.addEventListener('click', () => {
        results.hidden = true;
        if (window.matchMedia('(max-width: 900px)').matches && menu && side) {
          side.dataset.open = 'false';
          menu.setAttribute('aria-expanded', 'false');
        }
      });

      results.append(link);
    }
  }

  results.hidden = false;
}

if (input && results && search) {
  input.addEventListener('input', () => {
    renderResults(input.value.trim().toLowerCase());
  });

  input.addEventListener('focus', () => {
    const query = input.value.trim().toLowerCase();
    if (query) renderResults(query);
  });

  input.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      input.value = '';
      results.hidden = true;
      input.blur();
    }
    if (event.key === 'Enter') {
      const first = results.querySelector('a');
      if (first) {
        event.preventDefault();
        first.click();
        window.location.hash = first.getAttribute('href');
      }
    }
  });

  document.addEventListener('click', (event) => {
    if (!search.contains(event.target)) results.hidden = true;
  });

  document.addEventListener('keydown', (event) => {
    const target = event.target;
    const typing = target instanceof HTMLElement
      && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable);
    if (event.key === '/' && !typing && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault();
      input.focus();
      input.select();
    }
  });
}

/* ------------------------------------------------------------- scrollspy */
const sections = article ? $$('section[id]', article) : [];
const navLinks = $$('.docs-side a[href^="#"], .docs-toc a[href^="#"]');

let frame = 0;

function updateActive() {
  frame = 0;
  if (sections.length === 0) return;

  const line = window.scrollY + 120;
  let current = sections[0];

  for (const section of sections) {
    if (section.getBoundingClientRect().top + window.scrollY <= line) current = section;
    else break;
  }

  const currentHash = '#' + current.id;
  for (const link of navLinks) {
    if (link.getAttribute('href') === currentHash) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
}

function requestUpdate() {
  if (frame) return;
  frame = window.requestAnimationFrame(updateActive);
}

if (sections.length > 0) {
  window.addEventListener('scroll', requestUpdate, { passive: true });
  window.addEventListener('resize', requestUpdate);
  window.addEventListener('load', requestUpdate);
  updateActive();
}

/* ------------------------------------------------------------- copy code */
function copyText(text) {
  if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text);
  return new Promise((resolve, reject) => {
    const field = document.createElement('textarea');
    field.value = text;
    field.setAttribute('readonly', '');
    field.style.position = 'fixed';
    field.style.top = '-1000px';
    field.style.opacity = '0';
    document.body.append(field);
    field.select();
    try {
      document.execCommand('copy') ? resolve() : reject(new Error('copy failed'));
    } catch (error) {
      reject(error);
    } finally {
      field.remove();
    }
  });
}

for (const button of $$('.code-copy')) {
  button.addEventListener('click', async () => {
    const code = $('pre code', button.closest('.code'));
    if (!code) return;
    const label = button.textContent;
    try {
      await copyText(code.innerText.replace(/\s+$/, ''));
      button.textContent = 'Copied';
    } catch {
      button.textContent = 'Copy failed';
    }
    window.setTimeout(() => { button.textContent = label; }, 1600);
  });
}
