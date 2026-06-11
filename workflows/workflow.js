// Detailed-workflow page: render Mermaid, then wrap the SVG in svg-pan-zoom.
(async function () {
  if (!window.mermaid) return;

  // Theme-aware Mermaid init (matches host page's data-theme attribute)
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'loose',
    theme: isDark ? 'dark' : 'default',
    flowchart: { curve: 'basis', htmlLabels: true, padding: 14 }
  });

  const el = document.getElementById('diag');
  if (!el) return;

  // Render the diagram
  try { await mermaid.run({ nodes: [el] }); }
  catch (e) { console.error('Mermaid render failed:', e); return; }

  // After render, Mermaid replaces the <pre> content with an inline <svg>
  const svg = el.querySelector('svg');
  if (!svg) return;

  // Make sure the SVG fills its container so pan/zoom feels natural
  svg.removeAttribute('width');
  svg.removeAttribute('height');
  svg.style.width = '100%';
  svg.style.height = '100%';
  svg.style.maxWidth = '100%';

  // Wait one frame so layout settles before measuring
  await new Promise(r => requestAnimationFrame(r));

  if (!window.svgPanZoom) return;
  const panZoom = window.svgPanZoom(svg, {
    zoomEnabled: true,
    controlIconsEnabled: false, // we provide our own toolbar
    fit: true,
    center: true,
    minZoom: 0.3,
    maxZoom: 8,
    zoomScaleSensitivity: 0.25,
    dblClickZoomEnabled: true,
    mouseWheelZoomEnabled: true,
    preventMouseEventsDefault: true
  });

  // Wire toolbar buttons
  document.querySelectorAll('.tbtn').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.getAttribute('data-zoom');
      if (action === 'in') panZoom.zoomBy(1.25);
      else if (action === 'out') panZoom.zoomBy(0.8);
      else if (action === 'reset') { panZoom.resetZoom(); panZoom.center(); panZoom.fit(); }
    });
  });

  // Re-fit on container resize so the diagram stays usable on rotate / resize
  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { panZoom.resize(); panZoom.fit(); panZoom.center(); }, 120);
  });
})();
