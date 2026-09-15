const buttons = [...document.querySelectorAll('[data-preview-tab]')];
const views = [...document.querySelectorAll('[data-preview-view]')];

function activate(name) {
  for (const button of buttons) {
    const active = button.dataset.previewTab === name;
    button.classList.toggle('active', active);
    button.setAttribute('aria-selected', active ? 'true' : 'false');
  }
  for (const view of views) {
    const active = view.dataset.previewView === name;
    view.hidden = !active;
  }
  const heading = document.querySelector(`[data-preview-view="${name}"] h1`);
  if (heading) document.title = `Federation Bank Australia IOM · Merchant Bank · ${heading.textContent}`;
}

for (const button of buttons) button.addEventListener('click', () => activate(button.dataset.previewTab));
activate('overview');
