document.addEventListener('click', async (event) => {
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

  const headerBrand = document.querySelector('.site-header a.brand');
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
}

window.athenaSyncView = syncView;
syncView();
window.addEventListener('load', syncView);
window.addEventListener('hashchange', syncView);
document.addEventListener('input', (event) => {
  if (event.target.matches('#guide-filter')) filterGuides();
});
document.addEventListener('change', (event) => {
  if (event.target.matches('#guide-tag')) filterGuides();
});
