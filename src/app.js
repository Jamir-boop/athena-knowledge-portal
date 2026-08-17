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
  const sidebarBrand = document.querySelector('.sidebar .app-name a');
  if (headerBrand && sidebarBrand && !sidebarBrand.classList.contains('brand')) {
    sidebarBrand.replaceWith(headerBrand.cloneNode(true));
  }
}

syncView();
window.addEventListener('load', syncView);
window.addEventListener('hashchange', syncView);
