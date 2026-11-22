const dialog = document.querySelector('#demo-dialog');
const video = dialog?.querySelector('video');
let lastTrigger;
document.querySelectorAll('[data-play-demo]').forEach(button => {
  button.addEventListener('click', () => {
    lastTrigger = button;
    dialog.showModal();
    video.play().catch(() => {});
  });
});
dialog?.querySelector('[data-close-dialog]').addEventListener('click', () => dialog.close());
dialog?.addEventListener('click', event => {
  const box = dialog.getBoundingClientRect();
  if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) dialog.close();
});
dialog?.addEventListener('close', () => {
  video.pause();
  lastTrigger?.focus();
});

const tabs = [...document.querySelectorAll('[data-preview-state]')];
const preview = document.querySelector('[data-interface-preview]');
const previewWebp = document.querySelector('[data-interface-preview-webp]');
const panel = document.querySelector('#interface-panel');
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => {
    tabs.forEach(item => {
      const selected = item === tab;
      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
    });
    const state = tab.dataset.previewState;
    if (previewWebp) previewWebp.srcset = previewWebp.dataset[state];
    preview.src = preview.dataset[state];
    preview.width = Number(preview.dataset[state + 'Width']);
    preview.height = Number(preview.dataset[state + 'Height']);
    preview.alt = tab.dataset.imageAlt;
    panel.setAttribute('aria-labelledby', tab.id);
  });
  tab.addEventListener('keydown', event => {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    event.preventDefault();
    const next = event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
    tabs[next].click();
    tabs[next].focus();
  });
});
