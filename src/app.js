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

  const link = event.target.closest('a.download-link');
  if (!link || link.getAttribute('aria-disabled') === 'true') return;
  event.preventDefault();
  window.location.assign(link.href);
});

function syncView() {
  const home = !location.hash || location.hash === '#/' || location.hash.startsWith('#/?');
  document.body.classList.toggle('home-view', home);

  const headerBrand = document.querySelector('.site-header a.brand');
  const appName = document.querySelector('.sidebar .app-name');
  const sidebarBrand = appName?.querySelector('a');
  if (headerBrand && sidebarBrand && !sidebarBrand.classList.contains('brand')) {
    sidebarBrand.replaceWith(headerBrand.cloneNode(true));
  }

  const search = document.querySelector('.sidebar .search');
  if (appName && search && appName.nextElementSibling !== search) appName.after(search);
}

syncView();
window.addEventListener('load', syncView);
window.addEventListener('hashchange', syncView);
