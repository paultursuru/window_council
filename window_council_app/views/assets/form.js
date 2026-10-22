// Readings form: result of the last submission, kept values after an error,
// and a reload every 5 min unless a reading is being typed.
(() => {
  const form = document.getElementById('reading-form');
  const status = document.getElementById('form-status');
  const params = new URLSearchParams(location.search);
  if (location.protocol === 'file:') {
    // Opened as a file: nothing to post to
    form.hidden = true;
    document.getElementById('form-offline').hidden = false;
  }
  if (params.has('ok')) {
    status.textContent = `Relevé de ${params.get('ok')} enregistré.`;
    status.className = 'status ok';
  }
  if (params.has('erreur')) {
    status.textContent = params.get('erreur');
    status.className = 'status error';
    ['temperature', 'humidity', 'time', 'windows'].forEach(name => {
      if (params.has(name)) form.elements[name].value = params.get(name);
    });
  }
  if (location.search) history.replaceState(null, '', location.pathname + location.hash);

  const typing = () => form.contains(document.activeElement) ||
    ['temperature', 'humidity', 'time'].some(name => form.elements[name].value);
  setInterval(() => { if (!typing()) location.reload(); }, 300e3);
})();
