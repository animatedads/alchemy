/* FlyLo public projection v0.4.
   Semantic actions are observable and can be routed to a production endpoint.
   The built-in handler runs ONLY when body[data-demo-mode=true]. */
(() => {
  'use strict';

  const extrasCatalogue = {
    CABIN_BAG: { label: 'A cabin bag that is actually a bag', priceMinor: 2900 },
    CHECKED_BAG: { label: 'Checked bag', priceMinor: 4900 },
    SEAT_SELECTION: { label: 'Choose your seat', priceMinor: 1400 },
    PRIORITY_BOARDING: { label: 'Priority boarding', priceMinor: 900 }
  };

  const state = {
    actionCount: 0,
    saleSeq: 0,
    sale: null,
    lastSearch: null,
    assistantHistory: [],
    manage: null,
    assistantSessionId: (globalThis.crypto?.randomUUID?.() || `flylo-${Date.now()}-${Math.random().toString(36).slice(2)}`)
  };

  const sales = document.querySelector('#sales-process');
  const actionLog = document.querySelector('#action-log');
  const actionCount = document.querySelector('#action-count');
  const assistantPanel = document.querySelector('#assistant-panel');
  const assistantMessages = document.querySelector('#assistant-messages');
  const assistantForm = document.querySelector('#assistant-form');
  const assistantQuestion = document.querySelector('#assistant-question');
  const assistantSend = document.querySelector('#assistant-send');
  const assistantStatus = document.querySelector('#assistant-status');
  const runtimeBuild = document.querySelector('#runtime-build');
  const managePanel = document.querySelector('#manage-process');
  const manageLookupForm = document.querySelector('#manage-lookup-form');
  const manageWorkspace = document.querySelector('#manage-workspace');
  const manageError = document.querySelector('#manage-error');
  const manageContextBadge = document.querySelector('#manage-context-badge');

  const money = minor => new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP' }).format(minor / 100);
  const esc = value => String(value ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));

  function logAction(action, detail) {
    state.actionCount += 1;
    actionCount.textContent = String(state.actionCount);
    const item = document.createElement('li');
    const when = new Date().toISOString().slice(11, 19);
    item.innerHTML = `<strong>${esc(action)}</strong> <time>${when}</time><code>${esc(JSON.stringify(detail))}</code>`;
    actionLog.prepend(item);
    console.info('[FlyLo semantic action]', action, detail);
    document.dispatchEvent(new CustomEvent('flylo:action', { detail: { action, detail, timestamp: new Date().toISOString() } }));
  }

  async function dispatch(action, detail = {}) {
    logAction(action, detail);

    if (typeof window.FlyLoBackendAction === 'function') {
      return window.FlyLoBackendAction(action, detail);
    }

    const endpoint = document.querySelector('meta[name="flylo-action-endpoint"]')?.content?.trim();
    if (endpoint) {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ action, detail })
      });
      const body = await response.json().catch(() => ({}));
      if (!response.ok || !body.ok) {
        const error = new Error(body.message || body.code || `FlyLo action endpoint failed: ${response.status}`);
        error.code = body.code || 'FLYLO_ACTION_FAILED';
        throw error;
      }
      return body.result;
    }

    if (document.body.dataset.demoMode === 'true') return demoAction(action, detail);
    throw new Error('FLYLO_ACTION_ENDPOINT_REQUIRED');
  }

  function demoAction(action, detail) {
    switch (action) {
      case 'FLIGHT.SEARCH': {
        state.lastSearch = detail;
        return {
          source: 'DEMO', offerId: `DEMO-FL101-${detail.date}`, flightNo: 'FL101',
          origin: 'PIK', destination: 'EWR', date: detail.date,
          passengers: detail.passengers, fareMinor: 19900, currency: 'GBP',
          mandatoryChargesIncluded: true, departure: '11:20', arrival: '14:05'
        };
      }
      case 'FLIGHT.SELECT': {
        state.saleSeq += 1;
        state.sale = {
          saleId: `SALE-${String(state.saleSeq).padStart(5, '0')}`,
          state: 'PASSENGERS', offer: detail.offer, passengers: detail.passengers,
          extras: {}, totalMinor: detail.offer.fareMinor * detail.passengers,
          termsVersion: '', paymentStatus: 'NOT_STARTED'
        };
        return structuredClone(state.sale);
      }
      case 'PASSENGER.SAVE':
        state.sale.passengerData = detail.passengers;
        state.sale.state = 'EXTRAS';
        return structuredClone(state.sale);
      case 'ANCILLARY.SAVE': {
        state.sale.extras = detail.selections;
        let extraTotal = 0;
        Object.entries(detail.selections).forEach(([key, selected]) => {
          if (selected) extraTotal += extrasCatalogue[key].priceMinor * state.sale.passengers;
        });
        state.sale.totalMinor = state.sale.offer.fareMinor * state.sale.passengers + extraTotal;
        state.sale.state = 'REVIEW';
        return structuredClone(state.sale);
      }
      case 'SALE.REVIEW':
        state.sale.termsVersion = detail.termsVersion;
        state.sale.state = 'PAYMENT';
        return structuredClone(state.sale);
      case 'PAYMENT.AUTHORIZE':
        state.sale.paymentStatus = 'AUTHORIZED';
        state.sale.paymentAuthorizationId = `${state.sale.saleId}-DEMO-AUTH`;
        state.sale.state = 'CONFIRMED';
        state.sale.booking = { status: 'CONFIRMED', bookingRef: `FL${String(state.saleSeq).padStart(5, '0')}`, source: 'DEMO' };
        return structuredClone(state.sale);
      default:
        return { status: 'ACTION_OBSERVED', action, source: 'DEMO' };
    }
  }

  function show(content, stage) {
    sales.hidden = false;
    sales.dataset.stage = stage;
    sales.innerHTML = content;
    sales.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }


  function assistantContext() {
    const context = {};
    if (state.lastSearch) {
      context.search = {
        origin: state.lastSearch.origin || 'PIK',
        destination: state.lastSearch.destination || 'EWR',
        date: state.lastSearch.date || '',
        passengers: Number(state.lastSearch.passengers || 0)
      };
    }
    if (state.sale) {
      const offer = state.sale.offer || {};
      context.sale = {
        state: state.sale.state || '',
        flightNo: offer.flightNo || '',
        origin: offer.origin || '',
        destination: offer.destination || '',
        date: offer.date || '',
        totalMinor: Number.isInteger(state.sale.totalMinor) ? state.sale.totalMinor : undefined,
        currency: offer.currency || 'GBP',
        bookingStatus: state.sale.booking?.status || '',
        bookingRef: state.sale.booking?.bookingRef || '',
        selectedExtras: Object.entries(state.sale.extras || {}).filter(([, selected]) => selected).map(([key]) => key)
      };
    }
    return context;
  }

  function addAssistantMessage(role, text) {
    const item = document.createElement('div');
    item.className = `assistant-message ${role}`;
    const who = role === 'user' ? 'You' : 'FlyLo assistant';
    const label = document.createElement('strong');
    label.textContent = who;
    const paragraph = document.createElement('p');
    paragraph.textContent = String(text || '');
    item.append(label, paragraph);
    assistantMessages.append(item);
    assistantMessages.scrollTop = assistantMessages.scrollHeight;
  }

  async function refreshAssistantStatus() {
    try {
      const response = await fetch('/healthz', { cache: 'no-store' });
      const health = await response.json();
      const configured = Boolean(health?.assistant?.configured);
      assistantStatus.textContent = configured ? 'Grok ready · structured real-time' : 'Grok needs XAI auth';
      assistantStatus.dataset.ready = configured ? 'true' : 'false';
      if (runtimeBuild) {
        const storage = String(health?.runtime?.storage || '').toLowerCase();
        runtimeBuild.textContent = `v${health?.version || '?'} · ${storage || 'runtime'}`;
        runtimeBuild.dataset.ready = health?.runtime?.ready ? 'true' : 'false';
        runtimeBuild.title = `Wire ${health?.runtime?.wireUiServer || '?'} · ${health?.runtime?.engine || '?'} · ${health?.runtime?.accounting || '?'}`;
      }
    } catch {
      assistantStatus.textContent = 'Assistant status unavailable';
      assistantStatus.dataset.ready = 'false';
      if (runtimeBuild) { runtimeBuild.textContent = 'build unavailable'; runtimeBuild.dataset.ready = 'false'; }
    }
  }

  function openAssistant() {
    logAction('ASSISTANT.OPEN', { source: 'public-shell' });
    assistantPanel.hidden = false;
    assistantPanel.scrollIntoView({ behavior: 'smooth', block: 'start' });
    refreshAssistantStatus();
    setTimeout(() => assistantQuestion.focus(), 150);
  }

  async function askAssistant(question) {
    const priorHistory = state.assistantHistory.slice(-8);
    logAction('ASSISTANT.ASK', { source: 'public-shell', characters: question.length });
    addAssistantMessage('user', question);
    state.assistantHistory.push({ role: 'user', content: question });
    assistantSend.disabled = true;
    assistantSend.textContent = 'Grok is thinking…';
    assistantStatus.textContent = 'Grok is assisting…';
    try {
      const response = await fetch('/api/assistant', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sessionId: state.assistantSessionId, question, history: priorHistory, context: assistantContext() })
      });
      const body = await response.json().catch(() => ({}));
      if (!response.ok || !body.ok) {
        throw new Error(body.message || body.code || `Assistant request failed: ${response.status}`);
      }
      if (body.sessionId) state.assistantSessionId = String(body.sessionId);
      const text = String(body.text || '').trim() || 'I did not receive an answer from Grok.';
      state.assistantHistory.push({ role: 'assistant', content: text });
      addAssistantMessage('assistant', text);
      assistantStatus.textContent = `Grok ready · structured · ${body.model || 'real-time'}`;
      assistantStatus.dataset.ready = 'true';
      if (body.action?.type === 'FLIGHT_SEARCH_RESULT' && body.action.offer) {
        state.lastSearch = {
          origin: body.action.offer.origin, destination: body.action.offer.destination,
          date: body.action.offer.date, passengers: body.action.offer.passengers
        };
        renderOffer(body.action.offer);
      }
    } catch (error) {
      const message = error?.message || 'The FlyLo assistant is temporarily unavailable.';
      addAssistantMessage('assistant', message);
      assistantStatus.textContent = 'Assistant unavailable';
      assistantStatus.dataset.ready = 'false';
    } finally {
      assistantSend.disabled = false;
      assistantSend.textContent = 'Ask Grok';
      assistantQuestion.focus();
    }
  }

  function progress(active) {
    const steps = ['Flights', 'Passengers', 'Extras', 'Review', 'Payment', 'Booked'];
    return `<ol class="sale-progress">${steps.map((s, i) => `<li class="${i <= active ? 'done' : ''} ${i === active ? 'active' : ''}"><span>${i + 1}</span>${s}</li>`).join('')}</ol>`;
  }

  function minuteTime(value) {
    const minutes = Number(value);
    if (!Number.isFinite(minutes)) return '';
    const h = Math.floor(minutes / 60) % 24;
    const m = minutes % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  function renderOffer(offer) {
    state.lastSearch = { origin: offer.origin, destination: offer.destination, date: offer.date, passengers: Number(offer.passengers || 0) };
    const total = Number.isInteger(offer.totalFareMinor) ? offer.totalFareMinor : offer.fareMinor * offer.passengers;
    const legs = Array.isArray(offer.legs) && offer.legs.length ? offer.legs : [offer];
    const legLines = legs.map((leg, index) => {
      const depart = leg.departure || minuteTime(leg.departureMinute);
      const arrive = leg.arrival || minuteTime(leg.arrivalMinute);
      return `<li><strong>${esc(leg.flightNo || offer.flightNo)}</strong> ${esc(leg.origin || offer.origin)} → ${esc(leg.destination || offer.destination)} · ${esc(depart)} → ${esc(arrive)}${index < legs.length - 1 ? ' · connection follows' : ''}</li>`;
    }).join('');
    const headline = legs.length > 1 ? 'THE ITINERARY WE FOUND' : 'THE FLIGHT WE FOUND';
    show(`${progress(0)}
      <div class="sale-card offer-card">
        <div><p class="eyebrow">${headline}</p><h2>${esc(offer.origin)} → ${esc(offer.destination)}</h2><p class="flight-line">${esc(offer.date)} · ${legs.length} flight${legs.length === 1 ? '' : 's'}</p><ul class="price-lines">${legLines}</ul><p class="fine">Source: ${esc(offer.source || 'FLYLO')}. Mandatory taxes and charges are included in the displayed fare. Optional extras are not selected for you.</p></div>
        <div class="fare"><small>${offer.passengers} passenger${offer.passengers === 1 ? '' : 's'}</small><strong>${money(total)}</strong><span>${money(offer.fareMinor)} each</span><button id="select-offer" type="button">Select this magnificent bargain</button></div>
      </div>`, 'OFFERS');
    document.querySelector('#select-offer').addEventListener('click', async () => {
      const sale = await dispatch('FLIGHT.SELECT', { offerId: offer.offerId, passengers: offer.passengers });
      renderPassengers(sale);
    });
  }

  function renderPassengers(sale) {
    state.sale = sale;
    const fields = Array.from({ length: sale.passengers }, (_, i) => `<fieldset><legend>Passenger ${i + 1}</legend><label>Given name<input name="givenName-${i}" autocomplete="given-name" required></label><label>Family name<input name="familyName-${i}" autocomplete="family-name" required></label>${i === 0 ? `<label>Email<input name="email-${i}" type="email" autocomplete="email" required></label>` : ''}</fieldset>`).join('');
    show(`${progress(1)}<div class="sale-card"><p class="eyebrow">WHO ARE WE SUBJECTING TO THIS?</p><h2>Passenger details</h2><form id="passenger-form" class="stack-form">${fields}<button type="submit">Continue to optional things</button></form></div>`, 'PASSENGERS');
    document.querySelector('#passenger-form').addEventListener('submit', async e => {
      e.preventDefault();
      const fd = new FormData(e.currentTarget);
      const passengers = Array.from({ length: sale.passengers }, (_, i) => ({ givenName: fd.get(`givenName-${i}`), familyName: fd.get(`familyName-${i}`), ...(i === 0 ? { email: fd.get(`email-${i}`) } : {}) }));
      const next = await dispatch('PASSENGER.SAVE', { saleId: sale.saleId, passengers });
      renderExtras(next);
    });
  }

  function renderExtras(sale) {
    state.sale = sale;
    const choices = Object.entries(extrasCatalogue).map(([key, item]) => `<label class="extra"><input type="checkbox" name="${key}"><span><strong>${esc(item.label)}</strong><small>Optional. Not preselected.</small></span><b>+${money(item.priceMinor)} pp</b></label>`).join('');
    show(`${progress(2)}<div class="sale-card"><p class="eyebrow">THE TRADITIONAL LOW-COST AIRLINE BIT</p><h2>Would you like anything else?</h2><p>Everything below is optional. Astonishingly, the empty basket is a valid choice.</p><form id="extras-form" class="extras">${choices}<button type="submit">Continue with my actual choices</button></form></div>`, 'EXTRAS');
    document.querySelector('#extras-form').addEventListener('submit', async e => {
      e.preventDefault();
      const fd = new FormData(e.currentTarget);
      const selections = Object.fromEntries(Object.keys(extrasCatalogue).map(key => [key, fd.has(key)]));
      const next = await dispatch('ANCILLARY.SAVE', { saleId: sale.saleId, selections });
      renderReview(next);
    });
  }

  function renderReview(sale) {
    state.sale = sale;
    const selected = Object.entries(sale.extras).filter(([, value]) => value).map(([key]) => `<li>${esc(extrasCatalogue[key].label)} <span>+${money(extrasCatalogue[key].priceMinor * sale.passengers)}</span></li>`).join('') || '<li>No optional extras <span>£0.00</span></li>';
    show(`${progress(3)}<div class="sale-card review-card"><div><p class="eyebrow">BEFORE MONEY CHANGES HANDS</p><h2>Review your booking</h2><ul class="price-lines"><li>Flight ${esc(sale.offer.flightNo)} × ${sale.passengers}<span>${money(sale.offer.fareMinor * sale.passengers)}</span></li>${selected}</ul><p class="fine">The mandatory flight price was shown before extras. Optional products remain separately identifiable.</p></div><div class="total-box"><span>Total</span><strong>${money(sale.totalMinor)}</strong><label class="terms"><input id="terms" type="checkbox" required> I accept Conditions of Carriage version <code>FLYLO-COC-2026.08.24</code></label><button id="accept-review" type="button">Accept &amp; continue to payment</button></div></div>`, 'REVIEW');
    document.querySelector('#accept-review').addEventListener('click', async () => {
      const terms = document.querySelector('#terms');
      if (!terms.checked) { terms.focus(); return; }
      const next = await dispatch('SALE.REVIEW', { saleId: sale.saleId, termsVersion: 'FLYLO-COC-2026.08.24', totalMinor: sale.totalMinor, currency: 'GBP' });
      renderPayment(next);
    });
  }

  function renderPayment(sale) {
    state.sale = sale;
    show(`${progress(4)}<div class="sale-card payment-card"><div><p class="eyebrow">THE EXPENSIVE CLICK</p><h2>Pay ${money(sale.totalMinor)} and book</h2><p>This application does not accept raw card numbers. A production payment widget supplies an opaque payment-method token.</p><p class="fine">This development launcher uses an explicit opaque fixture token <code>tok_demo_browser</code>. Payment authorisation and booking creation remain separate authorities with separate idempotency identities.</p></div><div class="total-box"><span>Amount to charge</span><strong>${money(sale.totalMinor)}</strong><button id="pay-book" type="button">Pay ${money(sale.totalMinor)} and book</button></div></div>`, 'PAYMENT');
    document.querySelector('#pay-book').addEventListener('click', async e => {
      e.currentTarget.disabled = true;
      e.currentTarget.textContent = 'Authorising…';
      try {
        const next = await dispatch('PAYMENT.AUTHORIZE', { saleId: sale.saleId, paymentMethodToken: 'tok_demo_browser', amountMinor: sale.totalMinor, currency: 'GBP' });
        renderConfirmation(next);
      } catch (err) {
        e.currentTarget.disabled = false;
        e.currentTarget.textContent = `Pay ${money(sale.totalMinor)} and book`;
        alert(err.message);
      }
    });
  }

  function renderConfirmation(sale) {
    state.sale = sale;
    const surname = sale.booking?.passengers?.[0]?.familyName || sale.passengerData?.[0]?.familyName || '';
    show(`${progress(5)}<div class="sale-card confirmation"><div class="giant-tick">✓</div><div><p class="eyebrow">THE BOOKING ENGINE SAYS YES</p><h2>You are booked.</h2><p>Booking reference <strong>${esc(sale.booking.bookingRef)}</strong></p><p>FlyLo ${esc(sale.offer.flightNo)} · ${esc(sale.offer.origin)} → ${esc(sale.offer.destination)} · ${esc(sale.offer.date)}</p><p class="fine">Confirmation source: ${esc(sale.booking.source)}. The development backend is explicit; production confirmation remains dependent on the real host authority.</p><button id="manage-confirmed" type="button" class="secondary">Manage these passengers</button></div></div>`, 'CONFIRMED');
    document.querySelector('#manage-confirmed').addEventListener('click', () => openManage(sale.booking.bookingRef, surname, true));
  }

  document.querySelector('#search-form').addEventListener('submit', async e => {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const detail = { origin: 'PIK', destination: 'EWR', date: fd.get('date'), passengers: Number(fd.get('passengers')) };
    const offer = await dispatch('FLIGHT.SEARCH', detail);
    renderOffer(offer);
  });

  async function workspaceRequest(pathname, payload) {
    const response = await fetch(pathname, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload)
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || !body.ok) {
      const error = new Error(body.message || body.code || `FlyLo workspace request failed: ${response.status}`);
      error.code = body.code || 'FLYLO_WORKSPACE_FAILED';
      throw error;
    }
    return body.result;
  }

  async function lookupManageBooking(bookingRef, familyName) {
    manageError.textContent = '';
    try {
      const workspace = await dispatch('BOOKING.LOOKUP', { bookingRef: String(bookingRef || '').trim(), familyName: String(familyName || '').trim() });
      renderManage(workspace);
      return workspace;
    } catch (error) {
      state.manage = null;
      manageWorkspace.hidden = true;
      manageWorkspace.innerHTML = '';
      manageContextBadge.textContent = 'No workspace loaded';
      manageError.textContent = error.code === 'BOOKING_LOOKUP_NOT_MATCHED'
        ? 'We could not match that booking reference and surname. Check the reference on your confirmation and try again.'
        : `${error.code || 'Lookup failed'}: ${error.message}`;
      return null;
    }
  }

  async function openManage(bookingRef = '', familyName = '', openImmediately = false) {
    managePanel.hidden = false;
    if (bookingRef) document.querySelector('#manage-booking-ref').value = bookingRef;
    if (familyName) document.querySelector('#manage-family-name').value = familyName;
    managePanel.scrollIntoView({ behavior: 'smooth', block: 'start' });
    if (openImmediately && bookingRef && familyName) {
      await lookupManageBooking(bookingRef, familyName);
      return;
    }
    setTimeout(() => document.querySelector('#manage-booking-ref').focus(), 100);
  }

  function selectedPassengerIds() {
    return Array.from(manageWorkspace.querySelectorAll('input[data-passenger-id]:checked')).map(input => input.dataset.passengerId);
  }

  function contextLabel(context) {
    if (!context) return 'No workspace loaded';
    return `scope ${context.scopeRevision} · order ${context.orderRevision} · selection ${context.selectionRevision}${context.resultRevision != null ? ` · result ${context.resultRevision}` : ''}`;
  }

  function renderManage(workspace) {
    state.manage = workspace;
    const context = workspace.workspaceContext || {};
    const selected = new Set(Array.isArray(context.selectedIds) ? context.selectedIds.map(String) : []);
    manageContextBadge.textContent = contextLabel(context);
    manageError.textContent = '';
    const passengers = Array.isArray(workspace.passengers) ? workspace.passengers : [];
    const rows = passengers.map(passenger => {
      const id = String(passenger.passengerId || '');
      const name = `${passenger.givenName || ''} ${passenger.familyName || ''}`.trim();
      return `<label class="passenger-row"><input type="checkbox" data-passenger-id="${esc(id)}" ${selected.has(id) ? 'checked' : ''}><span><strong>${esc(name || id)}</strong><small>${esc(id)} · Checked bags: ${Number(passenger.checkedBagCount || 0)}</small></span></label>`;
    }).join('');
    const last = workspace.lastAncillaryService
      ? `<div class="service-evidence"><strong>Last service confirmed</strong><span>${esc(workspace.lastAncillaryService.type)} · ${money(Number(workspace.lastAncillaryService.amountMinor || 0))} · ${esc((workspace.lastAncillaryService.passengerIds || []).join(', '))}</span></div>` : '';
    manageWorkspace.hidden = false;
    manageWorkspace.innerHTML = `<div class="workspace-summary"><div><p class="eyebrow">${esc(workspace.bookingRef)}</p><h3>${esc(workspace.origin)} → ${esc(workspace.destination)}</h3><p>${esc(workspace.travelDate)} · ${esc(workspace.status)} · source ${esc(workspace.source)}</p></div><div class="workspace-actions"><button id="workspace-sort" type="button" class="secondary">Sort surname ${context.orderRevision % 2 ? 'A→Z' : 'Z→A'}</button></div></div><div class="passenger-list">${rows}</div><div class="bag-service"><div><strong>Add checked baggage</strong><p>£49 per selected passenger per bag. The server prices this; the page does not submit an amount.</p></div><label>Bag quantity<input id="bag-quantity" type="number" min="1" max="10" value="1"></label><button id="add-bag" type="button">Add bag to selected passenger${selected.size === 1 ? '' : 's'}</button></div>${last}`;

    manageWorkspace.querySelectorAll('input[data-passenger-id]').forEach(input => input.addEventListener('change', async () => {
      const ids = selectedPassengerIds();
      try {
        const nextContext = await workspaceRequest('/api/workspace/select', {
          workspaceRef: context.workspaceRef,
          scopeRevision: context.scopeRevision,
          selectedIds: ids
        });
        state.manage.workspaceContext = nextContext;
        renderManage(state.manage);
      } catch (error) { manageError.textContent = `${error.code || 'Selection failed'}: ${error.message}`; renderManage(state.manage); }
    }));

    document.querySelector('#workspace-sort').addEventListener('click', async () => {
      try {
        const direction = context.orderRevision % 2 ? 'ASC' : 'DESC';
        const nextContext = await workspaceRequest('/api/workspace/sort', { workspaceRef: context.workspaceRef, sortRef: 'familyName', direction });
        state.manage.workspaceContext = nextContext;
        renderManage(state.manage);
      } catch (error) { manageError.textContent = `${error.code || 'Sort failed'}: ${error.message}`; }
    });

    document.querySelector('#add-bag').addEventListener('click', async event => {
      const quantity = Number(document.querySelector('#bag-quantity').value);
      if (!selectedPassengerIds().length) { manageError.textContent = 'Select at least one passenger first.'; return; }
      event.currentTarget.disabled = true;
      try {
        const updated = await dispatch('BOOKING.ADD_CHECKED_BAG', {
          workspaceContext: state.manage.workspaceContext,
          quantity,
          paymentMethodToken: 'tok_demo_servicing'
        });
        renderManage(updated);
      } catch (error) {
        manageError.textContent = `${error.code || 'Servicing failed'}: ${error.message}`;
        event.currentTarget.disabled = false;
      }
    });
  }

  document.querySelector('#manage-open').addEventListener('click', () => openManage());
  manageLookupForm.addEventListener('submit', async event => {
    event.preventDefault();
    const fd = new FormData(event.currentTarget);
    await lookupManageBooking(fd.get('bookingRef'), fd.get('familyName'));
  });

  document.querySelector('#status-form').addEventListener('submit', async event => {
    event.preventDefault();
    const fd = new FormData(event.currentTarget);
    const output = document.querySelector('#status-result');
    try {
      const status = await dispatch('FLIGHT.STATUS', { flightNo: String(fd.get('flightNo') || '').trim(), date: fd.get('date') });
      output.textContent = `${status.flightNo || fd.get('flightNo')} · ${status.status || 'UNKNOWN'} · ${status.origin || ''} → ${status.destination || ''}`;
    } catch (error) { output.textContent = error.message; }
  });

  refreshAssistantStatus();
  document.querySelector('#assistant-open').addEventListener('click', openAssistant);
  document.querySelector('#assistant-close').addEventListener('click', () => { assistantPanel.hidden = true; });
  assistantForm.addEventListener('submit', async event => {
    event.preventDefault();
    const question = assistantQuestion.value.trim();
    if (!question) return;
    assistantQuestion.value = '';
    await askAssistant(question);
  });

  window.FlyLoActions = Object.freeze({ dispatch });
})();
