window.$docsify = {
  name: 'ATHENA',
  homepage: 'README.md',
  loadSidebar: true,
  auto2top: true,
  maxLevel: 3,
  subMaxLevel: 2,
  search: {
    namespace: 'athena-v2',
    paths: 'auto',
    placeholder: 'Buscar en Athena',
    noData: 'Sin resultados'
  },
  alias: { '/.*/_sidebar.md': '/_sidebar.md' }
};
