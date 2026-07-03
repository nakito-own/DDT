{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});

window.addEventListener('flutter-first-frame', function () {
  if (window.ddtSyncFlutterViewport) {
    window.ddtSyncFlutterViewport();
  }

  const splash = document.getElementById('ddt-splash');
  if (!splash) {
    return;
  }

  splash.classList.add('ddt-splash--hide');
  window.setTimeout(function () {
    splash.remove();
  }, 350);
});
