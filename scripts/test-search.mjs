import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const context = vm.createContext({
  URL,
  URLSearchParams,
  console,
  location: { hash: '#/' },
  history: { state: null, replaceState() {} },
  matchMedia: () => ({ matches: false }),
  navigator: { clipboard: { writeText() {} } },
  setTimeout() {},
  document: {
    addEventListener() {},
    querySelector() { return null; },
    body: {
      append() {},
      classList: { add() {}, remove() {}, toggle() {} }
    }
  },
  window: { addEventListener() {} }
});

vm.runInContext(readFileSync(new URL('../src/app.js', import.meta.url), 'utf8'), context);

const duplicateIds = context.docsifyHeadingIds('Repeated', [
  { level: 4, title: 'Detail', text: '' },
  { level: 2, title: 'Repeated', text: '' },
  { level: 3, title: 'Detail', text: '' }
]);
assert.equal(duplicateIds.map(({ level, id }) => level + ':' + id).join(','), '2:repeated-1,3:detail-1');

const filler = 'relleno '.repeat(60);
const fold = (value) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
const excerptEntry = context.prepareSearchEntry({
  kind: 'guide',
  title: 'Ejemplo',
  summary: 'Resumen breve',
  author: 'Test',
  tags: ['Solución de problemas'],
  text: 'de ' + filler + 'problemas importantes y solución comprobada',
  headings: [{ level: 2, title: 'Introducción', text: 'de ' + filler }]
});
const excerpt = context.findSnippet(excerptEntry, context.searchTerms('Solución de problemas'));
assert.match(fold(excerpt.text), /problemas/);
assert.equal(excerpt.source, '');

const headingEntry = context.prepareSearchEntry({
  kind: 'guide',
  title: 'Resolver problemas',
  summary: 'Resumen breve',
  author: 'Test',
  tags: ['Solución de problemas'],
  text: 'de detalles adicionales',
  headings: [{ level: 2, title: 'Solución', text: 'de detalles adicionales' }]
});
const headingExcerpt = context.findSnippet(headingEntry, context.searchTerms('Solución de problemas'));
assert.match(fold(headingExcerpt.text), /solucion/);

const metadataEntry = context.prepareSearchEntry({
  kind: 'guide',
  title: 'Ejemplo',
  summary: 'Resumen breve',
  author: 'Test',
  tags: ['Especial'],
  text: 'Contenido sin la etiqueta',
  headings: []
});
const metadata = context.findSnippet(metadataEntry, context.searchTerms('Especial'));
assert.equal(metadata.text, '');
assert.equal(metadata.source, 'Coincidencia en: etiqueta');

console.log('Search logic checks passed.');
