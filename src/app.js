document.addEventListener('click', (event) => {
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
