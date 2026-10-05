{{flutter_js}}
{{flutter_build_config}}

// Engine assets ship with the release. Do not depend on an external CanvasKit CDN.
const studioConfiguration = {
  canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
};
const loading = document.getElementById('studio-loading');
const status = document.getElementById('studio-loading-status');
document.getElementById('studio-retry')?.addEventListener('click', () => location.reload());
_flutter.loader.load({
  config: studioConfiguration,
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const runner = await engineInitializer.initializeEngine(studioConfiguration);
      await runner.runApp();
      loading?.remove();
    } catch (error) {
      if (status) status.textContent = 'The studio could not start. Check your connection and reload.';
      const retry = document.getElementById('studio-retry');
      if (retry) retry.hidden = false;
      console.error('Aureon initialization failed.', error);
    }
  },
}).catch((error) => {
  if (status) status.textContent = 'The studio could not load. Check the release files and reload.';
  const retry = document.getElementById('studio-retry');
  if (retry) retry.hidden = false;
  console.error('Aureon entrypoint failed.', error);
});
