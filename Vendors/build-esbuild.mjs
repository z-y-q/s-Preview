import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: ['node_modules/highlight.js/lib/index.js'],
  bundle: true, minify: true, format: 'iife', globalName: 'hljs',
  outfile: '../Resources/Viewer/vendor/hljs.js',
  logLevel: 'silent',
});

await esbuild.build({
  entryPoints: ['entry-three.js'],
  bundle: true, minify: true, format: 'iife',
  outfile: '../Resources/Viewer/vendor/three-viewer.js',
  logLevel: 'silent',
});

console.log('esbuild done');
