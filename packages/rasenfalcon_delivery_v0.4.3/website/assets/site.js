'use strict';
(function(){
  const toggle=document.getElementById('menu-button');
  const nav=document.getElementById('primary-navigation');
  if(!toggle||!nav)return;
  toggle.addEventListener('click',()=>{const open=toggle.getAttribute('aria-expanded')!=='true';toggle.setAttribute('aria-expanded',String(open));nav.dataset.open=String(open)});
  nav.addEventListener('click',event=>{if(event.target.closest('a')){toggle.setAttribute('aria-expanded','false');nav.dataset.open='false'}});
})();
