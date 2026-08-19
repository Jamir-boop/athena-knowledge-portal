let pageTreeItems = [];

function updatePageTreeCurrent() {
  if (!pageTreeItems.length) return;
  const current = [...pageTreeItems].reverse().find(({ heading }) => heading.getBoundingClientRect().top <= 120) || pageTreeItems[0];
  pageTreeItems.forEach(({ link }) => link.removeAttribute('aria-current'));
  current.link.setAttribute('aria-current', 'location');
}

function buildPageTree() {
  document.querySelector('.page-tree')?.remove();
  document.body.classList.remove('has-page-tree');
  pageTreeItems = [];

  const route = decodeURIComponent(location.hash.slice(1).split('?')[0]);
  const article = document.querySelector('.markdown-section');
  if (!route.startsWith('/content/') || !article) return;

  const headings = [...article.querySelectorAll('h1[id],h2[id],h3[id]')];
  if (!headings.length) return;

  const nav = document.createElement('nav');
  nav.className = 'page-tree';
  nav.setAttribute('aria-label', 'En esta p\u00e1gina');

  const details = document.createElement('details');
  details.open = matchMedia('(min-width: 1200px)').matches;
  const summary = document.createElement('summary');
  summary.textContent = 'En esta p\u00e1gina';
  const list = document.createElement('ol');

  headings.forEach((heading) => {
    const item = document.createElement('li');
    item.className = `page-tree__level-${heading.tagName.slice(1)}`;
    const link = document.createElement('a');
    link.href = heading.querySelector('a.anchor')?.getAttribute('href') || `#${heading.id}`;
    link.textContent = heading.textContent.trim();
    item.append(link);
    list.append(item);
    pageTreeItems.push({ heading, link });
  });

  details.append(summary, list);
  nav.append(details);
  article.insertBefore(nav, article.querySelector('h1') || article.firstChild);
  document.body.classList.add('has-page-tree');
  updatePageTreeCurrent();
}

document.addEventListener('click', async (event) => {
  const pageTreeLink = event.target.closest('.page-tree a');
  if (pageTreeLink && !matchMedia('(min-width: 1200px)').matches) pageTreeLink.closest('details').open = false;

  const copyButton = event.target.closest('button.copy-page');
  if (copyButton) {
    const label = copyButton.querySelector('span');
    try {
      const route = decodeURIComponent(location.hash.slice(1).split('?')[0]);
      const response = await fetch(route.endsWith('.md') ? route : `${route}.md`);
      if (!response.ok) throw new Error(`Article request failed: ${response.status}`);
      await navigator.clipboard.writeText(await response.text());
      copyButton.classList.add('copied');
      label.textContent = 'Copiado';
      setTimeout(() => {
        if (!copyButton.isConnected) return;
        copyButton.classList.remove('copied');
        label.textContent = 'Copiar página';
      }, 2000);
    } catch {
      label.textContent = 'No se pudo copiar';
    }
    return;
  }

});

const normalize = (value) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

function filterGuides() {
  const library = document.querySelector('.guide-library');
  if (!library) return;
  const query = normalize(document.querySelector('#guide-filter')?.value.trim() || '');
  const tag = normalize(document.querySelector('#guide-tag')?.value || '');
  let visible = 0;
  library.querySelectorAll('.library-card').forEach((card) => {
    const matchesText = !query || normalize(card.dataset.search || '').includes(query);
    const matchesTag = !tag || (card.dataset.tags || '').split('|').some((value) => normalize(value) === tag);
    card.hidden = !(matchesText && matchesTag);
    if (!card.hidden) visible += 1;
  });
  const count = document.querySelector('#guide-count');
  const empty = document.querySelector('.library-empty');
  if (count) count.textContent = `${visible} ${visible === 1 ? 'resultado' : 'resultados'}`;
  if (empty) empty.hidden = visible !== 0;
}

function syncView() {
  const home = !location.hash || location.hash === '#/' || location.hash.startsWith('#/?');
  document.body.classList.toggle('home-view', home);

  const headerBrand = document.querySelector('#brand-source .brand');
  const appName = document.querySelector('.sidebar .app-name');
  const sidebarBrand = appName?.querySelector('a');
  if (headerBrand && sidebarBrand && !sidebarBrand.classList.contains('brand')) {
    sidebarBrand.replaceWith(headerBrand.cloneNode(true));
  }

  const search = document.querySelector('.search');
  const homeSlot = document.querySelector('#home-search-slot');
  if (home && search && homeSlot && search.parentElement !== homeSlot) homeSlot.append(search);
  if (!home && appName && search && appName.nextElementSibling !== search) appName.after(search);
  filterGuides();
  buildPageTree();
}

window.athenaSyncView = syncView;
syncView();
window.addEventListener('load', syncView);
window.addEventListener('hashchange', syncView);
window.addEventListener('scroll', updatePageTreeCurrent, { passive: true });
document.addEventListener('input', (event) => {
  if (event.target.matches('#guide-filter')) filterGuides();
});
document.addEventListener('change', (event) => {
  if (event.target.matches('#guide-tag')) filterGuides();
});
